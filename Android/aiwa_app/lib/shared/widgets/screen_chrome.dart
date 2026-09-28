import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import 'aiwa_icon_button.dart';
import 'eyebrow_label.dart';
import 'press_scale.dart';

/// Standard mobile screen chrome from the design kit:
/// [ScreenHeader], [PageTitle], [StickyBar], [SettingsRow], [InlineBanner],
/// [EndOfList], [MetaDot] and the [AiwaWordmark].

/// Back button + eyebrow + serif title — `ScreenHeader` in the kit.
class ScreenHeader extends StatelessWidget {
  final String? eyebrow;
  final Color? eyebrowColor;
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  /// Small accent text after the title, e.g. "· 3 new".
  final String? titleSuffix;
  final double titleSize;
  final double titleHeight;

  const ScreenHeader({
    super.key,
    this.eyebrow,
    this.eyebrowColor,
    required this.title,
    this.onBack,
    this.trailing,
    this.titleSuffix,
    this.titleSize = 22,
    this.titleHeight = 1.1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTheme.gutter,
        MediaQuery.paddingOf(context).top + 14,
        AppTheme.gutter,
        8,
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            AiwaIconButton(icon: Icons.arrow_back_rounded, onTap: onBack),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null)
                  EyebrowLabel(eyebrow!, color: eyebrowColor),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    text: title,
                    style: AppTextStyles.h3.copyWith(
                      fontSize: titleSize,
                      height: titleHeight,
                      letterSpacing: 0,
                    ),
                    children: [
                      if (titleSuffix != null)
                        TextSpan(
                          text: '  $titleSuffix',
                          style: AppTextStyles.label.copyWith(
                            fontSize: 13,
                            color: AppColors.rose500,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

/// Large tab-root title ("Bookings", "Saved", "Discover") with an eyebrow.
class PageTitle extends StatelessWidget {
  final String eyebrow;
  final String title;
  final Widget? trailing;
  final double bottom;

  /// Null keeps h1's tracking; some kit titles use none (BOOK-C4).
  final double? letterSpacing;

  const PageTitle({
    super.key,
    required this.eyebrow,
    required this.title,
    this.trailing,
    this.bottom = 10,
    this.letterSpacing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTheme.gutter,
        MediaQuery.paddingOf(context).top + 22,
        AppTheme.gutter,
        bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EyebrowLabel(eyebrow),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: AppTextStyles.h1.copyWith(
                    fontSize: 28,
                    height: 1.05,
                    letterSpacing: letterSpacing,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// White bottom action bar with a hairline top border — `StickyBar`.
class StickyBar extends StatelessWidget {
  final Widget child;
  const StickyBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.paper,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppTheme.gutter,
        14,
        AppTheme.gutter,
        // states.jsx:431 bottom 32 already includes the home indicator.
        math.max(32, 14 + MediaQuery.paddingOf(context).bottom),
      ),
      child: child,
    );
  }
}

/// Standard list row with icon tile — `SettingsRow` in the kit.
class SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final String? value;
  final VoidCallback? onTap;
  final bool danger;
  final bool boxed;
  final bool showDivider;

  /// Replaces the chevron, e.g. an expand arrow or a toggle.
  final Widget? right;

  /// Gold icon tile — the kit's `tone="gold"`.
  final bool gold;

  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    this.sub,
    this.value,
    this.onTap,
    this.danger = false,
    this.boxed = false,
    this.showDivider = true,
    this.right,
    this.gold = false,
  });

  @override
  Widget build(BuildContext context) {
    final (tileBg, tileFg) = danger
        ? (AppColors.danger100, AppColors.danger700)
        : gold
        ? (AppColors.gold100, AppColors.gold700)
        : (AppColors.plum100, AppColors.plum700);
    final row = Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: tileBg,
            borderRadius: BorderRadius.circular(boxed ? 11 : 10),
          ),
          child: Icon(icon, size: 17, color: tileFg),
        ),
        SizedBox(width: boxed ? 13 : 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.body.copyWith(
                  fontSize: boxed ? 14 : null,
                  fontWeight: boxed ? FontWeight.w600 : FontWeight.w500,
                  color: danger ? AppColors.danger700 : AppColors.ink,
                ),
              ),
              if (sub != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    sub!,
                    style: AppTextStyles.micro.copyWith(fontSize: 11.5),
                  ),
                ),
            ],
          ),
        ),
        if (value != null)
          Padding(
            padding: EdgeInsetsDirectional.only(start: boxed ? 13 : 14),
            child: Text(
              value!,
              style: boxed
                  ? AppTextStyles.meta.copyWith(fontSize: 12.5)
                  : AppTextStyles.meta,
            ),
          ),
        if (right != null) ...[
          SizedBox(width: boxed ? 13 : 14),
          right!,
        ] else if (onTap != null && (boxed || !danger)) ...[
          SizedBox(width: boxed ? 13 : 14),
          Icon(
            Icons.chevron_right_rounded,
            size: boxed ? 17 : 16,
            color: boxed ? AppColors.ink4 : AppColors.ink3,
          ),
        ],
      ],
    );

    if (boxed) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: row,
        ),
      );
    }
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(bottom: BorderSide(color: AppColors.divider))
              : null,
        ),
        child: row,
      ),
    );
  }
}

