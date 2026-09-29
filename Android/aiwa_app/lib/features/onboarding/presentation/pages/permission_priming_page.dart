import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/system_screen.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';

// Contacts was dropped (FE-27): trusted contacts are typed in, so asking for
// READ_CONTACTS would be an unused sensitive permission at store review.
enum PermissionKind { location, notifications, camera }

/// `PERMISSIONS` in system-screens.jsx.
_Copy _copy(AppLocalizations l, PermissionKind kind) => switch (kind) {
  PermissionKind.location => (
    icon: LucideIcons.mapPin,
    eyebrow: l.permLocEyebrow,
    title: l.permLocTitle,
    body: l.permLocBody,
    points: [l.permLocP1, l.permLocP2, l.permLocP3],
    allow: l.permLocAllow,
    deny: l.permLocDeny,
  ),
  PermissionKind.notifications => (
    icon: LucideIcons.bell,
    eyebrow: l.permNotifEyebrow,
    title: l.permNotifTitle,
    body: l.permNotifBody,
    points: [l.permNotifP1, l.permNotifP2, l.permNotifP3],
    allow: l.permNotifAllow,
    deny: l.permNotNow,
  ),
  PermissionKind.camera => (
    icon: LucideIcons.camera,
    eyebrow: l.permCamEyebrow,
    title: l.permCamTitle,
    body: l.permCamBody,
    points: [l.permCamP1, l.permCamP2, l.permCamP3],
    allow: l.permCamAllow,
    deny: l.permCamDeny,
  ),
};

typedef _Copy = ({
  IconData icon,
  String eyebrow,
  String title,
  String body,
  List<String> points,
  String allow,
  String deny,
});

/// `PermissionPrimingScreen` — explains a permission before the OS prompt.
///
/// With [next] (onboarding) both buttons `go` there, resetting the stack.
/// Without it the page was pushed and pops `true` (Allow) / `false` (Deny).
class PermissionPrimingPage extends StatelessWidget {
  final PermissionKind kind;
  final String? next;

  const PermissionPrimingPage({super.key, required this.kind, this.next});

  /// Shows the OS prompt; true when access was granted.
  static Future<bool> request(PermissionKind kind) async {
    try {
      return switch (kind) {
        PermissionKind.location => const [
          LocationPermission.whileInUse,
          LocationPermission.always,
        ].contains(await Geolocator.requestPermission()),
        PermissionKind.notifications =>
          (await Permission.notification.request()).isGranted,
        PermissionKind.camera => (await Permission.camera.request()).isGranted,
      };
    } catch (_) {
      return false;
    }
  }

  /// Allow → OS prompt → the denied screen when refused. Its fallback for
  /// notifications opens the inbox once this step is done.
  Future<void> _allow(BuildContext context) async {
    final granted = await request(kind);
    if (!context.mounted) return;
    var toInbox = false;
    if (!granted) {
      toInbox =
          await context.push<bool>(PermissionDeniedPage.path(kind)) == true &&
          kind == PermissionKind.notifications;
      if (!context.mounted) return;
    }
    _done(context, granted);
    if (toInbox) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => router.push(AppRoutes.notifications),
      );
    }
  }

  void _done(BuildContext context, bool allowed) {
    if (next != null) {
      final resume = next == AppRoutes.home
          ? AppRoutes.resumeAfterSignUp
          : null;
      AppRoutes.resumeAfterSignUp = null;
      context.go(next!);
      // Sign-up started at the auth gate: land on Home, then continue the
      // booking on top of it so back returns to Home.
      if (resume != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => router.push(resume),
        );
      }
    } else {
      context.pop(allowed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _copy(AppLocalizations.of(context), kind);
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            PopIn(
              child: Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: AppColors.plum700,
                  borderRadius: BorderRadius.circular(AppTheme.radius22),
                ),
                child: Icon(p.icon, size: 29, color: AppColors.bone),
              ),
            ),
            const SizedBox(height: 20),
            EyebrowLabel(p.eyebrow, color: AppColors.rose700),
            const SizedBox(height: 7),
            Text(
              p.title,
              style: AppTextStyles.h1.copyWith(
                fontSize: 29,
                height: 1.07,
                letterSpacing: -0.58,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              p.body,
              style: AppTextStyles.bodySm.copyWith(
                fontSize: 14,
                color: AppColors.ink2,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 22),
            for (final pt in p.points)
              Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.success100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.check,
                        size: 12,
                        color: AppColors.success700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        pt,
                        style: AppTextStyles.bodySm.copyWith(
                          fontSize: AppTextStyles.fsMetaPlus,
                          color: AppColors.ink2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const Spacer(),
            AiwaButton(
              label: p.allow,
              size: AiwaButtonSize.lg,
              fullWidth: true,
              onPressed: () => _allow(context),
            ),
            const SizedBox(height: 9),
            AiwaButton(
              label: p.deny,
              variant: AiwaButtonVariant.ghost,
              size: AiwaButtonSize.sm,
              fullWidth: true,
              onPressed: () => _done(context, false),
            ),
          ],
        ),
      ),
    );
  }
}

/// `PermissionDeniedScreen` in system-screens.jsx. Pops `true` when the
/// fallback is picked, `false` after sending the user to Settings.
class PermissionDeniedPage extends StatelessWidget {
  final PermissionKind kind;
  const PermissionDeniedPage({super.key, required this.kind});

  static String path(PermissionKind kind) => Uri(
    path: AppRoutes.permissionDenied,
    queryParameters: {'kind': kind.name},
  ).toString();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (title, body, fallback) = switch (kind) {
      PermissionKind.camera => (
        l.permDeniedCamTitle,
        l.permDeniedCamBody,
        l.permDeniedCamFallback,
      ),
      PermissionKind.notifications => (
        l.permDeniedNotifTitle,
        l.permDeniedNotifBody,
        l.permDeniedNotifFallback,
      ),
      _ => (l.permDeniedLocTitle, l.permDeniedLocBody, l.permDeniedLocFallback),
    };
    return SystemScreen(
      icon: LucideIcons.ban,
      tone: SystemTone.warn,
      eyebrow: l.permNeeded,
      title: title,
      body: body,
      primary: l.permOpenSettings,
      onPrimary: () {
        openAppSettings();
        context.pop(false);
      },
      secondary: fallback,
      onSecondary: () => context.pop(true),
    );
  }
}
