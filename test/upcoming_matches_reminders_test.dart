import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clearly/data/database.dart';
import 'package:clearly/data/reminder.dart';
import 'package:clearly/data/repository.dart';

void main() {
  late AppDatabase db;
  late HomebaseRepository repo;
  late int pid;
  final now = DateTime(2026, 10, 30, 9);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = HomebaseRepository(db);
    pid = await repo.createProfile(
        ProfilesCompanion.insert(name: 'Owner', isAdmin: const Value(true)));
  });
  tearDown(() => db.close());

  test('a loan with no due day is not reminded about, and not listed',
      () async {
    await repo.upsertLoan(LoansCompanion.insert(
        profileId: pid,
        name: 'Car',
        balanceCents: 150000,
        originalAmountCents: 300000,
        monthlyPaymentCents: const Value(12483)));
    expect(await repo.upcomingReminders(profileId: pid, now: now), isEmpty);
    expect(await repo.upcomingItems(profileId: pid, days: 14, now: now),
        isEmpty);
  });

  test('everything the reminders panel shows is in the next-14-days list',
      () async {
    await repo.upsertLoan(LoansCompanion.insert(
        profileId: pid,
        name: 'Car',
        balanceCents: 150000,
        originalAmountCents: 300000,
        monthlyPaymentCents: const Value(12483),
        paymentDueDay: const Value(1)));
    await repo.upsertCard(CreditCardsCompanion.insert(
        profileId: pid,
        name: 'Visa',
        creditLimitCents: 500000,
        balanceCents: const Value(65173),
        paymentDueDay: const Value(1),
        annualFeeCents: const Value(15000),
        annualFeeDate: Value(DateTime(2026, 11, 2))));
    await repo.upsertBill(BillsCompanion.insert(
        profileId: pid, name: 'Phone', amountCents: 5500, dueDay: 31));

    final reminders = await repo.upcomingReminders(profileId: pid, now: now);
    expect(reminders.map((r) => r.kind).toSet(), {
      ReminderKind.loanPayment,
      ReminderKind.cardPayment,
      ReminderKind.annualFee,
      ReminderKind.bill,
    });

    final items =
        await repo.upcomingItems(profileId: pid, days: 14, now: now);
    String day(DateTime d) => '${d.year}-${d.month}-${d.day}';
    for (final r in reminders) {
      final kind = switch (r.kind) {
        ReminderKind.bill => UpcomingKind.bill,
        ReminderKind.cardPayment => UpcomingKind.cardPayment,
        ReminderKind.loanPayment => UpcomingKind.loanPayment,
        ReminderKind.annualFee => UpcomingKind.annualFee,
      };
      expect(
        items.any((i) => i.kind == kind && day(i.date) == day(r.date)),
        isTrue,
        reason: 'reminder "${r.title}" on ${day(r.date)} is missing below',
      );
    }
    // And the loan's real amount is what comes out.
    final loan = items.firstWhere((i) => i.kind == UpcomingKind.loanPayment);
    expect(loan.amountCents, -12483);
    expect(loan.label, 'Car payment');
  });
}
