import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/dashed_button.dart';
import '../../../../shared/widgets/aiwa_toast.dart';
import '../../../../shared/widgets/screen_chrome.dart' show InlineBanner, BannerTone;
import '../../../../core/di/injection_container.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/auth_repository.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../widgets/step_header.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ProviderVerificationPage extends StatefulWidget {
  final Map<String, dynamic> registrationData;
  const ProviderVerificationPage({super.key, required this.registrationData});

  @override
  State<ProviderVerificationPage> createState() =>
      _ProviderVerificationPageState();
}

class _ProviderVerificationPageState extends State<ProviderVerificationPage> {
  String? _idFront;
  String? _idBack;
  String? _selfie;

  /// Camera priming is shown once, before the first capture.
  bool _primed = false;

  bool get _ready => _idFront != null && _idBack != null && _selfie != null;

  Future<String?> _pick({bool selfie = false}) async {
    if (!_primed && !await Permission.camera.isGranted) {
      if (!mounted) return null;
      final answered = await context.push<bool>(
        '${AppRoutes.permission}?kind=camera',
      );
      if (answered == null) return null;
      _primed = true;
    }
    try {
      final file = await ImagePicker().pickImage(
        source: await Permission.camera.isGranted
            ? ImageSource.camera
            : ImageSource.gallery,
        preferredCameraDevice: selfie ? CameraDevice.front : CameraDevice.rear,
        imageQuality: 80,
      );
      return file?.path;
    } catch (_) {
      return null;
    }
  }

  /// Sent back here from the pending screen after a rejection or a "more
  /// info" request: upload straight away instead of continuing sign-up.
  bool get _resubmit => widget.registrationData['resubmit'] == true;
  bool _sending = false;
  String? _error;

  /// Registration, the business profile and these uploads all happen at the
  /// end of Preferences, after Terms (prototype.jsx:649-650).
  void _submit() => _resubmit
      ? _sendAgain()
      : context.push(
          AppRoutes.terms,
          extra: {
            ...widget.registrationData,
            'idFront': _idFront,
            'idBack': _idBack,
            'selfie': _selfie,
          },
        );

  /// POST /provider/verification/documents — the backend puts the provider
  /// back in the review queue and clears the admin's note.
  Future<void> _sendAgain() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final r = await sl<AuthRepository>().uploadVerificationDocuments(
      idFront: _idFront!,
      idBack: _idBack!,
      selfie: _selfie!,
    );
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    r.fold(
      (f) => setState(() {
        _sending = false;
        _error = l.error(f.message);
      }),
      (_) {
        context.read<AuthBloc>().add(AuthGetCurrentUserEvent());
        showAiwaToast(context, l.provDocsResent);
        context.go(AppRoutes.providerPending);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AuthStepScaffold(
      stickyBar: true,
      bottom: AiwaButton(
        label: _resubmit ? l.provResubmit : l.provVerifySubmit,
        fullWidth: true,
        size: AiwaButtonSize.lg,
        loading: _sending,
        onPressed: _ready && !_sending ? _submit : null,
      ),
      children: [
        if (_error != null) ...[
          InlineBanner(tone: BannerTone.danger, body: _error),
          const SizedBox(height: 12),
        ],
        StepHeader(
          step: 6,
          total: 6,
          title: l.provVerifyTitle,
          subtitle: l.provVerifySubtitle,
          onBack: () => context.pop(),
        ),
        const SizedBox(height: 22),
        _UploadSlot(
          label: l.provVerifyIdFront,
          hint: l.provVerifyIdFrontHint,
          icon: LucideIcons.creditCard,
          path: _idFront,
          onTap: () async {
            final p = await _pick();
            if (p != null) setState(() => _idFront = p);
          },
        ),
        const SizedBox(height: 10),
        _UploadSlot(
          label: l.provVerifyIdBack,
          hint: l.provVerifyIdBackHint,
          icon: LucideIcons.creditCard,
          path: _idBack,
          onTap: () async {
            final p = await _pick();
            if (p != null) setState(() => _idBack = p);
          },
        ),
        const SizedBox(height: 10),
        _UploadSlot(
          label: l.provVerifySelfie,
          hint: l.provVerifySelfieHint,
          icon: LucideIcons.camera,
          path: _selfie,
          onTap: () async {
            final p = await _pick(selfie: true);
            if (p != null) setState(() => _selfie = p);
          },
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.plum100,
            borderRadius: BorderRadius.circular(AppTheme.radius14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  LucideIcons.shieldCheck,
                  size: 16,
                  color: AppColors.plum700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.provVerifyPrivate,
                  style: AppTextStyles.micro.copyWith(
                    fontSize: 12,
                    color: AppColors.plum700,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UploadSlot extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final String? path;
  final VoidCallback onTap;

  const _UploadSlot({
    required this.label,
    required this.hint,
    required this.icon,
    required this.path,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (path != null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          height: 110,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius14),
            border: Border.all(color: AppColors.plum700, width: 1.5),
            image: DecorationImage(
              image: FileImage(File(path!)),
              fit: BoxFit.cover,
            ),
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius14),
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              stops: const [0, .6],
              colors: [
                AppColors.scrim.withValues(alpha: .7),
                AppColors.scrim.withValues(alpha: 0),
              ],
            ),
          ),
          padding: const EdgeInsets.all(12),
          alignment: AlignmentDirectional.bottomStart,
          child: Row(
            children: [
              Icon(LucideIcons.circleCheck, size: 14, color: AppColors.bone),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).provVerifyUploaded(label),
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
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(AppTheme.radius14),
        ),
        child: CustomPaint(
          painter: DashedBorder(AppColors.divider, 14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.plum100,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
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
                      const SizedBox(height: 2),
                      Text(
                        hint,
                        style: AppTextStyles.micro.copyWith(
                          fontSize: AppTextStyles.fsMicroPlus,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(LucideIcons.upload, size: 18, color: AppColors.plum700),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
