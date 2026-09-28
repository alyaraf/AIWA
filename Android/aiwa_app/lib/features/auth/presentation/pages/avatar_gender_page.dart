import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/press_scale.dart';
import '../widgets/step_header.dart';
import 'package:aiwa_app/l10n/l10n.dart';

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
  // Woman is preselected (prototype.jsx:535); its palette previews at once
  // and is only persisted on Continue.
  String _gender = 'FEMALE';
  String? _avatar;

  bool get _isProvider => widget.role == 'PROVIDER';
  int get _totalSteps => _isProvider ? 6 : 4;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ThemeController.applyGender(_gender, persist: false),
    );
  }

  void _pick(String gender) {
    setState(() => _gender = gender);
    ThemeController.applyGender(gender, persist: false);
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file != null && mounted) setState(() => _avatar = file.path);
  }

  /// Account creation waits for Terms + Preferences (prototype.jsx:644-645).
  void _continue() {
    ThemeController.applyGender(_gender);
    context.push(
      _isProvider ? AppRoutes.providerBusiness : AppRoutes.terms,
      extra: {
        ...widget.registrationData,
        'gender': _gender,
        'avatarPath': _avatar,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthStepScaffold(
      bottom: AiwaButton(
        label: _avatar == null
            ? AppLocalizations.of(context).authContinueWithoutPhoto
            : AppLocalizations.of(context).commonContinue,
        fullWidth: true,
        size: AiwaButtonSize.lg,
        onPressed: _continue,
      ),
      children: [
        StepHeader(
          step: 4,
          total: _totalSteps,
          title: AppLocalizations.of(context).authMakeItYours,
          subtitle: AppLocalizations.of(context).authMakeItYoursSub,
          onBack: () => context.pop(),
        ),
        const SizedBox(height: 22),
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickPhoto,
                child: Stack(
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
                        image: _avatar == null
                            ? null
                            : DecorationImage(
                                image: FileImage(File(_avatar!)),
                                fit: BoxFit.cover,
                              ),
                        border: Border.all(color: AppColors.paper, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.plum700.withValues(alpha: .18),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: _avatar == null
                          ? Icon(
                              Icons.camera_alt_outlined,
                              size: 36,
                              color: AppColors.bone,
                            )
                          : null,
                    ),
                    PositionedDirectional(
                      end: 0,
                      bottom: 0,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.plum700,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.bone, width: 3),
                        ),
                        child: Icon(
                          _avatar == null
                              ? Icons.add_rounded
                              : Icons.edit_outlined,
                          size: 16,
                          color: AppColors.bone,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickPhoto,
                child: Text(
                  _avatar == null
                      ? AppLocalizations.of(context).authUploadPhoto
                      : AppLocalizations.of(context).authReplacePhoto,
                  style: AppTextStyles.label.copyWith(color: AppColors.plum700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        EyebrowLabel(AppLocalizations.of(context).authSigningUpAs),
        const SizedBox(height: 6),
        Row(
          children: [
            _GenderOption(
              label: AppLocalizations.of(context).authWoman,
              swatches: AiwaPalettes.female,
              selected: _gender == 'FEMALE',
              onTap: () => _pick('FEMALE'),
            ),
            const SizedBox(width: 10),
            _GenderOption(
              label: AppLocalizations.of(context).authMan,
              swatches: AiwaPalettes.male,
              selected: _gender == 'MALE',
              onTap: () => _pick('MALE'),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          AppLocalizations.of(context).authPaletteNote,
          style: AppTextStyles.micro.copyWith(fontSize: 11.5),
        ),
      ],
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
    final colors = [swatches.plum700, swatches.plum300, swatches.bone];
    return Expanded(
      child: PressScale(
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
                        margin: const EdgeInsetsDirectional.only(end: 4),
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
