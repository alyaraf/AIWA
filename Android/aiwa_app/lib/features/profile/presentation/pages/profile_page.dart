import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_avatar.dart';
import '../../../../shared/widgets/aiwa_toast.dart';
import '../../../../shared/widgets/confirm_sheet.dart';
import '../../../../shared/widgets/guest_locked_view.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/account_repository.dart';
import '../widgets/secure_action_sheet.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _repo = sl<AccountRepository>();
  ({int bookings, int favorites, int reviews})? _stats;
  int? _trusted;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _repo.stats().then((r) {
      if (mounted) r.fold((_) {}, (s) => setState(() => _stats = s));
    });
    _repo.trustedContacts().then((r) {
      if (mounted) r.fold((_) {}, (c) => setState(() => _trusted = c.length));
    });
  }

  Future<void> _push(String route) async {
    await context.push(route);
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (_, s) => s is AuthAuthenticated || s is AuthUnauthenticated,
      builder: (context, state) {
        final user = state is AuthAuthenticated ? state.user : null;
        final l = AppLocalizations.of(context);
        if (user == null) {
          return Scaffold(
            backgroundColor: AppColors.bone,
            body: Padding(
              padding: const EdgeInsets.only(bottom: 90),
              child: GuestLockedView(
                title: l.profGuestTitle,
                body: l.profGuestBody,
                icon: LucideIcons.user,
              ),
            ),
          );
        }
        // prototype.jsx:343-354, in order.
        final rows = [
          (LucideIcons.user, l.profPersonalInfo, null, AppRoutes.editProfile),
          (LucideIcons.mapPin, l.profSavedAddresses, null, AppRoutes.addresses),
          (
            LucideIcons.userPlus,
            l.profTrustedContacts,
            _trusted == null ? null : l.profTrustedSaved(_trusted!),
            AppRoutes.trustedContacts,
          ),
          (LucideIcons.bell, l.ppNotifications, null, AppRoutes.notifications),
          (
            LucideIcons.bellRing,
            l.profNotificationPrefs,
            null,
            AppRoutes.notificationPreferences,
          ),
          // The language switch itself lives in Personal info.
          (
            LucideIcons.globe,
            l.profLanguage,
            user.preferredLanguage.toLowerCase() == 'ar'
                ? 'العربية'
                : 'English',
            AppRoutes.editProfile,
          ),
          (LucideIcons.shieldCheck, l.ppSafety, null, AppRoutes.safetyPolicies),
          (LucideIcons.messageCircle, l.ppWhatsApp, null, AppRoutes.support),
        ];
        return Scaffold(
          backgroundColor: AppColors.bone,
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              _Header(user: user, stats: _stats),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.gutter,
                  20,
                  AppTheme.gutter,
                  100,
                ),
                child: Column(
                  children: [
                    for (final (icon, label, value, route) in rows)
                      SettingsRow(
                        icon: icon,
                        label: label,
                        value: value,
                        onTap: () => _push(route),
                      ),
                    SettingsRow(
                      icon: LucideIcons.logOutDir,
                      label: l.commonSignOut,
                      danger: true,
                      onTap: _signOut,
                    ),
                    SettingsRow(
                      icon: LucideIcons.trash2,
                      label: l.profDeleteAccount,
                      danger: true,
                      showDivider: false,
                      onTap: _deleteAccount,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _signOut() async {
    final ok = await showConfirmSheet(
      context,
      eyebrow: AppLocalizations.of(context).profYourAccount,
      title: AppLocalizations.of(context).ppSignOutTitle,
      body: AppLocalizations.of(context).profSignOutBody,
      confirmLabel: AppLocalizations.of(context).commonSignOut,
      icon: LucideIcons.logOutDir,
      danger: false,
    );
    if (!ok || !mounted) return;
    context.read<AuthBloc>().add(AuthLogoutEvent());
    context.go(AppRoutes.splash);
  }

  Future<void> _deleteAccount() async {
    if (!await showDeleteAccountSheet(context) || !mounted) return;
    final l = AppLocalizations.of(context);
    // The backend wants the current password (CR-05); a wrong one is shown in
    // the sheet, which stays open.
    final deleted = await showSecureActionSheet(
      context,
      title: l.delTitle,
      body: l.editConfirmBody,
      confirmLabel: l.profDeleteAccount,
      danger: true,
      onSubmit: (password, _) async => (await _repo.deleteAccount(
        currentPassword: password,
      )).fold((f) => f, (_) => null),
    );
    if (!deleted || !mounted) return;
    showAiwaToast(context, l.profAccountDeleted);
    context.read<AuthBloc>().add(AuthLogoutEvent());
    context.go(AppRoutes.splash);
  }
}

class _Header extends StatelessWidget {
  final UserEntity user;
  final ({int bookings, int favorites, int reviews})? stats;
  const _Header({required this.user, this.stats});

  @override
  Widget build(BuildContext context) {
    final contact = user.phone ?? user.email ?? '';
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(gradient: AppTheme.heroGradient),
      child: Stack(
        children: [
          // prototype.jsx:358 — circle at 70% 30%, .4, transparent 60%.
          Positioned.fill(
            child: AiwaGlow.fill(
              center: const Alignment(.4, -.4),
              color: AppColors.glowRose,
              opacity: .4,
              stop: .6,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppTheme.gutter,
              MediaQuery.paddingOf(context).top + 22,
              AppTheme.gutter,
              22,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    AiwaAvatar(
                      name: user.fullName,
                      size: 64,
                      palette: AvatarPalette.rose,
                      imageUrl: user.profileImageUrl,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            style: AppTextStyles.h2.copyWith(
                              fontSize: 24,
                              letterSpacing: 0,
                              color: AppColors.bone,
                              height: 1.1,
                            ),
                          ),
                          if (contact.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              contact,
                              // Phone/email: keep '+20…' intact in Arabic.
                              textDirection: TextDirection.ltr,
                              style: AppTextStyles.meta.copyWith(
                                color: AppColors.rose300,
                              ),
                            ),
                          ],
                          // CR-05: an added email is not the sign-in until
                          // its code is confirmed.
                          if (user.pendingEmail != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              AppLocalizations.of(
                                context,
                              ).editEmailPending(user.pendingEmail!),
                              style: AppTextStyles.meta.copyWith(
                                color: AppColors.rose300,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  spacing: 10,
                  children: [
                    for (final (n, label) in [
                      (
                        stats?.bookings,
                        AppLocalizations.of(context).profStatBookings,
                      ),
                      (
                        stats?.favorites,
                        AppLocalizations.of(context).profStatFavorites,
                      ),
                      (
                        stats?.reviews,
                        AppLocalizations.of(context).profStatReviews,
                      ),
                    ])
                      Expanded(
                        child: _Stat(value: n, label: label),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final int? value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bone.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(AppTheme.radius14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value?.toString() ?? '—',
            style: AppTextStyles.h3.copyWith(
              fontSize: 22,
              height: 1,
              letterSpacing: 0,
              color: AppColors.bone,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: AppTextStyles.micro.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: .88,
              color: AppColors.rose300,
            ),
          ),
        ],
      ),
    );
  }
}
