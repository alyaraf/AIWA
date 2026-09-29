import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_event.dart';
import 'aiwa_button.dart';
import 'eyebrow_label.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum SystemTone { plum, danger, warn, info }

/// Full-screen system message — `SystemScreen` in system-screens.jsx.
class SystemScreen extends StatelessWidget {
  final IconData icon;
  final SystemTone tone;
  final String? eyebrow;
  final String title;
  final String body;
  final String? primary;
  final VoidCallback? onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;
  final Widget? child;

  const SystemScreen({
    super.key,
    required this.icon,
    this.tone = SystemTone.plum,
    this.eyebrow,
    required this.title,
    required this.body,
    this.primary,
    this.onPrimary,
    this.secondary,
    this.onSecondary,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      SystemTone.plum => (AppColors.plum100, AppColors.plum700),
      SystemTone.danger => (AppColors.danger100, AppColors.danger700),
      SystemTone.warn => (AppColors.warn100, AppColors.warn700),
      SystemTone.info => (AppColors.info100, AppColors.info700),
    };
    final insets = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: AppColors.bone,
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          26,
          insets.top + 30,
          26,
          insets.bottom + 34,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Center(
              child: PopIn(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                  child: Icon(icon, size: 31, color: fg),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (eyebrow != null)
              EyebrowLabel(eyebrow!, color: fg, textAlign: TextAlign.center),
            const SizedBox(height: 7),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.h1.copyWith(
                fontSize: 27,
                height: 1.1,
                letterSpacing: -0.27,
              ),
            ),
            const SizedBox(height: 9),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 290),
                child: Text(
                  body,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.ink2,
                    height: 1.6,
                  ),
                ),
              ),
            ),
            ?child,
            const Spacer(),
            if (primary != null)
              AiwaButton(
                label: primary!,
                size: AiwaButtonSize.lg,
                fullWidth: true,
                onPressed: onPrimary,
              ),
            if (secondary != null) ...[
              const SizedBox(height: 9),
              AiwaButton(
                label: secondary!,
                variant: AiwaButtonVariant.ghost,
                size: AiwaButtonSize.sm,
                fullWidth: true,
                onPressed: onSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// `aiwa-pop`: scale .86 -> 1 with fade. SuccessSheet uses the bounce,
/// EmptyState [AppTheme.easeSoft] (states.jsx:95, :277).
class PopIn extends StatelessWidget {
  final Widget child;
  final Curve curve;
  const PopIn({
    super.key,
    required this.child,
    this.curve = AppTheme.easeBounce,
  });

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: AppTheme.dur3,
    curve: curve,
    builder: (_, t, c) => Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.scale(scale: .86 + .14 * t, child: c),
    ),
    child: child,
  );
}

void _goBack(BuildContext context) =>
    context.canPop() ? context.pop() : context.go(AppRoutes.home);

void _signOutToSplash(BuildContext context) {
  context.read<AuthBloc>().add(AuthLogoutEvent());
  context.go(AppRoutes.splash);
}

/// ACCT-24 — 401 after the refresh token was rejected.
class SessionExpiredPage extends StatelessWidget {
  const SessionExpiredPage({super.key});

  @override
  Widget build(BuildContext context) => SystemScreen(
    icon: LucideIcons.clockAlert,
    tone: SystemTone.warn,
    eyebrow: AppLocalizations.of(context).sysSignedOut,
    title: AppLocalizations.of(context).sysSessionTitle,
    body: AppLocalizations.of(context).sysSessionBody,
    primary: AppLocalizations.of(context).sysSignInAgain,
    onPrimary: () => context.go(AppRoutes.splash),
  );
}

/// ACCT-25 — 423 (suspended / disabled account).
class AccountLockedPage extends StatelessWidget {
  const AccountLockedPage({super.key});

  @override
  Widget build(BuildContext context) => SystemScreen(
    icon: LucideIcons.lock,
    tone: SystemTone.danger,
    eyebrow: AppLocalizations.of(context).sysLocked,
    title: AppLocalizations.of(context).sysLockedTitle,
    body: AppLocalizations.of(context).sysLockedBody,
    primary: AppLocalizations.of(context).sysContactSupport,
    onPrimary: () => context.push(AppRoutes.support),
    secondary: AppLocalizations.of(context).sysBackToSignIn,
    onSecondary: () => _signOutToSplash(context),
  );
}

/// ACCT-26 — 403 / another role's area.
class ForbiddenPage extends StatelessWidget {
  const ForbiddenPage({super.key});

  @override
  Widget build(BuildContext context) => SystemScreen(
    icon: LucideIcons.shieldX,
    tone: SystemTone.danger,
    eyebrow: AppLocalizations.of(context).sysNoAccess,
    title: AppLocalizations.of(context).sysNoAccessTitle,
    body: AppLocalizations.of(context).sysNoAccessBody,
    primary: AppLocalizations.of(context).sysGoBack,
    onPrimary: () => _goBack(context),
  );
}

/// ACCT-27 — unknown route / 404.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) => SystemScreen(
    icon: LucideIcons.searchX,
    eyebrow: AppLocalizations.of(context).sysNotFound,
    title: AppLocalizations.of(context).sysNotFoundTitle,
    body: AppLocalizations.of(context).sysNotFoundBody,
    primary: AppLocalizations.of(context).sysGoBack,
    onPrimary: () => _goBack(context),
  );
}
