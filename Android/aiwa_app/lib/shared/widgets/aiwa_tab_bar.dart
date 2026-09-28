import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import 'press_scale.dart';

typedef AiwaTab = ({IconData icon, String label});

/// Frosted bottom tab bar — `TabBar` (components.jsx:203-237) and
/// `ProviderTabBar` (provider-screens.jsx:562-596).
class AiwaTabBar extends StatelessWidget {
  final List<AiwaTab> tabs;
  final int index;
  final ValueChanged<int> onTap;

  /// Tab carrying the rose dot, if any.
  final int? badgeIndex;

  /// Customer 80 / 12, provider 76 / 10.
  final double itemMaxWidth;
  final double itemHPad;

  const AiwaTabBar({
    super.key,
    required this.tabs,
    required this.index,
    required this.onTap,
    this.badgeIndex,
    this.itemMaxWidth = 80,
    this.itemHPad = 12,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.paper.withValues(alpha: 0.94),
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          padding: EdgeInsets.fromLTRB(
            4,
            8,
            4,
            math.max(26, MediaQuery.paddingOf(context).bottom),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: _TabItem(
                    tab: tabs[i],
                    active: i == index,
                    badge: i == badgeIndex,
                    maxWidth: itemMaxWidth,
                    hPad: itemHPad,
                    // Re-tapping the active tab is a no-op (prototype.jsx:565).
                    onTap: () => i == index ? null : onTap(i),
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
  final AiwaTab tab;
  final bool active;
  final bool badge;
  final double maxWidth;
  final double hPad;
  final VoidCallback onTap;

  const _TabItem({
    required this.tab,
    required this.active,
    required this.badge,
    required this.maxWidth,
    required this.hPad,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.plum700 : AppColors.ink3;
    return PressScale(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        // Shrink-wrap vertically: bottomNavigationBar's max height is the
        // whole screen, and a plain Center would fill it.
        heightFactor: 1,
        // flex: 1, maxWidth: 80 — the pill fills the slot, not the label.
        child: AnimatedContainer(
          duration: AppTheme.dur2,
          curve: AppTheme.easeSoft,
          width: maxWidth,
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 6),
          decoration: BoxDecoration(
            color: active ? AppColors.plum100 : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radius14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(tab.icon, size: 22, color: color),
                  if (badge)
                    PositionedDirectional(
                      top: -2,
                      end: -4,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.rose500,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.paper, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                tab.label,
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
