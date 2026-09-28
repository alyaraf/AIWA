import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/aiwa_tab_bar.dart';
import '../auth/presentation/bloc/auth_bloc.dart';
import '../auth/presentation/bloc/auth_state.dart';
import '../bookings/domain/repositories/booking_repository.dart';
import 'package:aiwa_app/l10n/l10n.dart';

class ShellPage extends StatefulWidget {
  final Widget child;

  const ShellPage({super.key, required this.child});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  /// Rose dot on Bookings: the signed-in user has a booking in flight.
  // ponytail: fetched once per sign-in, not live; refresh on booking events
  // if the dot needs to track changes while the shell is mounted.
  Future<bool>? _badge;
  int? _badgeUser;

  Future<bool> _hasActiveBooking() async {
    final r = await sl<BookingRepository>().getMyBookings(
      status: 'PENDING,ACCEPTED,ON_THE_WAY,ARRIVED,IN_PROGRESS',
      size: 20,
    );
    return r.fold((_) => false, (page) => page.content.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final user = auth is AuthAuthenticated ? auth.user.id : null;
    if (user != _badgeUser) {
      _badgeUser = user;
      _badge = user == null ? null : _hasActiveBooking();
    }
    final index = _currentIndex(GoRouterState.of(context).uri.toString());
    // Back on a tab root returns Home instead of exiting (DS-V01).
    // ponytail: Home still exits (Android convention); the prototype's pop()
    // is a no-op there — set canPop: false if design wants that.
    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.home);
      },
      child: Scaffold(
        backgroundColor: AppColors.bone,
        extendBody: true,
        body: widget.child,
        bottomNavigationBar: FutureBuilder<bool>(
          future: _badge,
          builder: (context, snap) => AiwaTabBar(
            tabs: _tabs(AppLocalizations.of(context)),
            index: index,
            badgeIndex: (snap.data ?? false) ? 2 : null,
            onTap: (i) => context.go(_routes[i]),
          ),
        ),
      ),
    );
  }

  static const _routes = [
    AppRoutes.home,
    AppRoutes.search,
    AppRoutes.bookings,
    AppRoutes.saved,
    AppRoutes.profile,
  ];

  static List<AiwaTab> _tabs(AppLocalizations l) => [
    (icon: Icons.home_outlined, label: l.tabHome),
    (icon: Icons.search_rounded, label: l.tabDiscover),
    (icon: Icons.event_available_outlined, label: l.tabBookings),
    (icon: Icons.favorite_border_rounded, label: l.tabSaved),
    (icon: Icons.person_outline_rounded, label: l.tabProfile),
  ];

  int _currentIndex(String location) {
    if (location.startsWith(AppRoutes.search)) return 1;
    if (location.startsWith(AppRoutes.bookings)) return 2;
    if (location.startsWith(AppRoutes.saved)) return 3;
    if (location.startsWith(AppRoutes.profile)) return 4;
    return 0;
  }
}
