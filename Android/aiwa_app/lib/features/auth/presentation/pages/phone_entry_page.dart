import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_text_field.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/step_header.dart';

class PhoneEntryPage extends StatefulWidget {
  final String role;
  const PhoneEntryPage({super.key, required this.role});

  @override
  State<PhoneEntryPage> createState() => _PhoneEntryPageState();
}

class _PhoneEntryPageState extends State<PhoneEntryPage> {
  String _mode = 'phone';
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool get _isProvider => widget.role == 'PROVIDER';
  int get _totalSteps => _isProvider ? 6 : 4;

  bool get _isValid {
    if (_mode == 'phone') {
      return _phoneCtrl.text.replaceAll(RegExp(r'\D'), '').length >= 9;
    }
    return RegExp(r'.+@.+\..+').hasMatch(_emailCtrl.text);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_isValid) return;
    final value = _mode == 'phone'
        ? '+20${_phoneCtrl.text.replaceAll(RegExp(r'\D'), '')}'
        : _emailCtrl.text.trim();

    if (_mode == 'phone') {
      context.read<AuthBloc>().add(AuthSendOtpEvent(phone: value));
    } else {
      // Email flow — no OTP endpoint for email, go straight to account setup.
      context.push(
        AppRoutes.accountSetup,
        extra: {'role': widget.role, 'identifier': value, 'mode': _mode},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthOtpSent) {
          context.push(
            AppRoutes.otp,
            extra: {
              'identifier': state.phone,
              'role': widget.role,
              'mode': _mode,
            },
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
            label: 'Send code',
            fullWidth: true,
            size: AiwaButtonSize.lg,
            loading: state is AuthLoading,
            onPressed: _isValid ? _continue : null,
          ),
        ),
        children: [
          StepHeader(
            step: 1,
            total: _totalSteps,
            title:
                "What's your ${_mode == 'phone' ? 'phone number' : 'email'}?",
            subtitle: "We'll send a 6-digit code to confirm.",
            onBack: () => context.pop(),
          ),
          const SizedBox(height: 22),
          IdentifierModeToggle(
            mode: _mode,
            onChanged: (m) => setState(() => _mode = m),
          ),
          const SizedBox(height: 18),
          if (_mode == 'phone')
            EgyptPhoneField(
              controller: _phoneCtrl,
              autoFocus: true,
              onChanged: (_) => setState(() {}),
            )
          else
            AiwaTextField(
              placeholder: 'you@example.com',
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              icon: Icons.mail_outline_rounded,
              autoFocus: true,
              onChanged: (_) => setState(() {}),
            ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: AppTextStyles.micro.copyWith(fontSize: 11.5, height: 1.45),
              children: [
                const TextSpan(text: "By continuing you agree to AIWA's "),
                TextSpan(
                  text: 'terms',
                  style: TextStyle(
                    color: AppColors.plum700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: 'safety policy',
                  style: TextStyle(
                    color: AppColors.plum700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
