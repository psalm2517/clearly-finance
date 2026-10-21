import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clearly/data/database.dart';
import 'package:clearly/data/repository.dart';
import 'package:clearly/data/simplefin.dart';
import 'package:clearly/main.dart';
import 'package:clearly/screens/bank_sync.dart';
import 'package:clearly/screens/shell.dart';
import 'package:clearly/theme/catppuccin.dart';

class _Bridge implements SimpleFinTransport {
  int fetches = 0;
  @override
  Future<({int status, String body})> send(String method, Uri url,
      {Map<String, String> headers = const {}}) async {
    fetches++;
    return (status: 200, body: jsonEncode({'errlist': [], 'accounts': []}));
  }
}

void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump();
    }
  }

  Future<int> open(WidgetTester tester, DateTime? lastSync) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = HomebaseRepository(db);
    late Profile profile;
    final bridge = _Bridge();
    await tester.runAsync(() async {
      final id = await repo.createProfile(
          ProfilesCompanion.insert(name: 'Owner', isAdmin: const Value(true)));
      profile = (await repo.profileById(id))!;
      await db.into(db.simpleFinConnections).insert(
            SimpleFinConnectionsCompanion.insert(
              profileId: id,
              accessUrl: 'https://u:p@bridge.test/simplefin',
              createdAt: DateTime(2026, 1, 1),
              lastSyncAt: Value(lastSync),
            ),
          );
    });
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        loggedInProfileProvider.overrideWith((ref) => profile),
        simpleFinClientProvider
            .overrideWithValue(SimpleFinClient(transport: bridge)),
      ],
      child: MaterialApp(
        theme: themeFor(CatppuccinFlavor.mocha),
        home: const AppShell(),
      ),
    ));
    await settle(tester);
    final n = bridge.fetches;
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await tester.pump(const Duration(seconds: 2));
    return n;
  }

  testWidgets('opening Clearly after missed days syncs, as the day is owed',
      (tester) async {
    final n = await open(tester, DateTime.now().subtract(const Duration(days: 4)));
    expect(n, greaterThan(0));
  });

  testWidgets('opening Clearly when today\'s sync is done does not sync',
      (tester) async {
    expect(lastSyncSlot(DateTime.now()).isBefore(DateTime.now()), isTrue);
    final n = await open(tester, DateTime.now());
    expect(n, 0);
  });

  testWidgets('with no connection nothing is ever fetched', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = HomebaseRepository(db);
    late Profile profile;
    final bridge = _Bridge();
    await tester.runAsync(() async {
      final id = await repo.createProfile(
          ProfilesCompanion.insert(name: 'Owner', isAdmin: const Value(true)));
      profile = (await repo.profileById(id))!;
    });
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        loggedInProfileProvider.overrideWith((ref) => profile),
        simpleFinClientProvider
            .overrideWithValue(SimpleFinClient(transport: bridge)),
      ],
      child: MaterialApp(
        theme: themeFor(CatppuccinFlavor.mocha),
        home: const AppShell(),
      ),
    ));
    await settle(tester);
    expect(bridge.fetches, 0);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await tester.pump(const Duration(seconds: 2));
  });
}
