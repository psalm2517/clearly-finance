part of 'repository.dart';

/// Where tapping an insight should take you.
enum InsightLink { cashFlow, budget, recurring, accounts, transactions }

enum InsightTone { warning, good, info }

class Insight {
  const Insight(this.tone, this.title, this.detail, this.link);
  final InsightTone tone;
  final String title;
  final String detail;
  final InsightLink link;
}

/// One category's spending this month against what is normal for it.
typedef CategoryPace = ({String category, int cents, int typicalCents});

/// Everything the dashboard's top section says, worked out from what is
/// already stored. Nothing here is a guess about the future beyond what is
/// scheduled: bills, paychecks, card and loan payments already on the books.
class DashboardBrief {
  const DashboardBrief({
    required this.cashCents,
    required this.committedCents,
    required this.horizon,
    required this.horizonIsPaycheck,
    required this.nextPaycheckCents,
    required this.spentThisMonthCents,
    required this.spentLastMonthSoFarCents,
    required this.topCategories,
    required this.insights,
  });

  /// Checking, savings and cash right now.
  final int cashCents;

  /// Bills, loan and card payments and the like falling due before [horizon].
  final int committedCents;

  /// The day that safe-to-spend is counted up to: the next paycheck, or two
  /// weeks out when none is scheduled soon.
  final DateTime horizon;
  final bool horizonIsPaycheck;
  final int? nextPaycheckCents;

  final int spentThisMonthCents;

  /// Spent last month, up to the same day of the month.
  final int spentLastMonthSoFarCents;
  final List<CategoryPace> topCategories;
  final List<Insight> insights;

  int get safeToSpendCents => cashCents - committedCents;

  int daysLeft(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final d = horizon.difference(today).inDays;
    return d < 1 ? 1 : d;
  }

  int perDayCents(DateTime now) =>
      safeToSpendCents <= 0 ? 0 : safeToSpendCents ~/ daysLeft(now);
}

extension DashboardBriefRepository on HomebaseRepository {
  Future<DashboardBrief> dashboardBrief({
    required int profileId,
    DateTime? now,
  }) async {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);

    final accounts = await watchAccounts(profileId: profileId).first;
    final cards = await watchCards(profileId: profileId).first;
    final cash = accounts
        .where((a) => HomebaseRepository.cashAccountTypes.contains(a.type))
        .fold<int>(0, (s, a) => s + a.balanceCents);

    // Safe to spend: cash, less what is already spoken for before the next
    // paycheck. Without a paycheck in the next 30 days, the next two weeks.
    final upcoming = await upcomingItems(profileId: profileId, days: 30, now: n);
    final paychecks =
        upcoming.where((u) => u.kind == UpcomingKind.paycheck).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final nextPay = paychecks.isEmpty ? null : paychecks.first;
    final twoWeeks = today.add(const Duration(days: 14));
    final horizonIsPaycheck = nextPay != null && nextPay.date.isAfter(today);
    final horizon = horizonIsPaycheck ? nextPay.date : twoWeeks;
    final committed = upcoming
        .where((u) =>
            u.amountCents < 0 &&
            u.kind != UpcomingKind.transfer &&
            u.date.isBefore(horizon))
        .fold<int>(0, (s, u) => s - u.amountCents);

    // Spending: this month so far, against the same stretch of last month.
    final entries = await watchAllEntries(profileId: profileId).first;
    final monthStart = DateTime(n.year, n.month);
    final lastStart = DateTime(n.year, n.month - 1);
    final lastSamePoint = DateTime(n.year, n.month - 1, n.day, 23, 59, 59);
    final threeBack = DateTime(n.year, n.month - 3);

    var spent = 0;
    var spentLast = 0;
    final thisByCat = <String, int>{};
    final priorByCat = <String, int>{};
    for (final e in entries) {
      if (e.type != EntryType.expense || e.category == Cat.transfers) continue;
      if (!e.date.isBefore(monthStart)) {
        spent += e.amountCents;
        thisByCat[e.category] = (thisByCat[e.category] ?? 0) + e.amountCents;
      } else {
        if (!e.date.isBefore(lastStart) && !e.date.isAfter(lastSamePoint)) {
          spentLast += e.amountCents;
        }
        if (!e.date.isBefore(threeBack)) {
          priorByCat[e.category] =
              (priorByCat[e.category] ?? 0) + e.amountCents;
        }
      }
    }
    // Three full prior months, averaged. Fewer when history is short.
    final firstEntry = entries.isEmpty
        ? monthStart
        : entries.map((e) => e.date).reduce((a, b) => a.isBefore(b) ? a : b);
    final monthsOfHistory = ((monthStart.year - firstEntry.year) * 12 +
            monthStart.month -
            firstEntry.month)
        .clamp(0, 3);
    final tops = thisByCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategories = <CategoryPace>[
      for (final t in tops.take(4))
        (
          category: t.key,
          cents: t.value,
          typicalCents: monthsOfHistory == 0
              ? 0
              : (priorByCat[t.key] ?? 0) ~/ monthsOfHistory,
        ),
    ];

