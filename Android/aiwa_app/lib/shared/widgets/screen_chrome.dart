import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import 'aiwa_icon_button.dart';
import 'eyebrow_label.dart';

/// Standard mobile screen chrome from the design kit:
/// [ScreenHeader], [PageTitle], [StickyBar], [SettingsRow], [InlineBanner],
/// [EndOfList], [MetaDot] and the [AiwaWordmark].

/// Back button + eyebrow + serif title — `ScreenHeader` in the kit.
class ScreenHeader extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  /// Small accent text after the title, e.g. "· 3 new".
  final String? titleSuffix;
  final double titleSize;

  const ScreenHeader({
    super.key,
    this.eyebrow,
    required this.title,
    this.onBack,
    this.trailing,
    this.titleSuffix,
    this.titleSize = 22,
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
                if (eyebrow != null) EyebrowLabel(eyebrow!),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    text: title,
                    style: AppTextStyles.h3.copyWith(
                      fontSize: titleSize,
                      height: 1.1,
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
          if (trailing != null) trailing!,
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

  const PageTitle({
    super.key,
    required this.eyebrow,
    required this.title,
    this.trailing,
    this.bottom = 10,
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
                  style: AppTextStyles.h1.copyWith(fontSize: 28, height: 1.05),
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
        14 + MediaQuery.paddingOf(context).bottom,
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
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: danger ? AppColors.danger100 : AppColors.plum100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 17,
            color: danger ? AppColors.danger700 : AppColors.plum700,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w500,
                  color: danger ? AppColors.danger700 : AppColors.ink,
                  height: 1.3,
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
            padding: const EdgeInsets.only(left: 8),
            child: Text(value!, style: AppTextStyles.meta),
          ),
        if (!danger && onTap != null) ...[
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.ink3),
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

  const InlineBanner({
    super.key,
    this.tone = BannerTone.info,
    this.icon,
    this.title,
    this.body,
    this.action,
    this.onAction,
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
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon ?? defaultIcon, size: 16, color: fg),
          ),
          const SizedBox(width: 10),
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
                      color: fg,
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  action!,
                  style: AppTextStyles.labelSm.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "That's everything" divider at the end of a list — `EndOfList`.
class EndOfList extends StatelessWidget {
  final String label;
  const EndOfList({super.key, this.label = "That's everything"});

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
              label,
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

/// 3px separator dot used between meta items (rating · distance · open).
class MetaDot extends StatelessWidget {
  final Color? color;
  const MetaDot({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: color ?? AppColors.ink3,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Soft radial highlight used on the dark hero gradients.
class AiwaGlow extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const AiwaGlow({
    super.key,
    required this.size,
    required this.color,
    this.opacity = 0.35,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withOpacity(opacity), color.withOpacity(0)],
          ),
        ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'AIWA',
          style: AppTextStyles.display.copyWith(
            fontSize: size,
            height: 1,
            letterSpacing: -0.02 * size,
            color: color ?? AppColors.plum900,
          ),
        ),
        Container(
          width: size * 0.14,
          height: size * 0.14,
          margin: EdgeInsets.only(left: size * 0.08, bottom: size * 0.1),
          decoration: BoxDecoration(
            color: dotColor ?? AppColors.rose500,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}
