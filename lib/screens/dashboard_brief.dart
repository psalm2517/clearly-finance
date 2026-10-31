import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repository.dart';
import '../main.dart';
import '../util/money.dart';
import '../widgets/common.dart';
import 'nav.dart';

/// How the month is going, and the few things actually worth a look. Everything is worked out from what is
/// already stored (see [DashboardBriefRepository.dashboardBrief]).
class DashboardBriefSection extends ConsumerWidget {
  const DashboardBriefSection({super.key, required this.profileId});

  final int profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    return FutureBuilder<DashboardBrief>(
      future: repo.dashboardBrief(profileId: profileId),
      builder: (context, snap) {
        final brief = snap.data;
        if (brief == null) return const SizedBox(height: 200);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MonthPace(brief: brief),
            const SizedBox(height: 8),
            _Attention(insights: brief.insights),
          ],
        );
      },
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 0.9,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _MonthPace extends StatelessWidget {
  const _MonthPace({required this.brief});
  final DashboardBrief brief;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final spent = brief.spentThisMonthCents;
    final last = brief.spentLastMonthSoFarCents;
    final diff = spent - last;
    final cats = brief.topCategories;
    final peak = cats.fold<int>(
        1, (m, c) => [m, c.cents, c.typicalCents].reduce((a, b) => a > b ? a : b));

    return GlassCard(
      tint: scheme.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _Label('Spent this month'),
              const Spacer(),
              if (last >= 10000)
                Pill(
                  diff > 0
                      ? '${fmtCents(diff)} above last month'
                      : '${fmtCents(-diff)} below last month',
                  color: diff > 0 ? scheme.error : scheme.primary,
                  fontSize: 11.5,
                ),
            ],
          ),
          const SizedBox(height: 10),
          MoneyText(
            fmtCents(spent),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            last > 0
                ? 'Last month, by this day: ${fmtCents(last)}. Transfers '
                    'are not counted.'
                : 'Transfers are not counted.',
            style: TextStyle(color: muted, height: 1.35),
          ),
          const SizedBox(height: 16),
          if (cats.isEmpty)
            Text('Nothing spent yet this month.',
                style: TextStyle(color: muted))
          else
            for (final c in cats)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CategoryDot(c.category),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(c.category,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13.5)),
                        ),
                        Text(fmtCents(c.cents),
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontFeatures: [FontFeature.tabularFigures()])),
                        if (c.typicalCents > 0)
                          Text('  / ${fmtCents(c.typicalCents)} typical',
                              style: TextStyle(fontSize: 11.5, color: muted)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: c.cents / peak,
                        minHeight: 4,
                        color: c.typicalCents > 0 && c.cents > c.typicalCents
                            ? scheme.error
                            : categoryColor(context, c.category),
                        backgroundColor:
                            scheme.onSurface.withValues(alpha: 0.07),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _Attention extends ConsumerWidget {
  const _Attention({required this.insights});
  final List<Insight> insights;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    if (insights.isEmpty) {
      return Card(
        child: ListTile(
          leading: Icon(Icons.check_circle_outline, color: scheme.primary),
          title: const Text('Nothing needs your attention'),
          subtitle: const Text(
              'No projected shortfall, card use is in range, and spending is '
              'in line with last month.'),
        ),
      );
    }
    Dest dest(InsightLink l) => switch (l) {
          InsightLink.cashFlow => Dest.cashFlow,
          InsightLink.budget => Dest.budget,
          InsightLink.recurring => Dest.recurring,
          InsightLink.accounts => Dest.accounts,
          InsightLink.transactions => Dest.transactions,
        };
    return Card(
      child: Column(
        children: [
          for (final i in insights)
            ListTile(
              onTap: () => ref.read(navProvider.notifier).state = dest(i.link),
              leading: Icon(
                switch (i.tone) {
                  InsightTone.warning => Icons.error_outline,
                  InsightTone.good => Icons.trending_down,
                  InsightTone.info => Icons.insights_outlined,
                },
                color: switch (i.tone) {
                  InsightTone.warning => scheme.error,
                  InsightTone.good => scheme.primary,
                  InsightTone.info => scheme.secondary,
                },
              ),
              title: Text(i.title),
              subtitle: Text(i.detail),
              trailing: const Icon(Icons.chevron_right, size: 20),
            ),
        ],
      ),
    );
  }
}