    final insights = <Insight>[];

    // 1. Cash that runs out.
    final projection =
        await projectCashFlow(profileId: profileId, days: 30, now: n);
    if (projection.isNotEmpty) {
      final low = projection
          .reduce((a, b) => a.balanceCents < b.balanceCents ? a : b);
      if (low.balanceCents < 0) {
        insights.add(Insight(
          InsightTone.warning,
          'Cash is projected to run out',
          'It reaches ${fmtCents(low.balanceCents)} on '
              '${low.date.month}/${low.date.day} if nothing changes.',
          InsightLink.cashFlow,
        ));
      }
    }

    // 2. Card balances above 30% of the limit.
    final overall = HomebaseRepository.overallUtilization(cards);
    if (cards.isNotEmpty && overall > 0.30) {
      final limit = cards.fold<int>(0, (s, c) => s + c.creditLimitCents);
      final balance = cards.fold<int>(0, (s, c) => s + c.balanceCents);
      final toPay = balance - (limit * 0.30).floor();
      insights.add(Insight(
        InsightTone.warning,
        'Card use is ${(overall * 100).round()}% of your limits',
        'Paying down ${fmtCents(toPay)} would bring it under 30%.',
        InsightLink.accounts,
      ));
    }

    // 3. Pace against last month.
    if (spentLast >= 10000) {
      final diff = spent - spentLast;
      if (spent > spentLast * 1.15) {
        insights.add(Insight(
          InsightTone.warning,
          'Spending ${fmtCents(diff)} more than this time last month',
          'Counted to the same day of the month, transfers left out.',
          InsightLink.budget,
        ));
      } else if (spent < spentLast * 0.85) {
        insights.add(Insight(
          InsightTone.good,
          'Spending ${fmtCents(-diff)} less than this time last month',
          'Counted to the same day of the month, transfers left out.',
          InsightLink.budget,
        ));
      }
    }

    // 4. A category well above its own normal.
    for (final c in topCategories) {
      if (c.typicalCents >= 5000 &&
          c.cents > c.typicalCents * 1.5 &&
          c.cents - c.typicalCents >= 5000) {
        insights.add(Insight(
          InsightTone.info,
          '${c.category} is running high',
          '${fmtCents(c.cents)} so far, against about '
              '${fmtCents(c.typicalCents)} in a typical month.',
          InsightLink.transactions,
        ));
        break;
      }
    }

    return DashboardBrief(
      cashCents: cash,
      committedCents: committed,
      horizon: horizon,
      horizonIsPaycheck: horizonIsPaycheck,
      nextPaycheckCents: horizonIsPaycheck ? nextPay.amountCents : null,
      spentThisMonthCents: spent,
      spentLastMonthSoFarCents: spentLast,
      topCategories: topCategories,
      insights: insights,
    );
  }
}

/// Something that keeps coming back in the history: a subscription, a bill,
/// a paycheck. Found by looking, not by being told.
typedef DetectedRecurring = ({
  String key,
  String name,
  EntryType type,
  String cadence,
  int days,
  int typicalCents,
  bool variable,
  DateTime last,
  DateTime next,
  int count,
  String category,
  int? accountId,
  int? cardId,
});

String _recurringKey(String text) {
  final words = text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.length > 1 && w != 'sq' && w != 'tst' && w != 'pos')
      .take(3)
      .toList();
  return words.join(' ');
}

