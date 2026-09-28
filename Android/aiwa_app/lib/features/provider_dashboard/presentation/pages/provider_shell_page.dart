import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_tab_bar.dart';
import '../../domain/repositories/dashboard_repository.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Provider app frame: tab roots + `ProviderTabBar`
/// (provider-screens.jsx:562-596). Pushed screens sit above it.
class ProviderShellPage extends StatefulWidget {
  final StatefulNavigationShell shell;
  const ProviderShellPage({super.key, required this.shell});

  @override
  State<ProviderShellPage> createState() => _ProviderShellPageState();
}

class _ProviderShellPageState extends State<ProviderShellPage>
    with SingleTickerProviderStateMixin {
  List<AiwaTab> _tabs(AppLocalizations l) => [
    (icon: LucideIcons.layoutDashboard, label: l.tabToday),
    (icon: LucideIcons.calendarCheck, label: l.tabBookings),
    (icon: LucideIcons.list, label: l.tabServices),
    (icon: LucideIcons.clock, label: l.tabSchedule),
    (icon: LucideIcons.user, label: l.tabProfile),
  ];

  /// Tab change fades the new root in (aiwa-fade-in).
  late final _fade = AnimationController(
    vsync: this,
    duration: AppTheme.dur3,
    value: 1,
  );

  /// Rose dot on Bookings while requests are pending.
  bool _pending = false;

  Future<void> _loadBadge() async {
    final r = await sl<DashboardRepository>().getStats();
    if (!mounted) return;
    setState(
      () => _pending = r.fold((_) => false, (s) => s.pendingBookings > 0),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadBadge();
    providerBookingsChanged.addListener(_loadBadge);
  }

  @override
  void dispose() {
    providerBookingsChanged.removeListener(_loadBadge);
    _fade.dispose();
    super.dispose();
  }

  void _onTap(int i) {
    final shell = widget.shell;
    if (i != shell.currentIndex) _fade.forward(from: 0);
    // Re-tapping the active tab returns it to its root.
    shell.goBranch(i, initialLocation: i == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bone,
      extendBody: true,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _fade, curve: AppTheme.easeSoft),
        child: widget.shell,
      ),
      bottomNavigationBar: AiwaTabBar(
        tabs: _tabs(AppLocalizations.of(context)),
        index: widget.shell.currentIndex,
        onTap: _onTap,
        badgeIndex: _pending ? 1 : null,
        itemMaxWidth: 76,
        itemHPad: 10,
      ),
    );
  }
}
