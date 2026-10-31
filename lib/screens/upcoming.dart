import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/repository.dart';
import '../main.dart';
import '../util/money.dart';
import '../widgets/common.dart';

IconData _kindIcon(UpcomingKind kind) => switch (kind) {
      UpcomingKind.bill => Icons.receipt_long_outlined,
      UpcomingKind.paycheck => Icons.payments_outlined,
      UpcomingKind.transfer => Icons.sync_alt_outlined,
      UpcomingKind.recurring => Icons.autorenew,
      UpcomingKind.cardPayment => Icons.credit_card,
      UpcomingKind.loanPayment => Icons.request_quote_outlined,
      UpcomingKind.annualFee => Icons.event_repeat,
    };

String _kindLabel(UpcomingKind kind) => switch (kind) {
      UpcomingKind.bill => 'Bill',
      UpcomingKind.paycheck => 'Paycheck',
      UpcomingKind.transfer => 'Transfer',
      UpcomingKind.recurring => 'Recurring',
      UpcomingKind.cardPayment => 'Card payment',
      UpcomingKind.loanPayment => 'Loan payment',
      UpcomingKind.annualFee => 'Annual fee',
    };

/// Everything Clearly already knows is coming — bills, paychecks,
/// transfers and general recurring transactions — merged into one
/// chronological list instead of checking four separate screens.
class UpcomingScreen extends ConsumerStatefulWidget {
  const UpcomingScreen({super.key});

  @override
  ConsumerState<UpcomingScreen> createState() => _UpcomingScreenState();
}

class _UpcomingScreenState extends ConsumerState<UpcomingScreen> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final profileId = ref.watch(activeProfileProvider)!.id;
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<UpcomingItem>>(
      future: repo.upcomingItems(profileId: profileId, days: _days),
      builder: (context, snap) {
        final items = snap.data ?? [];

        return ListView(
          padding: kPagePadding,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SectionHeader('Upcoming',
                    icon: Icons.upcoming_outlined,
                    info: const InfoButton(
                      title: 'Upcoming',
                      body: [
                        'Every bill due, paycheck landing, recurring '
                            'transfer, and general recurring transaction '
                            'in the window below, in one chronological '
                            'list.',
                        'This is the same data the projected cash balance '
                            'on the Dashboard is built from — this view '
                            'just shows what each occurrence actually is, '
                            'rather than the running total.',
                      ],
                    )),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 7, label: Text('7d')),
                    ButtonSegment(value: 30, label: Text('30d')),
                    ButtonSegment(value: 90, label: Text('90d')),
                  ],
                  selected: {_days},
                  onSelectionChanged: (s) => setState(() => _days = s.first),
                ),
              ],
            ),
            _DetectedPanel(
              profileId: profileId,
              onTracked: () => setState(() {}),
            ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: EmptyState(
                  icon: Icons.upcoming_outlined,
                  title: 'Nothing coming up',
                  message: 'Bills, paychecks, transfers and recurring '
                      'transactions in this window will show up here.',
                ),
              )
            else
              Card(
                child: Column(
                  children: [
                    for (final item in items)
                      ListTile(
                        leading: Icon(_kindIcon(item.kind),
                            color: item.amountCents >= 0
                                ? scheme.primary
                                : scheme.onSurfaceVariant),
                        title: Text(item.label),
                        subtitle: Text(
                            '${_fmtDate(item.date)} • ${_kindLabel(item.kind)}'),
                        trailing: Text(
                          '${item.amountCents >= 0 ? '+' : '-'}'
                          '${fmtCents(item.amountCents.abs())}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: item.amountCents >= 0
                                ? scheme.primary
                                : scheme.onSurface,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${ordinalDay(d.day)}, ${d.year}';
  }
}

/// Repeating charges and deposits found in the history that are not tracked
/// yet. One tap makes them a bill, a paycheck or a recurring transaction.
class _DetectedPanel extends ConsumerStatefulWidget {
  const _DetectedPanel({required this.profileId, required this.onTracked});

  final int profileId;
  final VoidCallback onTracked;

  @override
  ConsumerState<_DetectedPanel> createState() => _DetectedPanelState();
}

class _DetectedPanelState extends ConsumerState<_DetectedPanel> {
  final _hidden = <String>{};

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<DetectedRecurring>>(
      future: repo.detectRecurring(profileId: widget.profileId),
      builder: (context, snap) {
        final found = [
          for (final d in snap.data ?? const <DetectedRecurring>[])
            if (!_hidden.contains(d.key)) d,
        ];
        if (found.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            SectionHeader(
              'Found in your history',
              icon: Icons.auto_awesome_outlined,
              info: const InfoButton(
                title: 'Found in your history',
                body: [
                  'Clearly looked through your transactions for charges and '
                      'deposits that come back on a steady rhythm for about '
                      'the same amount. It takes at least three in a row, '
                      '(two for a yearly one) so a one-off is never '
                      'mistaken for a pattern.',
                  'Track one and it becomes a bill, a paycheck schedule or a '
                      'recurring transaction, so it shows up in Coming up and '
                      'in your cash projection. Nothing is added until you '
                      'choose it.',
                  'This is worked out here from your own history. The bank '
                      'does not say what repeats.',
                ],
              ),
            ),
            Card(
              child: Column(
                children: [
                  for (final d in found)
                    ListTile(
                      leading: Icon(
                        d.type == EntryType.income
                            ? Icons.south_west
                            : Icons.autorenew,
                        color: d.type == EntryType.income
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      title: Text(d.name, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${d.cadence} · '
                        '${d.variable ? 'about ' : ''}${fmtCents(d.typicalCents)}'
                        ' · next around ${_UpcomingScreenState._fmtDate(d.next)}'
                        ' · seen ${d.count} times',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Not recurring',
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () =>
                                setState(() => _hidden.add(d.key)),
                          ),
                          FilledButton.tonal(
                            onPressed: () async {
                              await repo.trackDetected(
                                  profileId: widget.profileId, d: d);
                              if (!mounted) return;
                              setState(() => _hidden.add(d.key));
                              widget.onTracked();
                            },
                            child: const Text('Track'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}
