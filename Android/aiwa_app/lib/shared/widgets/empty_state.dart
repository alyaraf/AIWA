import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
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
            Container(
              width: circle,
              height: circle,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, size: compact ? 22 : 27, color: fg),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: AppTextStyles.h3.copyWith(fontSize: compact ? 19 : 22),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
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
            if ((actionLabel != null && onAction != null) ||
                (secondaryLabel != null && onSecondary != null)) ...[
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 250),
                child: Column(
                  children: [
                    if (actionLabel != null && onAction != null)
                      AiwaButton(
                        label: actionLabel!,
                        onPressed: onAction,
                        fullWidth: true,
                      ),
                    if (secondaryLabel != null && onSecondary != null) ...[
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
  final String title;
  final String body;
  final VoidCallback? onRetry;
  final bool compact;

  const ErrorState({
    super.key,
    this.title = "Couldn't load this",
    this.body = 'Something went wrong on our side. Give it another try.',
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final circle = compact ? 52.0 : 64.0;
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
              title,
              style: AppTextStyles.h3.copyWith(fontSize: compact ? 19 : 22),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 270),
              child: Text(
                body,
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
                  label: 'Try again',
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
