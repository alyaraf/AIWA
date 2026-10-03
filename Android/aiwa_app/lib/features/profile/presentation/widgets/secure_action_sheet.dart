import 'package:flutter/material.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_sheet.dart';
import '../../../../shared/widgets/aiwa_text_field.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import 'package:aiwa_app/l10n/l10n.dart';

/// Sheet for the actions the backend now guards (CR-05): asks for the current
/// password and/or a 6-digit code and runs [onSubmit]. A failure (wrong
/// password, wrong code) is shown inside the sheet and the fields stay
/// editable; returns true once [onSubmit] succeeded, false when closed.
Future<bool> showSecureActionSheet(
  BuildContext context, {
  required String title,
  String? body,
  bool askPassword = true,
  bool askCode = false,
  required String confirmLabel,
  bool danger = false,
  required Future<Failure?> Function(String password, String code) onSubmit,
}) async =>
    await showAiwaSheet<bool>(
      context,
      builder: (_) => _SecureActionSheet(
        title: title,
        body: body,
        askPassword: askPassword,
        askCode: askCode,
        confirmLabel: confirmLabel,
        danger: danger,
        onSubmit: onSubmit,
      ),
    ) ??
    false;

class _SecureActionSheet extends StatefulWidget {
  final String title;
  final String? body;
  final bool askPassword;
  final bool askCode;
  final String confirmLabel;
  final bool danger;
  final Future<Failure?> Function(String password, String code) onSubmit;

  const _SecureActionSheet({
    required this.title,
    required this.body,
    required this.askPassword,
    required this.askCode,
    required this.confirmLabel,
    required this.danger,
    required this.onSubmit,
  });

  @override
  State<_SecureActionSheet> createState() => _SecureActionSheetState();
}

class _SecureActionSheetState extends State<_SecureActionSheet> {
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  bool get _ready =>
      !_busy &&
      (!widget.askPassword || _password.text.isNotEmpty) &&
      (!widget.askCode || RegExp(r'^[0-9]{6}$').hasMatch(_code.text.trim()));

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final failure = await widget.onSubmit(_password.text, _code.text.trim());
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = AppLocalizations.of(context).error(failure.message);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: AppTextStyles.h3.copyWith(fontSize: 22, height: 1.1),
          ),
          if (widget.body != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.body!,
              style: AppTextStyles.micro.copyWith(
                fontSize: AppTextStyles.fsLabelSmPlus,
                color: AppColors.ink3,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_error != null) ...[
            InlineBanner(tone: BannerTone.danger, body: _error),
            const SizedBox(height: 12),
          ],
          if (widget.askPassword) ...[
            AiwaTextField(
              controller: _password,
              placeholder: l.editCurrentPassword,
              obscureText: true,
              autoFocus: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
          ],
          if (widget.askCode) ...[
            AiwaTextField(
              controller: _code,
              placeholder: l.authCodePlaceholder,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autoFocus: !widget.askPassword,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 4),
          AiwaButton(
            label: widget.confirmLabel,
            variant: widget.danger
                ? AiwaButtonVariant.danger
                : AiwaButtonVariant.primary,
            size: AiwaButtonSize.lg,
            fullWidth: true,
            loading: _busy,
            onPressed: _ready ? _submit : null,
          ),
        ],
      ),
    );
  }
}