enum BannerTone { info, warn, danger, success, plum, gold }

/// Contextual notice — `InlineBanner` in the kit.
class InlineBanner extends StatelessWidget {
  final BannerTone tone;
  final IconData? icon;
  final String? title;
  final String? body;
  final String? action;
  final VoidCallback? onAction;

  /// Sign-in error box (auth-screens.jsx:942): tighter padding, radius 10.
  final bool compact;

  const InlineBanner({
    super.key,
    this.tone = BannerTone.info,
    this.icon,
    this.title,
    this.body,
    this.action,
    this.onAction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    late Color bg, fg;
    late IconData defaultIcon;
    switch (tone) {
      case BannerTone.info:
        bg = AppColors.info100;
        fg = AppColors.info700;
        defaultIcon = Icons.info_outline_rounded;
        break;
      case BannerTone.warn:
        bg = AppColors.warn100;
        fg = AppColors.warn700;
        defaultIcon = Icons.warning_amber_rounded;
        break;
      case BannerTone.danger:
        bg = AppColors.danger100;
        fg = AppColors.danger700;
        defaultIcon = Icons.report_outlined;
        break;
      case BannerTone.success:
        bg = AppColors.success100;
        fg = AppColors.success700;
        defaultIcon = Icons.check_circle_outline_rounded;
        break;
      case BannerTone.plum:
        bg = AppColors.plum100;
        fg = AppColors.plum700;
        defaultIcon = Icons.auto_awesome_outlined;
        break;
      case BannerTone.gold:
        bg = AppColors.gold100;
        fg = AppColors.gold700;
        defaultIcon = Icons.auto_awesome_outlined;
        break;
    }
    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
          : const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(compact ? 10 : 14),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                icon ?? defaultIcon,
                size: compact ? 14 : 16,
                color: fg,
              ),
            ),
            SizedBox(width: compact ? 8 : 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      style: AppTextStyles.label.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  if (title != null && body != null) const SizedBox(height: 2),
                  if (body != null)
                    Text(
                      body!,
                      style: AppTextStyles.micro.copyWith(
                        fontSize: 12.5,
                        color: fg.withValues(alpha: .92),
                        height: 1.5,
                      ),
                    ),
                ],
              ),
            ),
            if (action != null)
              // alignSelf: center (states.jsx:165).
              Align(
                child: PressScale(
                  onTap: onAction,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 10),
                    child: Text(
                      action!,
                      style: AppTextStyles.labelSm.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "That's everything" divider at the end of a list — `EndOfList`.
class EndOfList extends StatelessWidget {
  final String? label;
  const EndOfList({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: AppColors.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label ?? AppLocalizations.of(context).endOfList,
              style: AppTextStyles.micro.copyWith(
                fontSize: 11.5,
                color: AppColors.ink4,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: AppColors.divider)),
        ],
      ),
    );
  }
}

/// Page picker with a 3-page window — `Pagination` in states.jsx.
class AiwaPagination extends StatelessWidget {
  final int page;
  final int totalPages;
  final ValueChanged<int> onPage;
  final bool compact;

