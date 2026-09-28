import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_icon_button.dart';
import '../../../../shared/widgets/aiwa_text_field.dart';
import '../../../../shared/widgets/aiwa_toast.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../domain/repositories/auth_repository.dart';
import '../widgets/step_header.dart';
import 'package:aiwa_app/l10n/l10n.dart';

/// Forgot password — identifier -> code -> new password
/// (ForgotPasswordScreen, flow-additions-v3.jsx:135-202).
///
/// The code is only checked by POST /auth/reset-password in step 3: the
/// backend deletes a code once verified, so calling /auth/verify-otp in
/// step 2 would make the reset fail.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  int _step = 1;
  String _mode = 'phone';
  final _value = TextEditingController();
  final _code = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_value, _code, _pw, _pw2]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _identifier => _mode == 'phone'
      ? '+20${_value.text.replaceAll(RegExp(r'\D'), '')}'
      : _value.text.trim();

  bool get _canContinue => switch (_step) {
    1 => _value.text.trim().isNotEmpty,
    // Backend codes are 6 digits (the prototype accepts 4+).
    2 => _code.text.trim().length >= 6,
    _ => _pw.text.length >= 6 && _pw.text == _pw2.text,
  };

  void _back() {
    if (_step == 1) return context.pop();
    setState(() {
      _step--;
      _error = null;
    });
  }

  Future<void> _next() async {
    if (!_canContinue || _busy) return;
    if (_step == 2) return setState(() => _step = 3);
    final repo = sl<AuthRepository>();
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = _step == 1
        ? await repo.sendOtp(phone: _identifier)
        : await repo.resetPassword(
            identifier: _identifier,
            code: _code.text.trim(),
            newPassword: _pw.text,
          );
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      (f) => setState(() {
        _error = AppLocalizations.of(context).error(f.message);
        // A rejected code (wrong / expired) is fixed on step 2.
        if (_step == 3 && f is! NetworkFailure) _step = 2;
      }),
      (_) {
        if (_step == 1) return setState(() => _step = 2);
        showAiwaToast(
          context,
          AppLocalizations.of(context).authPasswordResetDone,
        );
        context.pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (eyebrow, title, cta) = switch (_step) {
      1 => (l.authResetPassword, l.authWhereSendCode, l.authSendResetCode),
      2 => (
        l.authEnterCode,
        _mode == 'phone' ? l.authCheckMessages : l.authCheckInbox,
        l.authVerify,
      ),
      _ => (l.authAlmostDone, l.authSetNewPassword, l.authResetPassword),
    };
    void changed(String _) => setState(() => _error = null);

    return AuthStepScaffold(
      bottom: AiwaButton(
        label: cta,
        fullWidth: true,
        size: AiwaButtonSize.lg,
        loading: _busy,
        onPressed: _canContinue ? _next : null,
      ),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AiwaIconButton(icon: Icons.arrow_back_rounded, onTap: _back),
        ),
        const SizedBox(height: 22),
        EyebrowLabel(eyebrow),
        const SizedBox(height: 6),
        Text(
          title,
          style: AppTextStyles.h1.copyWith(fontSize: 28, height: 1.08),
        ),
        const SizedBox(height: 18),
        if (_step == 1) ...[
          if (kEmailOtpEnabled) ...[
            IdentifierModeToggle(
              mode: _mode,
              shadow: false,
              onChanged: (m) => setState(() {
                _mode = m;
                _value.clear();
                _error = null;
              }),
            ),
            const SizedBox(height: 14),
          ],
          AiwaTextField(
            key: ValueKey(_mode),
            controller: _value,
            placeholder: _mode == 'phone' ? '100 555 8821' : 'you@example.com',
            icon: _mode == 'phone'
                ? Icons.phone_outlined
                : Icons.mail_outline_rounded,
            keyboardType: _mode == 'phone'
                ? TextInputType.phone
                : TextInputType.emailAddress,
            autoFocus: true,
            onChanged: changed,
          ),
        ] else if (_step == 2)
          AiwaTextField(
            controller: _code,
            placeholder: l.authCodePlaceholder,
            icon: Icons.key_outlined,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autoFocus: true,
            onChanged: changed,
          )
        else ...[
          AiwaTextField(
            controller: _pw,
            placeholder: l.authNewPassword,
            icon: Icons.lock_outline_rounded,
            obscureText: true,
            autoFocus: true,
            onChanged: changed,
          ),
          const SizedBox(height: 10),
          AiwaTextField(
            controller: _pw2,
            placeholder: l.authConfirmPassword,
            icon: Icons.lock_outline_rounded,
            obscureText: true,
            onChanged: changed,
            onSubmitted: (_) => _next(),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          InlineBanner(
            tone: BannerTone.danger,
            icon: Icons.error_outline_rounded,
            body: _error,
          ),
        ],
      ],
    );
  }
}
