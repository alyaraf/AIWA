import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/step_header.dart';

/// "Make it yours" — the gender choice sets the app palette, previewed live.
class AvatarGenderPage extends StatefulWidget {
  final String role;
  final Map<String, dynamic> registrationData;

  const AvatarGenderPage({
    super.key,
    required this.role,
    required this.registrationData,
  });

  @override
  State<AvatarGenderPage> createState() => _AvatarGenderPageState();
}

class _AvatarGenderPageState extends State<AvatarGenderPage> {
  late String _gender = ThemeController.mode.value == ThemeController.female
      ? 'FEMALE'
      : 'MALE';

  bool get _isProvider => widget.role == 'PROVIDER';
  int get _totalSteps => _isProvider ? 6 : 4;

  void _pick(String gender) {
    setState(() => _gender = gender);
    ThemeController.applyGender(gender);
  }

  void _continue() {
    final data = {...widget.registrationData, 'gender': _gender};
    if (_isProvider) {
      context.push(AppRoutes.providerBusiness, extra: data);
    } else {
      final mode = data['mode'] as String? ?? 'phone';
      context.read<AuthBloc>().add(
        AuthRegisterEvent(
          fullName: data['fullName'] as String,
          password: data['password'] as String,
          email: data['email'] as String?,
          phone: mode == 'phone' ? data['identifier'] as String? : null,
          role: widget.role,
          gender: _gender,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.registrationData['fullName'] as String? ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : null;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go(
            state.user.isProvider ? AppRoutes.providerPending : AppRoutes.home,
          );
        } else if (state is AuthError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      child: AuthStepScaffold(
        bottom: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) => AiwaButton(
            label: 'Continue',
            fullWidth: true,
            size: AiwaButtonSize.lg,
            loading: state is AuthLoading,
            onPressed: _continue,
          ),
        ),
        children: [
          StepHeader(
            step: 4,
            total: _totalSteps,
            title: 'Make it yours',
            subtitle: 'Pick your palette. You can change it later.',
            onBack: () => context.pop(),
          ),
          const SizedBox(height: 22),
          Center(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: AppTheme.dur3,
                  curve: AppTheme.easeSoft,
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.plum500, AppColors.plum900],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: AppColors.paper, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.plum700.withOpacity(0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: initial != null
                      ? Text(
                          initial,
                          style: AppTextStyles.display.copyWith(
                            color: AppColors.bone,
                            fontSize: 54,
                            height: 1,
                          ),
                        )
                      : Icon(
                          Icons.person_outline_rounded,
                          size: 40,
                          color: AppColors.bone,
                        ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You can add a photo later from your profile.',
                  style: AppTextStyles.meta.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const EyebrowLabel("I'm signing up as"),
          const SizedBox(height: 10),
          Row(
            children: [
              _GenderOption(
                label: 'Woman',
                swatches: AiwaPalettes.female,
                selected: _gender == 'FEMALE',
                onTap: () => _pick('FEMALE'),
              ),
              const SizedBox(width: 10),
              _GenderOption(
                label: 'Man',
                swatches: AiwaPalettes.male,
                selected: _gender == 'MALE',
                onTap: () => _pick('MALE'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'This sets the palette of your app.',
            style: AppTextStyles.micro.copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _GenderOption extends StatelessWidget {
  final String label;
  final AiwaPalette swatches;
  final bool selected;
  final VoidCallback onTap;

  const _GenderOption({
    required this.label,
    required this.swatches,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [swatches.plum700, swatches.rose500, swatches.bone];
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppTheme.dur2,
          curve: AppTheme.easeSoft,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppColors.plum100 : AppColors.paper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.plum700 : AppColors.divider,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: colors
                    .map(
                      (c) => Container(
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.divider),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: AppTextStyles.h4.copyWith(color: AppColors.plum900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
