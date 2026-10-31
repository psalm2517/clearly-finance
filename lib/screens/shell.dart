import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/notifications.dart';
import '../data/repository.dart';
import '../main.dart';
import '../theme/catppuccin.dart';
import '../theme/flavor_provider.dart';
import '../widgets/add_transaction.dart';
import '../widgets/clearly_mark.dart';
import '../widgets/common.dart' show AmbientBackground;
import 'accounts_hub.dart';
import 'bank_sync.dart' show simpleFinClientProvider;
import 'budget.dart';
import 'cash_flow.dart';
import 'dashboard.dart';
import '../widgets/lazy_indexed_stack.dart';
import 'nav.dart';
import 'recurring_hub.dart';
import 'settings.dart';
import 'transactions.dart';

/// The most recent 1:30 AM, local time, at or before [now].
DateTime lastSyncSlot(DateTime now) {
  final today = DateTime(now.year, now.month, now.day, 1, 30);
  return today.isAfter(now)
      ? DateTime(now.year, now.month, now.day - 1, 1, 30)
      : today;
}

/// Whether the daily bank sync is owed: it is due once a day, at 1:30 AM, and
/// is owed whenever the last successful sync is older than the most recent
/// 1:30 AM. Because it compares against the clock rather than waiting for a
/// timer, a night the app was closed or the computer asleep is made up at the
/// next chance, and a day is never skipped.
bool dailySyncDue(DateTime now, DateTime? lastSyncAt) =>
    lastSyncAt == null || lastSyncAt.isBefore(lastSyncSlot(now));

