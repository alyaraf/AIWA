import 'package:flutter/material.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import 'aiwa_button.dart';

enum EmptyStateTone { plum, rose, gold }

/// Icon + title + body + primary/secondary action — `EmptyState` in the kit.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final EmptyStateTone tone;
  final bool compact;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.tone = EmptyStateTone.plum,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    late Color bg, fg;
    switch (tone) {
      case EmptyStateTone.plum:
        bg = AppColors.plum100;
        fg = AppColors.plum700;
        break;
      case EmptyStateTone.rose:
        bg = AppColors.rose100;
        fg = AppColors.rose700;
        break;
      case EmptyStateTone.gold:
        bg = AppColors.gold100;
        fg = AppColors.gold700;
        break;
    }
    final circle = compact ? 52.0 : 64.0;

    return Center(
      child: Padding(
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 26, vertical: 30)
            : const EdgeInsets.symmetric(horizontal: 30, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // aiwa-pop 320ms (states.jsx:88).
            TweenAnimationBuilder<double>(
              tween: Tween(begin: .86, end: 1),
              duration: AppTheme.dur3,
              curve: AppTheme.easeSoft,
              builder: (_, v, c) => Opacity(
                opacity: ((v - .86) / .14).clamp(0.0, 1.0),
                child: Transform.scale(scale: v, child: c),
              ),
              child: Container(
                width: circle,
                height: circle,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, size: compact ? 22 : 27, color: fg),
              ),
            ),
            // Kit column gap 3 on top of marginBottom 14 / 6.
            const SizedBox(height: 17),
            Text(
              title,
              style: AppTextStyles.h3.copyWith(
                fontSize: compact ? 19 : 22,
                letterSpacing: 0,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 9),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 270),
                child: Text(
                  subtitle!,
                  style: AppTextStyles.bodySm.copyWith(
                    fontSize: 13.5,
                    color: AppColors.ink3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (actionLabel != null || secondaryLabel != null) ...[
              const SizedBox(height: 21),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 250),
                child: Column(
                  children: [
                    if (actionLabel != null)
                      AiwaButton(
                        label: actionLabel!,
                        onPressed: onAction,
                        fullWidth: true,
                      ),
                    if (secondaryLabel != null) ...[
                      const SizedBox(height: 8),
                      AiwaButton(
                        label: secondaryLabel!,
                        onPressed: onSecondary,
                        variant: AiwaButtonVariant.ghost,
                        size: AiwaButtonSize.sm,
                        fullWidth: true,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Failed request with Try again — `ErrorState` in the kit.
class ErrorState extends StatelessWidget {
  final String? title;
  final String? body;
  final VoidCallback? onRetry;
  final bool compact;

  const ErrorState({
    super.key,
    this.title,
    this.body,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final circle = compact ? 52.0 : 64.0;
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 26, vertical: 30)
            : const EdgeInsets.symmetric(horizontal: 30, vertical: 46),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: circle,
              height: circle,
              decoration: BoxDecoration(
                color: AppColors.danger100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                size: compact ? 22 : 27,
                color: AppColors.danger700,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title ?? l.errLoadTitle,
              style: AppTextStyles.h3.copyWith(
                fontSize: compact ? 19 : 22,
                letterSpacing: 0,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 270),
              child: Text(
                body ?? l.errLoadBody,
                style: AppTextStyles.bodySm.copyWith(
                  fontSize: 13.5,
                  color: AppColors.ink3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 250),
                child: AiwaButton(
                  label: l.commonTryAgain,
                  icon: Icons.refresh_rounded,
                  onPressed: onRetry,
                  fullWidth: true,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
