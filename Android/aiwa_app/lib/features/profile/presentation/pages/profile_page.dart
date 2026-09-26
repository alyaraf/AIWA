import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../shared/widgets/aiwa_avatar.dart';
import '../../../../shared/widgets/confirm_sheet.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/guest_locked_view.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state is AuthAuthenticated ? state.user : null;
        if (user == null) {
          return Scaffold(
            backgroundColor: AppColors.bone,
            body: const Padding(
              padding: EdgeInsets.only(bottom: 90),
              child: GuestLockedView(
                title: 'Make AIWA yours',
                body:
                    'Sign in to manage your details, notifications and bookings.',
                icon: Icons.person_outline_rounded,
              ),
            ),
          );
        }
        return Scaffold(
          backgroundColor: AppColors.bone,
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              _Header(user: user),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.gutter,
                  20,
                  AppTheme.gutter,
                  110,
                ),
                child: Column(
                  children: [
                    SettingsRow(
                      icon: Icons.notifications_none_rounded,
                      label: 'Notifications',
                      onTap: () => context.push(AppRoutes.notifications),
                    ),
                    SettingsRow(
                      icon: Icons.palette_outlined,
                      label: 'App palette',
                      value:
                          ThemeController.mode.value == ThemeController.female
                          ? 'Mauve'
                          : 'Charcoal',
                      onTap: () => _pickPalette(context),
                    ),
                    SettingsRow(
                      icon: Icons.language_rounded,
                      label: 'Language',
                      value: user.preferredLanguage.toLowerCase() == 'ar'
                          ? 'العربية'
                          : 'English',
                    ),
                    if (user.email != null && user.email!.isNotEmpty)
                      SettingsRow(
                        icon: Icons.mail_outline_rounded,
                        label: 'Email',
                        value: user.email,
                      ),
                    SettingsRow(
                      icon: Icons.logout_rounded,
                      label: 'Sign out',
                      danger: true,
                      showDivider: false,
                      onTap: () => _signOut(context),
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

  Future<void> _signOut(BuildContext context) async {
    final ok = await showConfirmSheet(
      context,
      eyebrow: 'Sign out',
      title: 'Sign out of AIWA?',
      body: "You'll need your phone or email and password to sign back in.",
      confirmLabel: 'Sign out',
      icon: Icons.logout_rounded,
    );
    if (!ok || !context.mounted) return;
    context.read<AuthBloc>().add(AuthLogoutEvent());
    context.go(AppRoutes.splash);
  }

  void _pickPalette(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.plum900.withOpacity(0.45),
      builder: (ctx) => Container(
        decoration: AppTheme.sheetDecoration,
        padding: EdgeInsets.fromLTRB(
          AppTheme.gutter,
          18,
          AppTheme.gutter,
          24 + MediaQuery.paddingOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const EyebrowLabel('Make it yours'),
            const SizedBox(height: 4),
            Text('App palette', style: AppTextStyles.h3),
            const SizedBox(height: 16),
            _PaletteOption(
              name: 'Charcoal & stone',
              palette: AiwaPalettes.male,
              selected: ThemeController.mode.value == ThemeController.male,
              onTap: () {
                Navigator.pop(ctx);
                ThemeController.set(ThemeController.male);
              },
            ),
            const SizedBox(height: 10),
            _PaletteOption(
              name: 'Mauve & dusty rose',
              palette: AiwaPalettes.female,
              selected: ThemeController.mode.value == ThemeController.female,
              onTap: () {
                Navigator.pop(ctx);
                ThemeController.set(ThemeController.female);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final UserEntity user;
  const _Header({required this.user});

  @override
  Widget build(BuildContext context) {
    final contact = user.phone ?? user.email ?? '';
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(gradient: AppTheme.heroGradient),
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -30,
            child: AiwaGlow(size: 260, color: AppColors.rose300, opacity: 0.4),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppTheme.gutter,
              MediaQuery.paddingOf(context).top + 26,
              AppTheme.gutter,
              22,
            ),
            child: Row(
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
                          color: AppColors.bone,
                          height: 1.1,
                        ),
                      ),
                      if (contact.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          contact,
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
    );
  }
}

class _PaletteOption extends StatelessWidget {
  final String name;
  final AiwaPalette palette;
  final bool selected;
  final VoidCallback onTap;

  const _PaletteOption({
    required this.name,
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.plum100 : AppColors.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.plum700 : AppColors.divider,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            for (final c in [palette.plum700, palette.rose500, palette.bone])
              Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.divider),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: AppTextStyles.label.copyWith(fontSize: 14),
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: 18, color: AppColors.plum700),
          ],
        ),
      ),
    );
  }
}