/// Desktop shell: NavigationRail sidebar + content. Only admins see the
/// profile switcher; non-admins have no indication other profiles exist.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  int? _caughtUpFor;
  Timer? _poll;
  var _syncing = false;
  DateTime? _lastAttempt;

  /// Syncs the bank feed once a day. The check is cheap and local, so it runs
  /// when Clearly opens, when it comes back from sleep, and every few
  /// minutes while it is open; it only reaches the network when a day's sync
  /// is actually owed (see [dailySyncDue]). A failed attempt is retried at
  /// most once an hour, well inside the bridge's daily limit.
  Future<void> _syncIfDue() async {
    if (_syncing || !mounted) return;
    final now = DateTime.now();
    final last = _lastAttempt;
    if (last != null && now.difference(last) < const Duration(hours: 1)) return;
    final profile =
        ref.read(activeProfileProvider) ?? ref.read(loggedInProfileProvider);
    if (profile == null) return;
    _syncing = true;
    try {
      final repo = ref.read(repositoryProvider);
      final connections = await repo
          .watchSimpleFinConnections(profileId: profile.id)
          .first;
      if (connections.isEmpty) return;
      final owed = connections.any((c) => dailySyncDue(now, c.lastSyncAt));
      if (!owed) return;
      _lastAttempt = now;
      await repo.syncSimpleFin(
        profileId: profile.id,
        client: ref.read(simpleFinClientProvider),
      );
    } catch (_) {
      // The outcome, good or bad, is kept on the connection and shown in
      // Settings; a failed attempt should not interrupt anything.
    } finally {
      _syncing = false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll = Timer.periodic(const Duration(minutes: 5), (_) => _syncIfDue());
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncIfDue());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncIfDue();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  /// Brings the books up to date for whoever is being viewed: generate
  /// upcoming paychecks, mark ones whose payday has passed as received, and
  /// record autopay bills that have come due. Runs on entry and on profile
  /// switch so it never depends on visiting a particular screen.
  void _catchUp(int profileId) {
    if (_caughtUpFor == profileId) return;
    _caughtUpFor = profileId;
    Future.microtask(() async {
      final repo = ref.read(repositoryProvider);
      final now = DateTime.now();
      await repo.generateDuePaychecks(
        profileId: profileId,
        until: now.add(HomebaseRepository.paycheckHorizon),
      );
      await repo.materializeReceivedPaychecks(profileId: profileId);
      await repo.materializeAutopayPayments(profileId: profileId, month: now);
      await repo.materializeDueTransfers(profileId: profileId, now: now);
      await repo.materializeDueRecurringTransactions(
        profileId: profileId,
        now: now,
      );
      // Tidying what the bank has already delivered is local work, so it
      // happens on every launch rather than waiting for the next sync.
      try {
        final connections = await repo
            .watchSimpleFinConnections(profileId: profileId)
            .first;
        if (connections.isNotEmpty) {
          await repo.reconcileBankMovements(profileId, DateTime.now());
          await repo.tidyBankEntries(profileId);
        }
      } catch (_) {}
      // A point for today even on a day with no edits.
      await repo.recordNetWorthSnapshot(profileId: profileId);
      await repo.recordAccountSnapshotsForToday(profileId: profileId);

      // Nudge about anything due soon. The dashboard panel is the reliable
      // surface; this is the extra desktop/phone notification on top.
      final reminders = await repo.upcomingReminders(profileId: profileId);
      for (final reminder in reminders) {
        await NotificationService.instance.showReminder(reminder);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = ref.watch(loggedInProfileProvider)!;
    final active = ref.watch(activeProfileProvider) ?? loggedIn;
    _catchUp(active.id);
    final flavor = ref.watch(flavorProvider);

    final dest = ref.watch(navProvider);

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.tab): _StepDestIntent(1),
        SingleActivator(LogicalKeyboardKey.tab, shift: true): _StepDestIntent(
          -1,
        ),
      },
      child: Actions(
        actions: {_StepDestIntent: _StepDestAction(ref)},
        child: Focus(
          autofocus: true,
          child: _shell(context, ref, dest, flavor, loggedIn, active),
        ),
      ),
    );
  }

  Widget _shell(
    BuildContext context,
    WidgetRef ref,
    Dest dest,
    CatppuccinFlavor flavor,
    Profile loggedIn,
    Profile active,
  ) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: AmbientBackground(
        child: _scaffold(context, ref, dest, flavor, loggedIn, active),
      ),
    );
  }

  Widget _scaffold(
    BuildContext context,
    WidgetRef ref,
    Dest dest,
    CatppuccinFlavor flavor,
    Profile loggedIn,
    Profile active,
  ) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        shape: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
        title: Text(dest.title),
        actions: [
          // The one place to record money, from any screen. A synced
          // profile has none: the bank is its only source.
          if (!active.isSynced)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FilledButton.icon(
                onPressed: () => showAddTransaction(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ),
          if (loggedIn.isAdmin) _ProfileSwitcher(active: active),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          AppSidebar(active: active, flavor: flavor),
          Expanded(
            child: LazyIndexedStack(
              index: dest.index,
              // Same order as the Dest enum.
              builders: [
                (_) => const DashboardScreen(),
                (_) => const AccountsHubScreen(),
                (_) => const TransactionsScreen(),
                (_) => const CashFlowScreen(),
                (_) => const BudgetScreen(),
                (_) => const RecurringHubScreen(),
                (_) => const SettingsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSwitcher extends ConsumerWidget {
  const _ProfileSwitcher({required this.active});
  final Profile active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    return FutureBuilder<List<Profile>>(
      future: repo.allProfiles(),
      builder: (context, snapshot) {
        final profiles = snapshot.data ?? [active];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: DropdownButton<int>(
            value: active.id,
            underline: const SizedBox.shrink(),
            icon: const Icon(Icons.swap_horiz),
            items: [
              for (final p in profiles)
                DropdownMenuItem(
                  value: p.id,
                  child: Text('Viewing: ${p.name}'),
                ),
            ],
            onChanged: (id) {
              if (id == null) return;
              ref.read(activeProfileProvider.notifier).state = profiles
                  .firstWhere((p) => p.id == id);
            },
          ),
        );
      },
    );
  }
}

const _navIcons = <Dest, (IconData, IconData)>{
  Dest.dashboard: (Icons.space_dashboard_outlined, Icons.space_dashboard),
  Dest.accounts: (Icons.account_balance_outlined, Icons.account_balance),
  Dest.transactions: (Icons.swap_horiz_outlined, Icons.swap_horiz),
  Dest.cashFlow: (Icons.alt_route_outlined, Icons.alt_route),
  Dest.budget: (Icons.pie_chart_outline, Icons.pie_chart),
  Dest.recurring: (Icons.autorenew_outlined, Icons.autorenew),
  Dest.settings: (Icons.settings_outlined, Icons.settings),
};

/// The left sidebar: wordmark, destinations as icon + label rows, and the
/// profile's mode, theme and log out at the foot.
class AppSidebar extends ConsumerWidget {
  const AppSidebar({required this.active, required this.flavor});

  final Profile active;
  final CatppuccinFlavor flavor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final selected = ref.watch(navProvider);
    final muted = scheme.onSurfaceVariant;

    Widget item(Dest d) {
      final on = d == selected;
      final (off, onIcon) = _navIcons[d]!;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => ref.read(navProvider.notifier).state = d,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: on
                  ? scheme.primary.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  on ? onIcon : off,
                  size: 19,
                  color: on ? scheme.primary : muted,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    d.title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                      color: on ? scheme.onSurface : muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget footerButton(IconData icon, String label, VoidCallback onTap) =>
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(icon, size: 18, color: muted),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, color: muted),
                  ),
                ),
              ],
            ),
          ),
        );

    return Container(
      width: 216,
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            child: Row(
              children: [
                const ClearlyMark(height: 26),
                const SizedBox(width: 10),
                Text(
                  'Clearly',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          for (final d in Dest.values) item(d),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                Icon(
                  active.isSynced ? Icons.sync : Icons.edit_note,
                  size: 15,
                  color: muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${active.name} · ${active.isSynced ? 'Synced' : 'Manual'}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ),
              ],
            ),
          ),
          footerButton(
            flavor.isDark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
            flavor.isDark ? 'Light mode' : 'Dark mode',
            () => ref.read(flavorProvider.notifier).toggleLightDark(),
          ),
          footerButton(Icons.logout, 'Log out', () {
            ref.read(navProvider.notifier).state = Dest.dashboard;
            ref.read(loggedInProfileProvider.notifier).state = null;
            ref.invalidate(activeProfileProvider);
          }),
        ],
      ),
    );
  }
}

/// Tab and Shift+Tab step through the sidebar destinations.
class _StepDestIntent extends Intent {
  const _StepDestIntent(this.delta);
  final int delta;
}

class _StepDestAction extends Action<_StepDestIntent> {
  _StepDestAction(this.ref);
  final WidgetRef ref;

  // While typing in a field Tab keeps its usual job of moving between
  // fields, so the shortcut stands aside and the key passes through.
  @override
  bool isEnabled(_StepDestIntent intent) {
    final ctx = FocusManager.instance.primaryFocus?.context;
    return ctx == null ||
        ctx.findAncestorWidgetOfExactType<EditableText>() == null;
  }

  @override
  Object? invoke(_StepDestIntent intent) {
    const all = Dest.values;
    final i = ref.read(navProvider).index;
    ref.read(navProvider.notifier).state =
        all[(i + intent.delta + all.length) % all.length];
    return null;
  }
}
