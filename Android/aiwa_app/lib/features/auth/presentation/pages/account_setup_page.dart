import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_text_field.dart';
import '../widgets/step_header.dart';

class AccountSetupPage extends StatefulWidget {
  final String role;
  final String identifier;
  final String identifierMode;

  const AccountSetupPage({
    super.key,
    required this.role,
    required this.identifier,
    required this.identifierMode,
  });

  @override
  State<AccountSetupPage> createState() => _AccountSetupPageState();
}

class _AccountSetupPageState extends State<AccountSetupPage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _showPassword = false;

  bool get _isProvider => widget.role == 'PROVIDER';
  int get _totalSteps => _isProvider ? 6 : 4;
  bool get _showEmailField => widget.identifierMode == 'phone';

  String? get _nameError {
    final name = _nameCtrl.text.trim();
    if (name.isNotEmpty && name.split(RegExp(r'\s+')).length < 2) {
      return 'Enter your first and last name';
    }
    return null;
  }

  String? get _emailError {
    final email = _emailCtrl.text;
    if (email.isNotEmpty && !RegExp(r'.+@.+\..+').hasMatch(email)) {
      return "Doesn't look like a valid email";
    }
    return null;
  }

  String? get _passwordError {
    if (_passwordCtrl.text.isNotEmpty && _passwordCtrl.text.length < 6) {
      return 'At least 6 characters';
    }
    return null;
  }

  int get _strength {
    final len = _passwordCtrl.text.length;
    if (len >= 12) return 3;
    if (len >= 8) return 2;
    if (len >= 6) return 1;
    return 0;
  }

  static const _strengthLabels = ['Weak', 'Okay', 'Good', 'Strong'];

  Color _strengthColor(int s) {
    switch (s) {
      case 1:
        return AppColors.warn500;
      case 2:
        return AppColors.info500;
      case 3:
        return AppColors.success500;
      default:
        return AppColors.divider;
    }
  }

  bool get _isValid =>
      _nameError == null &&
      _emailError == null &&
      _passwordError == null &&
      _nameCtrl.text.trim().isNotEmpty &&
      _passwordCtrl.text.length >= 6;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strength = _strength;
    final strengthColor = _strengthColor(strength);

    return AuthStepScaffold(
      bottom: AiwaButton(
        label: 'Continue',
        fullWidth: true,
        size: AiwaButtonSize.lg,
        onPressed: _isValid
            ? () => context.push(
                AppRoutes.avatarGender,
                extra: {
                  'role': widget.role,
                  'identifier': widget.identifier,
                  'mode': widget.identifierMode,
                  'fullName': _nameCtrl.text.trim(),
                  'password': _passwordCtrl.text,
                  if (_emailCtrl.text.isNotEmpty)
                    'email': _emailCtrl.text.trim(),
                },
              )
            : null,
      ),
      children: [
        StepHeader(
          step: 3,
          total: _totalSteps,
          title: 'Set up your account',
          subtitle:
              "A name and a password — that's it. We'll add the rest later.",
          onBack: () => context.pop(),
        ),
        const SizedBox(height: 22),
        AiwaTextField(
          label: 'Full name',
          placeholder: 'e.g. Layla Hassan',
          hint: 'Your real name — providers see it on bookings.',
          controller: _nameCtrl,
          icon: Icons.person_outline_rounded,
          error: _nameError,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        if (_showEmailField) ...[
          AiwaTextField(
            label: 'Email',
            placeholder: 'you@example.com',
            hint: 'For receipts and account recovery.',
            optional: true,
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            icon: Icons.mail_outline_rounded,
            error: _emailError,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
        ],
        AiwaTextField(
          label: 'Password',
          placeholder: '••••••••',
          hint: 'At least 6 characters.',
          controller: _passwordCtrl,
          obscureText: !_showPassword,
          icon: Icons.lock_outline_rounded,
          suffixIcon: IconButton(
            icon: Icon(
              _showPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 18,
              color: AppColors.ink3,
            ),
            onPressed: () => setState(() => _showPassword = !_showPassword),
          ),
          error: _passwordError,
          onChanged: (_) => setState(() {}),
        ),
        if (_passwordCtrl.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              ...List.generate(
                4,
                (i) => Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 4,
                    margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                    decoration: BoxDecoration(
                      color: i < strength ? strengthColor : AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                child: Text(
                  _strengthLabels[strength],
                  textAlign: TextAlign.right,
                  style: AppTextStyles.micro.copyWith(
                    fontWeight: FontWeight.w600,
                    color: strengthColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
