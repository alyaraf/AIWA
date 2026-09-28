import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_text_field.dart';
import '../widgets/step_header.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
      return AppLocalizations.of(context).authNameError;
    }
    return null;
  }

  String? get _emailError {
    final email = _emailCtrl.text;
    if (email.isNotEmpty && !RegExp(r'.+@.+\..+').hasMatch(email)) {
      return AppLocalizations.of(context).authEmailError;
    }
    return null;
  }

  String? get _passwordError {
    if (_passwordCtrl.text.isNotEmpty && _passwordCtrl.text.length < 6) {
      return AppLocalizations.of(context).authPasswordMinError;
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
    final l = AppLocalizations.of(context);
    final strength = _strength;
    final strengthLabels = [
      l.authStrengthWeak,
      l.authStrengthOkay,
      l.authStrengthGood,
      l.authStrengthStrong,
    ];
    final strengthColor = _strengthColor(strength);

    return AuthStepScaffold(
      bottom: AiwaButton(
        label: l.commonContinue,
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
          title: l.authSetupTitle,
          subtitle: l.authSetupSubtitle,
          onBack: () => context.pop(),
        ),
        const SizedBox(height: 22),
        AiwaTextField(
          label: l.authFullName,
          placeholder: l.authNamePlaceholder,
          hint: l.authNameHint,
          controller: _nameCtrl,
          icon: LucideIcons.user,
          error: _nameError,
          inlineError: true,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        if (_showEmailField) ...[
          AiwaTextField(
            label: l.authModeEmail,
            placeholder: 'you@example.com',
            hint: l.authEmailHint,
            optional: true,
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            icon: LucideIcons.mail,
            error: _emailError,
            inlineError: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
        ],
        AiwaTextField(
          label: l.authPassword,
          placeholder: '••••••••',
          hint: l.authPasswordHint,
          controller: _passwordCtrl,
          obscureText: !_showPassword,
          icon: LucideIcons.lock,
          suffixIcon: IconButton(
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            icon: Icon(
              _showPassword ? LucideIcons.eyeOff : LucideIcons.eye,
              size: 16,
              color: AppColors.ink3,
            ),
            onPressed: () => setState(() => _showPassword = !_showPassword),
          ),
          error: _passwordError,
          inlineError: true,
          belowInput: _passwordCtrl.text.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      ...List.generate(
                        4,
                        (i) => Expanded(
                          child: AnimatedContainer(
                            duration: AppTheme.dur2,
                            height: 4,
                            margin: EdgeInsetsDirectional.only(
                              end: i < 3 ? 4 : 0,
                            ),
                            decoration: BoxDecoration(
                              color: i < strength
                                  ? strengthColor
                                  : AppColors.divider,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 48,
                        child: Text(
                          strengthLabels[strength],
                          textAlign: TextAlign.end,
                          style: AppTextStyles.micro.copyWith(
                            fontWeight: FontWeight.w600,
                            color: strengthColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}
