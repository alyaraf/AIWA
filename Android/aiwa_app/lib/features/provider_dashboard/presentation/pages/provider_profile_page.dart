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
import '../../../../shared/widgets/aiwa_toggle.dart';
import '../../../../shared/widgets/confirm_sheet.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/provider_manage_repository.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Profile tab — `ProviderProfile` (provider-screens.jsx:482-557).
class ProviderProfilePage extends StatefulWidget {
  const ProviderProfilePage({super.key});

  @override
  State<ProviderProfilePage> createState() => _ProviderProfilePageState();
}

class _ProviderProfilePageState extends State<ProviderProfilePage> {
  final _repo = sl<ProviderManageRepository>();
  Json? _d;
  bool _vacation = false;
  String? _vacationError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await _repo.detail(providerIdOf(context));
    if (!mounted) return;
    r.fold((_) {}, (d) {
      setState(() {
        _d = d;
        _vacation = d['vacationMode'] == true;
      });
    });
  }

  /// Optimistic; reverts with an inline error on failure.
  Future<void> _setVacation(bool on) async {
    setState(() {
      _vacation = on;
      _vacationError = null;
    });
    final r = await _repo.setVacation(on);
    if (!mounted) return;
    r.fold(
      (f) => setState(() {
        _vacation = !on;
        _vacationError = AppLocalizations.of(context).error(f.message);
      }),
      (_) {},
    );
  }

  Future<void> _push(String route) async {
    await context.push(route);
    if (mounted) _load();
  }

  Future<void> _signOut() async {
    final ok = await showConfirmSheet(
      context,
      eyebrow: AppLocalizations.of(context).ppAccount,
      title: AppLocalizations.of(context).ppSignOutTitle,
      body: AppLocalizations.of(context).ppSignOutBody,
      confirmLabel: AppLocalizations.of(context).commonSignOut,
      icon: LucideIcons.logOutDir,
      danger: false,
    );
    if (!ok || !mounted) return;
    context.read<AuthBloc>().add(AuthLogoutEvent());
    showAiwaToast(context, AppLocalizations.of(context).commonSignedOut);
    context.go(AppRoutes.splash);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final user = auth is AuthAuthenticated ? auth.user : null;
    final d = _d;
    final l = AppLocalizations.of(context);
    final approved = user?.providerProfile?.isApproved ?? false;
    final name =
        d?['businessName'] as String? ??
        user?.providerProfile?.businessName ??
        user?.fullName ??
        '';
    final sub = [
      d?['address'],
      if (d?['primaryCategory'] != null) l.category('${d!['primaryCategory']}'),
    ].where((s) => s != null && '$s'.isNotEmpty).join(' · ');
    final photos = (d?['galleryImages'] as List?)?.length;
    final rating = (d?['averageRating'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      backgroundColor: AppColors.bone,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          Container(
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(gradient: AppTheme.heroGradient),
            child: Stack(
              children: [
                PositionedDirectional(
                  end: -60,
                  top: -80,
                  child: AiwaGlow(
                    size: 300,
                    color: AppColors.rose300,
                    opacity: .4,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppTheme.gutter,
                    MediaQuery.paddingOf(context).top + 22,
                    AppTheme.gutter,
                    24,
                  ),
                  child: Row(
                    children: [
                      AiwaAvatar(
                        name: name.isEmpty ? '?' : name,
                        size: 64,
                        palette: AvatarPalette.rose,
                        verified: approved,
                        imageUrl: user?.profileImageUrl,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: AppTextStyles.h2.copyWith(
                                fontSize: 24,
                                height: 1.1,
                                color: AppColors.bone,
                              ),
                            ),
                            if (sub.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                sub,
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
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gutter,
              14,
              AppTheme.gutter,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Card(
                  bg: AppColors.paper,
                  border: AppColors.divider,
                  iconBg: _vacation ? AppColors.warn100 : AppColors.plum100,
                  iconFg: _vacation ? AppColors.warn700 : AppColors.plum700,
                  icon: LucideIcons.palmtree,
                  title: l.ppVacation,
                  titleColor: AppColors.ink,
                  body: _vacation ? l.ppVacationOn : l.ppVacationOff,
                  bodyStyle: AppTextStyles.micro.copyWith(
                    fontSize: AppTextStyles.fsMicroPlus,
                  ),
                  trailing: AiwaToggle(
                    value: _vacation,
                    warn: true,
                    onChanged: d == null ? (_) {} : _setVacation,
                  ),
                ),
                if (_vacationError != null) ...[
                  const SizedBox(height: 8),
                  InlineBanner(tone: BannerTone.danger, body: _vacationError),
                ],
                if (approved) ...[
                  const SizedBox(height: 14),
                  _Card(
                    bg: AppColors.success100,
                    border: AppColors.success500.withValues(alpha: .2),
                    iconBg: AppColors.success500,
                    iconFg: AppColors.paper,
                    icon: LucideIcons.badgeCheck,
                    title: l.ppVerified,
                    titleColor: AppColors.success700,
                    // BACKEND GAP: no approval date (verifiedAt) in any
                    // provider payload, so the date is dropped.
                    body: l.ppApproved,
                    bodyStyle: AppTextStyles.micro.copyWith(
                      fontSize: 12,
                      color: AppColors.success700.withValues(alpha: .85),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SettingsRow(
                  icon: LucideIcons.briefcase,
                  label: l.ppBusinessInfo,
                  onTap: () => _push(AppRoutes.providerBusinessInfo),
                ),
                SettingsRow(
                  icon: LucideIcons.images,
                  label: l.galEyebrow,
                  value: photos == null ? null : l.ppPhotos(photos),
                  onTap: () => _push(AppRoutes.providerGallery),
                ),
                SettingsRow(
                  icon: LucideIcons.users,
                  label: l.staffTitle,
                  onTap: () => _push(AppRoutes.providerStaff),
                ),
                SettingsRow(
                  icon: LucideIcons.banknote,
                  label: l.ppWallet,
                  onTap: () => _push(AppRoutes.providerWallet),
                ),
                SettingsRow(
                  icon: LucideIcons.bell,
                  label: l.ppNotifications,
                  onTap: () => context.push(AppRoutes.notifications),
                ),
                SettingsRow(
                  icon: LucideIcons.star,
                  label: l.revTitle,
                  value: d == null
                      ? null
                      : '${rating > 0 ? rating.toStringAsFixed(1) : '—'} · ${d['totalReviews'] ?? 0}',
                  onTap: () => _push(AppRoutes.providerReviews),
                ),
                SettingsRow(
                  icon: LucideIcons.shieldCheck,
                  label: l.ppSafety,
                  onTap: () => context.push(AppRoutes.safetyPolicies),
                ),
                SettingsRow(
                  icon: LucideIcons.messageCircle,
                  label: l.ppWhatsApp,
                  onTap: () => context.push(AppRoutes.support),
                ),
                SettingsRow(
                  icon: LucideIcons.logOutDir,
                  label: l.commonSignOut,
                  danger: true,
                  showDivider: false,
                  onTap: _signOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon circle + title + sub card used by the vacation and verified rows.
class _Card extends StatelessWidget {
  final Color bg, border, iconBg, iconFg, titleColor;
  final IconData icon;
  final String title, body;
  final TextStyle bodyStyle;
  final Widget? trailing;

  const _Card({
    required this.bg,
    required this.border,
    required this.iconBg,
    required this.iconFg,
    required this.icon,
    required this.title,
    required this.titleColor,
    required this.body,
    required this.bodyStyle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radius14),
        border: Border.all(color: border),
      ),
      child: Row(
        spacing: 12,
        children: [
          AnimatedContainer(
            duration: AppTheme.dur2,
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: iconFg),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 1),
                Text(body, style: bodyStyle),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
