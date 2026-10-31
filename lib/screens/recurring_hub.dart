import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/add_transaction.dart' show showAddTransaction;
import '../widgets/common.dart' show PillTabs;

import '../widgets/lazy_indexed_stack.dart';
import 'bills.dart';
import 'paychecks.dart';
import 'recurring.dart';
import 'transfers.dart';
import 'upcoming.dart';

/// Everything that repeats, in one place: what's coming up next, then each
/// kind of thing that repeats — bills, paychecks, scheduled transfers, and
/// anything else on a schedule. Add anything new with the Add button.
class RecurringHubScreen extends StatefulWidget {
  const RecurringHubScreen({super.key});

  @override
  State<RecurringHubScreen> createState() => _RecurringHubScreenState();
}

class _RecurringHubScreenState extends State<RecurringHubScreen>
    with SingleTickerProviderStateMixin {
  late final _controller = TabController(
    length: 5,
    vsync: this,
    animationDuration: Duration.zero,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
          child: Row(
            children: [
              PillTabs(
                controller: _controller,
                labels: const [
                  'Upcoming',
                  'Bills',
                  'Paychecks',
                  'Transfers',
                  'Other',
                ],
              ),
              const Spacer(),
              // Works in a synced profile too: a schedule is a plan, not a
              // transaction, so the bank is not its source.
              Consumer(
                builder: (context, ref, _) => FilledButton.icon(
                  onPressed: () =>
                      showAddTransaction(context, ref, recurringOnly: true),
                  icon: const Icon(Icons.add),
                  label: const Text('Add recurring'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => LazyIndexedStack(
              index: _controller.index,
              builders: [
                (_) => const UpcomingScreen(),
                (_) => const BillsScreen(),
                (_) => const PaychecksScreen(),
                (_) => const TransfersScreen(),
                (_) => const RecurringTransactionsScreen(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
