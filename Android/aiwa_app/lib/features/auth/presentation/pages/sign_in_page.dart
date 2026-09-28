import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_icon_button.dart';
import '../../../../shared/widgets/aiwa_text_field.dart';
import '../../../../shared/widgets/aiwa_toast.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/step_header.dart';
import 'package:aiwa_app/l10n/l10n.dart';

class SignInPage extends StatefulWidget {
  final String role;

  /// Opened from the auth gate: pop `true` back to it instead of landing.
  final bool resume;
  const SignInPage({super.key, required this.role, this.resume = false});

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
      AuthLoginEvent(
        identifier: _identifier,
        password: _passwordCtrl.text,
        remember: _remember,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (_, _) => ModalRoute.of(context)?.isCurrent ?? false,
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          showAiwaToast(
            context,
            AppLocalizations.of(
              context,
            ).authWelcomeBackName(state.user.fullName.trim().split(' ').first),
          );
          if (widget.resume && !state.user.isProvider) {
            context.pop(true);
          } else {
            context.go(AppRoutes.landingFor(state.user));
          }
        } else if (state is AuthError) {
          setState(
            () => _error = AppLocalizations.of(context).error(state.message),
          );
        }
      },
      child: AuthStepScaffold(
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) => AiwaButton(
                label: AppLocalizations.of(context).authSignIn,
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
                Text(
                  AppLocalizations.of(context).authNewToAiwa,
                  style: AppTextStyles.meta,
                ),
                GestureDetector(
                  onTap: () => context.pushReplacement(
                    AppRoutes.phoneEntry,
                    extra: {'role': widget.role},
                  ),
                  child: Text(
                    AppLocalizations.of(context).authChoiceCustomerSignUp,
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
            widget.role == 'PROVIDER'
                ? AppLocalizations.of(context).authProviderSignIn
                : AppLocalizations.of(context).authWelcomeBack,
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context).authSignInTitle,
            style: AppTextStyles.h1.copyWith(fontSize: 30, height: 1.05),
          ),
          const SizedBox(height: 8),
          Text(
            _mode == 'phone'
                ? AppLocalizations.of(context).authSignInSubtitlePhone
                : AppLocalizations.of(context).authSignInSubtitleEmail,
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
            EyebrowLabel(AppLocalizations.of(context).authPhoneNumber),
            const SizedBox(height: 6),
            EgyptPhoneField(
              controller: _phoneCtrl,
              onChanged: (_) => setState(_clearErrorSilently),
            ),
          ] else
            AiwaTextField(
              label: AppLocalizations.of(context).authModeEmail,
              placeholder: 'you@example.com',
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              icon: Icons.mail_outline_rounded,
              autoFocus: true,
              onChanged: (_) => setState(_clearErrorSilently),
            ),
          const SizedBox(height: 14),
          AiwaTextField(
            label: AppLocalizations.of(context).authPassword,
            placeholder: '••••••••',
            controller: _passwordCtrl,
            obscureText: !_showPassword,
            icon: Icons.lock_outline_rounded,
            suffixIcon: IconButton(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              icon: Icon(
                _showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 16,
                color: AppColors.ink3,
              ),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
            onChanged: (_) => setState(_clearErrorSilently),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            InlineBanner(
              tone: BannerTone.danger,
              icon: Icons.error_outline_rounded,
              body: _error,
              compact: true,
            ),
          ],
          SizedBox(height: _error == null ? 16 : 10),
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _remember = !_remember),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: AppTheme.dur1,
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
                      AppLocalizations.of(context).authRememberMe,
                      style: AppTextStyles.meta.copyWith(color: AppColors.ink2),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push(AppRoutes.forgotPassword),
                child: Text(
                  AppLocalizations.of(context).authForgotPassword,
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
