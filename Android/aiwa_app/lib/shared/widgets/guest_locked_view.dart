import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'aiwa_button.dart';
import 'eyebrow_label.dart';
import 'package:aiwa_app/l10n/l10n.dart';

/// Shown in place of Saved / Bookings / Profile while browsing as a guest —
/// `GuestLockedScreen` in the kit.
class GuestLockedView extends StatelessWidget {
  final String? title;
  final String body;
  final IconData icon;

  const GuestLockedView({
    super.key,
    this.title,
    required this.body,
    this.icon = Icons.lock_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    return Padding(
      // Kit '68px 24px 32px'; 68 includes the ~54px status bar.
      padding: EdgeInsets.fromLTRB(24, insets.top + 14, 24, 32),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.plum100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: AppColors.plum700),
          ),
          const SizedBox(height: 18),
          EyebrowLabel(AppLocalizations.of(context).guestBrowsing),
          const SizedBox(height: 8),
          Text(
            title ?? AppLocalizations.of(context).guestTitle,
            style: AppTextStyles.h2.copyWith(
              fontSize: 24,
              height: 1.1,
              letterSpacing: 0,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              body,
              style: AppTextStyles.bodySm.copyWith(
                fontSize: 13.5,
                color: AppColors.ink2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const Spacer(),
          AiwaButton(
            label: AppLocalizations.of(context).guestSignIn,
            fullWidth: true,
            size: AiwaButtonSize.lg,
            onPressed: () => context.push(AppRoutes.authGate),
          ),
        ],
      ),
    );
  }
}
