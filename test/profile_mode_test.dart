import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clearly/data/database.dart';
import 'package:clearly/data/repository.dart';
import 'package:clearly/data/transaction_draft.dart';

void main() {
  late AppDatabase db;
  late HomebaseRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = HomebaseRepository(db);
  });
  tearDown(() => db.close());

  Future<int> profile(String mode) => repo.createProfile(
      ProfilesCompanion.insert(name: 'P', syncMode: Value(mode)));

  final draft = TransactionDraft(
    kind: DraftKind.expense,
    amountCents: 500,
    date: DateTime(2026, 8, 3),
    name: 'Coffee',
  );

  test('profiles are manual unless made synced', () async {
    final m = await repo.profileById(await profile('manual'));
    final s = await repo.profileById(await profile('synced'));
    expect(m!.isSynced, isFalse);
    expect(s!.isSynced, isTrue);
    final d = await repo.profileById(await repo.createProfile(
        ProfilesCompanion.insert(name: 'Default')));
    expect(d!.isSynced, isFalse);
  });

  test('a synced profile refuses hand entry and CSV import', () async {
    final id = await profile('synced');
    await expectLater(
        repo.addTransaction(profileId: id, draft: draft), throwsStateError);
    await expectLater(
        repo.previewImport(profileId: id, accountId: 1, rows: const []),
        throwsStateError);
    await expectLater(
        repo.commitImport(
            profileId: id,
            accountId: 1,
            sourceFilename: 'x.csv',
            rows: const [],
            updateAccountBalance: false),
        throwsStateError);
  });

  test('a manual profile still takes hand entry', () async {
    final id = await profile('manual');
    await repo.addTransaction(profileId: id, draft: draft);
    expect(await repo.watchAllEntries(profileId: id).first, hasLength(1));
  });

  test('reusing an existing tag links the right one', () async {
    final id = await profile('manual');
    for (final name in ['A', 'B']) {
      await repo.addBudgetEntry(BudgetEntriesCompanion.insert(
          profileId: id,
          date: DateTime(2026, 8, 3),
          amountCents: 100,
          type: EntryType.expense,
          description: Value(name)));
    }
    final entries = await repo.watchAllEntries(profileId: id).first;
    await repo.setEntryTags(
        profileId: id, entryId: entries[0].id, tagNames: ['x', 'y']);
    await repo.setEntryTags(
        profileId: id, entryId: entries[1].id, tagNames: ['y', 'x', 'z']);
    final tags = await repo.watchEntryTagNames(profileId: id).first;
    expect(tags[entries[0].id]!.toSet(), {'x', 'y'});
    expect(tags[entries[1].id]!.toSet(), {'x', 'y', 'z'});
  });
}
