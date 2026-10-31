import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clearly/data/database.dart';
import 'package:clearly/data/repository.dart';

void main() {
  group("detection", detectionTests);
  late AppDatabase db;
  late HomebaseRepository repo;
  late int pid;
  final now = DateTime(2026, 10, 15);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = HomebaseRepository(db);
    pid = await repo.createProfile(ProfilesCompanion.insert(name: 'P'));
    await repo.upsertAccount(AccountsCompanion.insert(
        profileId: pid,
        name: 'Checking',
        type: AccountType.checking,
        balanceCents: const Value(100000)));
  });
  tearDown(() => db.close());

  Future<void> spend(DateTime d, int cents, String cat) =>
      repo.addBudgetEntry(BudgetEntriesCompanion.insert(
          profileId: pid,
          date: d,
          amountCents: cents,
          type: EntryType.expense,
          category: Value(cat)));

  test('safe to spend is cash less bills due before the next paycheck',
      () async {
    await repo.upsertBill(BillsCompanion.insert(
        profileId: pid, name: 'Rent', amountCents: 30000, dueDay: 20));
    // Due after the paycheck: not counted.
    await repo.upsertBill(BillsCompanion.insert(
        profileId: pid, name: 'Gym', amountCents: 5000, dueDay: 28));
    await repo.upsertPaycheck(PaychecksCompanion.insert(
        profileId: pid,
        name: 'Job',
        date: DateTime(2026, 10, 25),
        amountCents: 200000));

    final b = await repo.dashboardBrief(profileId: pid, now: now);
    expect(b.cashCents, 100000);
    expect(b.committedCents, 30000);
    expect(b.safeToSpendCents, 70000);
    expect(b.horizonIsPaycheck, isTrue);
    expect(b.horizon, DateTime(2026, 10, 25));
  });

  test('without a paycheck the horizon is two weeks', () async {
    final b = await repo.dashboardBrief(profileId: pid, now: now);
    expect(b.horizonIsPaycheck, isFalse);
    expect(b.horizon, DateTime(2026, 10, 29));
    expect(b.safeToSpendCents, 100000);
  });

  test('spending is compared with the same point last month, transfers out',
      () async {
    await spend(DateTime(2026, 9, 5), 20000, 'Food'); // by day 15
    await spend(DateTime(2026, 9, 25), 90000, 'Food'); // after day 15
    await spend(DateTime(2026, 10, 3), 50000, 'Food');
    await spend(DateTime(2026, 10, 4), 99900, 'Transfers');

    final b = await repo.dashboardBrief(profileId: pid, now: now);
    expect(b.spentThisMonthCents, 50000);
    expect(b.spentLastMonthSoFarCents, 20000);
    expect(
        b.insights.any((i) =>
            i.tone == InsightTone.warning && i.title.contains('more than')),
        isTrue);
  });

  test('an overrun cash projection is flagged', () async {
    await repo.upsertBill(BillsCompanion.insert(
        profileId: pid, name: 'Big', amountCents: 500000, dueDay: 20));
    final b = await repo.dashboardBrief(profileId: pid, now: now);
    expect(b.insights.first.title, contains('run out'));
  });
}

void detectionTests() {
  late AppDatabase db;
  late HomebaseRepository repo;
  late int pid;
  final now = DateTime(2026, 10, 15);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = HomebaseRepository(db);
    pid = await repo.createProfile(ProfilesCompanion.insert(name: 'P'));
  });
  tearDown(() => db.close());

  Future<void> add(DateTime d, int cents, String payee,
          {EntryType type = EntryType.expense, String cat = 'Other'}) =>
      repo.addBudgetEntry(BudgetEntriesCompanion.insert(
          profileId: pid,
          date: d,
          amountCents: cents,
          type: type,
          payee: Value(payee),
          category: Value(cat)));

  test('a steady monthly charge is found, a one-off and a pair are not',
      () async {
    for (final m in [5, 6, 7, 8, 9, 10]) {
      await add(DateTime(2026, m, 3), 1599, 'NETFLIX.COM 123');
    }
    await add(DateTime(2026, 9, 9), 4200, 'Random Shop');
    await add(DateTime(2026, 8, 2), 900, 'Two Times');
    await add(DateTime(2026, 9, 2), 900, 'Two Times');

    final found = await repo.detectRecurring(profileId: pid, now: now);
    expect(found, hasLength(1));
    expect(found.single.cadence, 'monthly');
    expect(found.single.typicalCents, 1599);
    expect(found.single.next, DateTime(2026, 11, 3));
  });

  test('biweekly pay is found as income, and tracking makes a schedule',
      () async {
    for (var i = 0; i < 6; i++) {
      await add(DateTime(2026, 7, 31).add(Duration(days: 14 * i)), 75000,
          'City Payroll',
          type: EntryType.income, cat: 'Paycheck');
    }
    final found = await repo.detectRecurring(profileId: pid, now: now);
    expect(found.single.cadence, 'every 2 weeks');
    await repo.trackDetected(profileId: pid, d: found.single);
    final schedules = await repo.watchSchedules(profileId: pid).first;
    expect(schedules, hasLength(1));
    expect(schedules.single.amountCents, 75000);
    // Now tracked, so no longer offered.
    expect(await repo.detectRecurring(profileId: pid, now: now), isEmpty);
  });

  test('a pattern that stopped long ago is not offered', () async {
    for (final m in [1, 2, 3, 4]) {
      await add(DateTime(2025, m, 3), 999, 'Old Gym');
    }
    expect(await repo.detectRecurring(profileId: pid, now: now), isEmpty);
  });
}