extension RecurringDetection on HomebaseRepository {
  /// Looks through the last year and a half for charges and deposits that
  /// repeat on a steady rhythm, for about the same amount. Three occurrences
  /// are needed (two for a yearly one), so a one-off is never mistaken for a
  /// pattern. Anything already tracked as a bill, paycheck or recurring item
  /// is left out.
  Future<List<DetectedRecurring>> detectRecurring({
    required int profileId,
    DateTime? now,
  }) async {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final since = today.subtract(const Duration(days: 550));

    final entries = await (_db.select(_db.budgetEntries)
          ..where((e) =>
              e.profileId.equals(profileId) &
              e.date.isBiggerOrEqualValue(since)))
        .get();

    final groups = <String, List<BudgetEntry>>{};
    for (final e in entries) {
      if (e.category == Cat.transfers || e.category == 'Split') continue;
      final key = _recurringKey(
          '${e.payee?.isNotEmpty == true ? e.payee : e.description ?? ''}');
      if (key.isEmpty) continue;
      groups.putIfAbsent('${e.type.name}:$key', () => []).add(e);
    }

    final tracked = <String>{};
    for (final b in await watchBills(profileId: profileId).first) {
      tracked.add(_recurringKey(b.name).split(' ').first);
    }
    for (final s in await watchSchedules(profileId: profileId).first) {
      tracked.add(_recurringKey(s.name).split(' ').first);
    }
    for (final r in await (_db.select(_db.recurringTransactions)
          ..where((r) => r.profileId.equals(profileId)))
        .get()) {
      tracked.add(_recurringKey(r.name).split(' ').first);
    }
    tracked.remove('');

    const cadences = <(String, int, int)>[
      ('weekly', 7, 2),
      ('every 2 weeks', 14, 3),
      ('monthly', 30, 5),
      ('quarterly', 91, 8),
      ('yearly', 365, 10),
    ];

    final found = <DetectedRecurring>[];
    for (final g in groups.entries) {
      final list = g.value..sort((a, b) => a.date.compareTo(b.date));
      // One occurrence per day.
      final days = <DateTime>[];
      for (final e in list) {
        final d = DateTime(e.date.year, e.date.month, e.date.day);
        if (days.isEmpty || d != days.last) days.add(d);
      }
      if (days.length < 2) continue;
      final gaps = [
        for (var i = 1; i < days.length; i++)
          days[i].difference(days[i - 1]).inDays,
      ];

      (String, int, int)? best;
      var bestHits = 0;
      for (final c in cadences) {
        final hits = gaps.where((x) => (x - c.$2).abs() <= c.$3).length;
        if (hits > bestHits) {
          bestHits = hits;
          best = c;
        }
      }
      if (best == null) continue;
      final need = best.$1 == 'yearly' ? 1 : 2;
      if (bestHits < need || bestHits < gaps.length * 0.7) continue;
      if (best.$1 != 'yearly' && days.length < 3) continue;

      final amounts = [for (final e in list) e.amountCents]..sort();
      final median = amounts[amounts.length ~/ 2];
      if (median <= 0) continue;
      int within(double tol) =>
          amounts.where((a) => (a - median).abs() <= median * tol).length;
      final stable = within(0.12) >= amounts.length * 0.7;
      final variable = !stable &&
          best.$1 == 'monthly' &&
          within(0.4) >= amounts.length * 0.7;
      if (!stable && !variable) continue;

      final last = days.last;
      // A pattern that stopped a while ago is history, not a subscription.
      if (today.difference(last).inDays > best.$2 * 2.2) continue;
      DateTime step(DateTime d) => switch (best!.$1) {
            'monthly' => DateTime(d.year, d.month + 1, last.day),
            'quarterly' => DateTime(d.year, d.month + 3, last.day),
            'yearly' => DateTime(d.year + 1, d.month, last.day),
            _ => d.add(Duration(days: best.$2)),
          };
      var next = step(last);
      while (next.isBefore(today)) {
        next = step(next);
      }

      final first = g.key.split(':').first;
      final key = g.key.split(':').last;
      if (tracked.contains(key.split(' ').first)) continue;

      final latest = list.last;
      found.add((
        key: g.key,
        name: latest.payee?.isNotEmpty == true
            ? latest.payee!
            : (latest.description ?? key),
        type: first == 'income' ? EntryType.income : EntryType.expense,
        cadence: best.$1,
        days: best.$2,
        typicalCents: median,
        variable: variable,
        last: last,
        next: next,
        count: days.length,
        category: latest.category,
        accountId: latest.accountId,
        cardId: latest.cardId,
      ));
    }
    found.sort((a, b) => a.next.compareTo(b.next));
    return found;
  }

  /// Starts tracking a detected pattern as the right kind of thing: a bill, a
  /// paycheck schedule, or a recurring transaction.
  Future<void> trackDetected({
    required int profileId,
    required DetectedRecurring d,
  }) async {
    final name = d.name.length > 64 ? d.name.substring(0, 64) : d.name;
    final monthly = d.cadence == 'monthly';
    final billish = d.type == EntryType.expense &&
        (monthly || d.cadence == 'quarterly' || d.cadence == 'yearly');
    if (billish) {
      await upsertBill(BillsCompanion.insert(
        profileId: profileId,
        name: name,
        amountCents: d.typicalCents,
        dueDay: d.last.day,
        frequency: Value(monthly
            ? BillFrequency.monthly
            : d.cadence == 'quarterly'
                ? BillFrequency.quarterly
                : BillFrequency.annual),
        dueMonth: Value(monthly ? null : d.last.month),
      ));
      return;
    }
    final freq = switch (d.cadence) {
      'weekly' => PayFrequency.weekly,
      'every 2 weeks' => PayFrequency.biweekly,
      _ => PayFrequency.monthly,
    };
    if (d.type == EntryType.income && d.category == Cat.paycheck) {
      await upsertSchedule(PaycheckSchedulesCompanion.insert(
        profileId: profileId,
        name: name,
        frequency: freq,
        anchorDate: d.next,
        amountCents: d.typicalCents,
        accountId: Value(d.accountId),
      ));
      return;
    }
    await upsertRecurringTransaction(RecurringTransactionsCompanion.insert(
      profileId: profileId,
      name: name,
      type: d.type,
      amountCents: d.typicalCents,
      category: Value(d.category),
      frequency: freq,
      anchorDate: d.next,
      accountId: Value(d.accountId),
      cardId: Value(d.cardId),
    ));
  }
}
