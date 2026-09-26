import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_icon_button.dart';
import '../../../../shared/widgets/aiwa_text_field.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/step_header.dart';

class SignInPage extends StatefulWidget {
  final String role;
  const SignInPage({super.key, required this.role});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  String _mode = 'phone';
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _showPassword = false;
  bool _remember = true;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool get _isValid {
    final idValid = _mode == 'phone'
        ? _phoneCtrl.text.replaceAll(RegExp(r'\D'), '').length >= 9
        : RegExp(r'.+@.+\..+').hasMatch(_emailCtrl.text);
    return idValid && _passwordCtrl.text.length >= 6;
  }

  String get _identifier => _mode == 'phone'
      ? '+20${_phoneCtrl.text.replaceAll(RegExp(r'\D'), '')}'
      : _emailCtrl.text.trim();

  void _submit() {
    if (!_isValid) return;
    setState(() => _error = null);
    context.read<AuthBloc>().add(
      AuthLoginEvent(identifier: _identifier, password: _passwordCtrl.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go(
            state.user.isProvider
                ? AppRoutes.providerDashboard
                : AppRoutes.home,
          );
        } else if (state is AuthError) {
          setState(() => _error = state.message);
        }
      },
      child: AuthStepScaffold(
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) => AiwaButton(
                label: 'Sign in',
                fullWidth: true,
                size: AiwaButtonSize.lg,
                loading: state is AuthLoading,
                onPressed: _isValid ? _submit : null,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('New to AIWA? ', style: AppTextStyles.meta),
                GestureDetector(
                  onTap: () => context.push(
                    AppRoutes.phoneEntry,
                    extra: {'role': widget.role},
                  ),
                  child: Text(
                    'Create an account',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.plum700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          AiwaIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => context.canPop()
                ? context.pop()
                : context.go(AppRoutes.roleChoice),
          ),
          const SizedBox(height: 22),
          EyebrowLabel(
            widget.role == 'PROVIDER' ? 'Provider sign in' : 'Welcome back',
          ),
          const SizedBox(height: 6),
          Text(
            'Sign in to AIWA',
            style: AppTextStyles.h1.copyWith(fontSize: 30, height: 1.05),
          ),
          const SizedBox(height: 8),
          Text(
            'Use the ${_mode == 'phone' ? 'number' : 'email'} and password you signed up with.',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.ink2),
          ),
          const SizedBox(height: 22),
          IdentifierModeToggle(
            mode: _mode,
            onChanged: (m) => setState(() {
              _mode = m;
              _error = null;
            }),
          ),
          const SizedBox(height: 18),
          if (_mode == 'phone') ...[
            const EyebrowLabel('Phone number'),
            const SizedBox(height: 6),
            EgyptPhoneField(
              controller: _phoneCtrl,
              onChanged: (_) => setState(_clearErrorSilently),
            ),
          ] else
            AiwaTextField(
              label: 'Email',
              placeholder: 'you@example.com',
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              icon: Icons.mail_outline_rounded,
              autoFocus: true,
              onChanged: (_) => setState(_clearErrorSilently),
            ),
          const SizedBox(height: 14),
          AiwaTextField(
            label: 'Password',
            placeholder: '••••••••',
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
            onChanged: (_) => setState(_clearErrorSilently),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            InlineBanner(
              tone: BannerTone.danger,
              icon: Icons.error_outline_rounded,
              body: _error,
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _remember = !_remember),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: _remember
                            ? AppColors.plum700
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: _remember ? AppColors.plum700 : AppColors.ink4,
                          width: 2,
                        ),
                      ),
                      child: _remember
                          ? Icon(
                              Icons.check_rounded,
                              size: 12,
                              color: AppColors.paper,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Remember me',
                      style: AppTextStyles.meta.copyWith(color: AppColors.ink2),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Password reset is coming soon — contact support for now.',
                    ),
                  ),
                ),
                child: Text(
                  'Forgot password?',
                  style: AppTextStyles.label.copyWith(color: AppColors.plum700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _clearErrorSilently() {
    _error = null;
  }
}