  const AiwaPagination({
    super.key,
    required this.page,
    required this.totalPages,
    required this.onPage,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();
    final from = (page - 1).clamp(1, (totalPages - 2).clamp(1, totalPages));
    final to = (from + 2).clamp(1, totalPages);

    Widget box({
      required Widget child,
      required bool selected,
      VoidCallback? onTap,
    }) => Semantics(
      button: true,
      enabled: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null && !selected ? .5 : 1,
          child: Container(
            constraints: const BoxConstraints(minWidth: 32),
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.plum700 : AppColors.paper,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? Colors.transparent : AppColors.divider,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );

    Widget chevron(IconData icon, int target, bool enabled) => box(
      selected: false,
      onTap: enabled ? () => onPage(target) : null,
      child: Icon(
        icon,
        size: 15,
        color: enabled ? AppColors.plum700 : AppColors.ink4,
      ),
    );

    return Padding(
      padding: EdgeInsets.only(top: compact ? 14 : 18, bottom: compact ? 4 : 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 6,
        children: [
          chevron(Icons.chevron_left_rounded, page - 1, page > 1),
          for (var n = from; n <= to; n++)
            box(
              selected: n == page,
              onTap: () => onPage(n),
              child: Text(
                '$n',
                style: AppTextStyles.label.copyWith(
                  color: n == page ? AppColors.paper : AppColors.ink2,
                ),
              ),
            ),
          if (totalPages > from + 2)
            Text(
              '…',
              style: AppTextStyles.meta.copyWith(color: AppColors.ink4),
            ),
          chevron(Icons.chevron_right_rounded, page + 1, page < totalPages),
        ],
      ),
    );
  }
}

/// 3px separator dot used between meta items (rating · distance · open).
class MetaDot extends StatelessWidget {
  final Color? color;

  /// Horizontal margin on each side of the dot.
  final double gap;
  const MetaDot({super.key, this.color, this.gap = 6});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      margin: EdgeInsets.symmetric(horizontal: gap),
      decoration: BoxDecoration(
        color: color ?? AppColors.ink3,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Soft radial highlight used on the dark hero gradients.
class AiwaGlow extends StatelessWidget {
  final double? size;
  final Color color;
  final double opacity;

  /// Where the gradient reaches transparent (CSS `transparent 60%` = .6).
  final double stop;

  /// Centre for [AiwaGlow.fill].
  final Alignment center;

  const AiwaGlow({
    super.key,
    required double this.size,
    required this.color,
    this.opacity = 0.35,
    this.stop = 1,
  }) : center = Alignment.center;

  /// Fills its parent like CSS `radial-gradient(circle at x y, …)`: a
  /// farthest-corner circle around [center], e.g. `30% 25%` = (-.4, -.5).
  const AiwaGlow.fill({
    super.key,
    required this.center,
    required this.color,
    required this.opacity,
    required this.stop,
  }) : size = null;

  RadialGradient _gradient(double radius) => RadialGradient(
    center: center,
    radius: radius,
    colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)],
    stops: [0, stop],
  );

  @override
  Widget build(BuildContext context) {
    if (size case final size?) {
      return IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _gradient(.5),
          ),
        ),
      );
    }
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (_, c) {
          final w = c.maxWidth, h = c.maxHeight;
          final cx = (center.x + 1) / 2 * w, cy = (center.y + 1) / 2 * h;
          final far = math.sqrt(
            math.pow(math.max(cx, w - cx), 2) +
                math.pow(math.max(cy, h - cy), 2),
          );
          // RadialGradient.radius is a fraction of the box's shortest side.
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: _gradient(far / math.min(w, h)),
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

/// "AIWA" serif wordmark with the accent dot.
class AiwaWordmark extends StatelessWidget {
  final double size;
  final Color? color;
  final Color? dotColor;

  const AiwaWordmark({super.key, this.size = 56, this.color, this.dotColor});

  @override
  Widget build(BuildContext context) {
    // Laid out like the 320x100 SVG (prototype.jsx:5-12), [size] = height.
    return SizedBox(
      width: size * 3.2,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Text(
              'AIWA',
              style: AppTextStyles.display.copyWith(
                fontSize: size * 0.84,
                height: 1,
                letterSpacing: -2 * size / 100,
                color: color ?? AppColors.plum900,
              ),
            ),
          ),
          Positioned(
            left: size * 3.01,
            top: size * 0.62,
            child: Container(
              width: size * 0.12,
              height: size * 0.12,
              decoration: BoxDecoration(
                color: dotColor ?? AppColors.rose500,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
