import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/step_header.dart';

class ProviderVerificationPage extends StatefulWidget {
  final Map<String, dynamic> registrationData;
  const ProviderVerificationPage({super.key, required this.registrationData});

  @override
  State<ProviderVerificationPage> createState() =>
      _ProviderVerificationPageState();
}

class _ProviderVerificationPageState extends State<ProviderVerificationPage> {
  bool _idFrontDone = false;
  bool _idBackDone = false;
  bool _selfieDone = false;

  bool get _ready => _idFrontDone && _idBackDone && _selfieDone;

  void _submit() {
    final data = widget.registrationData;
    final mode = data['mode'] as String? ?? 'phone';
    context.read<AuthBloc>().add(
      AuthRegisterEvent(
        fullName: data['fullName'] as String,
        password: data['password'] as String,
        email: data['email'] as String?,
        phone: mode == 'phone' ? data['identifier'] as String? : null,
        role: 'PROVIDER',
        gender: data['gender'] as String?,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go(AppRoutes.providerPending);
        } else if (state is AuthError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      child: AuthStepScaffold(
        stickyBar: true,
        bottom: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) => AiwaButton(
            label: 'Submit for review',
            fullWidth: true,
            size: AiwaButtonSize.lg,
            loading: state is AuthLoading,
            onPressed: _ready ? _submit : null,
          ),
        ),
        children: [
          StepHeader(
            step: 6,
            total: 6,
            title: 'Verify your identity',
            subtitle:
                'Upload your national ID and a live selfie. AIWA reviews every provider before they can take bookings.',
            onBack: () => context.pop(),
          ),
          const SizedBox(height: 22),
          _UploadSlot(
            label: 'National ID — front',
            hint:
                'Front side of your government-issued ID. Make sure all four corners are visible.',
            icon: Icons.credit_card_outlined,
            done: _idFrontDone,
            onTap: () => setState(() => _idFrontDone = !_idFrontDone),
          ),
          const SizedBox(height: 10),
          _UploadSlot(
            label: 'National ID — back',
            hint: 'The back side of the same ID.',
            icon: Icons.credit_card_outlined,
            done: _idBackDone,
            onTap: () => setState(() => _idBackDone = !_idBackDone),
          ),
          const SizedBox(height: 10),
          _UploadSlot(
            label: 'Live selfie',
            hint:
                'A clear photo of your face, taken now. We compare it to your ID.',
            icon: Icons.photo_camera_outlined,
            done: _selfieDone,
            onTap: () => setState(() => _selfieDone = !_selfieDone),
          ),
          const SizedBox(height: 16),
          const InlineBanner(
            tone: BannerTone.plum,
            icon: Icons.verified_user_outlined,
            body:
                "Your documents are private. Only AIWA admins reviewing your account see them. They're never shown to customers.",
          ),
        ],
      ),
    );
  }
}

class _UploadSlot extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final bool done;
  final VoidCallback onTap;

  const _UploadSlot({
    required this.label,
    required this.hint,
    required this.icon,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (done) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.plum700, width: 1.5),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.plum500, AppColors.plum900],
            ),
          ),
          padding: const EdgeInsets.all(12),
          alignment: Alignment.bottomLeft,
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 14, color: AppColors.bone),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '$label uploaded · tap to replace',
                  style: AppTextStyles.labelSm.copyWith(color: AppColors.bone),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTheme.dur2,
        constraints: const BoxConstraints(minHeight: 110),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.plum100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: AppColors.plum700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.label.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hint,
                    style: AppTextStyles.micro.copyWith(
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.upload_rounded, size: 18, color: AppColors.plum700),
          ],
        ),
      ),
    );
  }
}
