import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_icon_button.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../widgets/step_header.dart';

class RoleChoicePage extends StatefulWidget {
  const RoleChoicePage({super.key});

  @override
  State<RoleChoicePage> createState() => _RoleChoicePageState();
}

class _RoleChoicePageState extends State<RoleChoicePage> {
  String? _selectedRole;

  static const _roles = [
    _RoleOption(
      id: 'CUSTOMER',
      icon: Icons.auto_awesome_outlined,
      title: "I'm here to book",
      subtitle: 'Find a barber, hairdresser, nail artist, or spa near you.',
      perks: [
        'Browse verified providers',
        'Cash on visit',
        'Track your booking live',
      ],
    ),
    _RoleOption(
      id: 'PROVIDER',
      icon: Icons.work_outline_rounded,
      title: "I'm offering services",
      subtitle: 'Get bookings from customers in your area.',
      perks: [
        'ID verification required',
        'Manage your services & hours',
        'Cash payouts',
      ],
    ),
  ];

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.splash);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthStepScaffold(
      bottom: AiwaButton(
        label: 'Continue',
        fullWidth: true,
        size: AiwaButtonSize.lg,
        onPressed: _selectedRole != null
            ? () => context.push('${AppRoutes.authChoice}?role=$_selectedRole')
            : null,
      ),
      children: [
        AiwaIconButton(icon: Icons.arrow_back_rounded, onTap: _back),
        const SizedBox(height: 22),
        const EyebrowLabel('Welcome to AIWA'),
        const SizedBox(height: 6),
        Text(
          'How will you\nbe using AIWA?',
          style: AppTextStyles.h1.copyWith(fontSize: 30, height: 1.05),
        ),
        const SizedBox(height: 8),
        Text(
          'You can change this later from your profile.',
          style: AppTextStyles.bodySm.copyWith(color: AppColors.ink2),
        ),
        const SizedBox(height: 22),
        ..._roles.map(
          (role) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RoleCard(
              role: role,
              active: _selectedRole == role.id,
              onTap: () => setState(() => _selectedRole = role.id),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final _RoleOption role;
  final bool active;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sub = active ? AppColors.rose300 : AppColors.ink3;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTheme.dur2,
        curve: AppTheme.easeSoft,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: active ? AppColors.plum700 : AppColors.paper,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? Colors.transparent : AppColors.divider,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white.withOpacity(0.18)
                        : AppColors.plum100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    role.icon,
                    size: 20,
                    color: active ? AppColors.bone : AppColors.plum700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.title,
                        style: AppTextStyles.h3.copyWith(
                          fontSize: 20,
                          height: 1.1,
                          color: active ? AppColors.bone : AppColors.plum900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        role.subtitle,
                        style: AppTextStyles.micro.copyWith(
                          fontSize: 12,
                          color: sub,
                        ),
                      ),
                    ],
                  ),
                ),
                if (active)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: AppColors.bone,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 54),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: role.perks
                    .map(
                      (perk) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_rounded,
                              size: 11,
                              color: active
                                  ? AppColors.rose300
                                  : AppColors.plum700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              perk,
                              style: AppTextStyles.micro.copyWith(
                                fontSize: 12,
                                color: active
                                    ? AppColors.rose300
                                    : AppColors.ink2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleOption {
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> perks;

  const _RoleOption({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.perks,
  });
}
