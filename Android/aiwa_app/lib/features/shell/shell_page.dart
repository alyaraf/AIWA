import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';

class ShellPage extends StatelessWidget {
  final Widget child;

  const ShellPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bone,
      extendBody: true,
      body: child,
      bottomNavigationBar: _TabBar(
        index: _currentIndex(GoRouterState.of(context).uri.toString()),
      ),
    );
  }

  int _currentIndex(String location) {
    if (location.startsWith(AppRoutes.search)) return 1;
    if (location.startsWith(AppRoutes.bookings)) return 2;
    if (location.startsWith(AppRoutes.saved)) return 3;
    if (location.startsWith(AppRoutes.profile)) return 4;
    return 0;
  }
}

/// Frosted bottom tab bar — `TabBar` in the kit.
class _TabBar extends StatelessWidget {
  final int index;
  const _TabBar({required this.index});

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (Icons.home_outlined, Icons.home_rounded, 'Home', AppRoutes.home),
      (
        Icons.search_rounded,
        Icons.search_rounded,
        'Discover',
        AppRoutes.search,
      ),
      (
        Icons.event_available_outlined,
        Icons.event_available_rounded,
        'Bookings',
        AppRoutes.bookings,
      ),
      (
        Icons.favorite_border_rounded,
        Icons.favorite_rounded,
        'Saved',
        AppRoutes.saved,
      ),
      (
        Icons.person_outline_rounded,
        Icons.person_rounded,
        'Profile',
        AppRoutes.profile,
      ),
    ];

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.paper.withOpacity(0.94),
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          padding: EdgeInsets.fromLTRB(
            4,
            8,
            4,
            8 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: _TabItem(
                    icon: tabs[i].$1,
                    activeIcon: tabs[i].$2,
                    label: tabs[i].$3,
                    active: i == index,
                    onTap: () => context.go(tabs[i].$4),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.plum700 : AppColors.ink3;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedContainer(
          duration: AppTheme.dur2,
          curve: AppTheme.easeSoft,
          constraints: const BoxConstraints(maxWidth: 80),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? AppColors.plum100 : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
                style: AppTextStyles.labelSm.copyWith(
                  fontSize: 11,
                  color: color,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
