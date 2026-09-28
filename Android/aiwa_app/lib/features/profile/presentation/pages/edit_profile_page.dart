import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../shared/widgets/aiwa_avatar.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_text_field.dart';
import '../../../../shared/widgets/aiwa_toast.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import 'package:aiwa_app/l10n/l10n.dart';

/// Personal info — `EditProfileScreen` in account-screens.jsx.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _repo = sl<AuthRepository>();
  late final UserEntity? _user;
  late final _name = TextEditingController(text: _user?.fullName);
  late final _phone = TextEditingController(text: _user?.phone);
  late final _email = TextEditingController(text: _user?.email);
  late String _theme = ThemeController.mode.value;
  late bool _arabic = _wasArabic;
  bool _dirty = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = context.read<AuthBloc>().state;
    _user = s is AuthAuthenticated ? s.user : null;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  String? get _nameErr => _name.text.trim().length < 2
      ? AppLocalizations.of(context).editNameError
      : null;
  // Email-only accounts have no number, so an empty field stays valid.
  String? get _phoneErr =>
      _phone.text.isEmpty && (_user?.phone ?? '').isEmpty ||
          _phone.text.replaceAll(RegExp(r'\D'), '').length >= 9
      ? null
      : AppLocalizations.of(context).editPhoneError;
  String? get _emailErr =>
      _email.text.isNotEmpty && !RegExp(r'\S+@\S+\.\S+').hasMatch(_email.text)
      ? AppLocalizations.of(context).editEmailError
      : null;
  bool get _valid => _nameErr == null && _phoneErr == null && _emailErr == null;

  void _touch() => setState(() => _dirty = true);

  Future<void> _changePhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    final r = await _repo.uploadAvatar(file.path);
    if (!mounted) return;
    r.fold(
      (f) => setState(
        () => _error = AppLocalizations.of(context).error(f.message),
      ),
      (_) => context.read<AuthBloc>().add(AuthGetCurrentUserEvent()),
    );
  }

  bool get _wasArabic => _user?.preferredLanguage.toUpperCase() == 'AR';

  Future<Failure?> _persist() async {
    // Backend gap: PATCH /auth/me takes no phone; a number change needs an
    // OTP-verified endpoint.
    if (_phone.text.trim() != (_user?.phone ?? '')) {
      return const NotSupportedFailure('Changing your mobile number');
    }
    final email = _email.text.trim();
    final profile = await _repo.updateProfile(
      fullName: _name.text.trim(),
      email: email.isEmpty ? null : email,
    );
    if (profile.isLeft() || _arabic == _wasArabic) {
      return profile.fold((f) => f, (_) => null);
    }
    final lang = await _repo.updateLanguage(language: _arabic ? 'AR' : 'EN');
    return lang.fold((f) => f, (_) => null);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final failure = await _persist();
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _saving = false;
        _error = AppLocalizations.of(context).error(failure.message);
      });
      return;
    }
    ThemeController.set(_theme);
    if (_arabic != _wasArabic) LocaleController.set(_arabic ? 'ar' : 'en');
    context.read<AuthBloc>().add(AuthGetCurrentUserEvent());
    showAiwaToast(context, AppLocalizations.of(context).editProfileUpdated);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _valid && _dirty && !_saving;
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bone,
      body: Column(
        children: [
          ScreenHeader(
            eyebrow: l.editAccount,
            title: l.profPersonalInfo,
            onBack: () => context.pop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                16,
                AppTheme.gutter,
                24,
              ),
              children: [
                Row(
                  children: [
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (_, s) => AiwaAvatar(
                        name: _name.text,
                        size: 68,
                        palette: AvatarPalette.rose,
                        imageUrl: s is AuthAuthenticated
                            ? s.user.profileImageUrl
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AiwaButton(
                          label: l.editChangePhoto,
                          variant: AiwaButtonVariant.secondary,
                          size: AiwaButtonSize.sm,
                          icon: Icons.photo_camera_outlined,
                          onPressed: _changePhoto,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l.editPhotoHint,
                          style: AppTextStyles.micro.copyWith(
                            fontSize: 11.5,
                            color: AppColors.ink4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                if (_error != null) ...[
                  InlineBanner(tone: BannerTone.danger, body: _error),
                  const SizedBox(height: 14),
                ],
                ValidatedField(
                  error: _nameErr,
                  builder: (e) => AiwaTextField(
                    validated: true,
                    label: l.authFullName,
                    controller: _name,
                    icon: Icons.person_outline_rounded,
                    placeholder: l.editYourName,
                    error: e,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => _touch(),
                  ),
                ),
                const SizedBox(height: 14),
                ValidatedField(
                  error: _phoneErr,
                  builder: (e) => AiwaTextField(
                    validated: true,
                    label: l.editMobile,
                    controller: _phone,
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    hint: l.editMobileHint,
                    error: e,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => _touch(),
                  ),
                ),
                const SizedBox(height: 14),
                ValidatedField(
                  error: _emailErr,
                  builder: (e) => AiwaTextField(
                    validated: true,
                    label: l.authModeEmail,
                    controller: _email,
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    optional: true,
                    error: e,
                    onChanged: (_) => _touch(),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  l.editTheme,
                  style: AppTextStyles.label.copyWith(
                    fontSize: 12.5,
                    color: AppColors.ink2,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (final (id, label, p) in [
                      (
                        ThemeController.female,
                        l.editThemeMauve,
                        AiwaPalettes.female,
                      ),
                      (
                        ThemeController.male,
                        l.editThemeCharcoal,
                        AiwaPalettes.male,
                      ),
                    ]) ...[
                      if (id == ThemeController.male) const SizedBox(width: 9),
                      Expanded(
                        child: _ThemeOption(
                          label: label,
                          swatches: [p.plum500, p.rose300],
                          selected: _theme == id,
                          onTap: () => setState(() {
                            _theme = id;
                            _dirty = true;
                          }),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                SettingsRow(
                  icon: Icons.language_rounded,
                  label: l.profLanguage,
                  value: _arabic ? 'العربية' : 'English',
                  showDivider: false,
                  onTap: () => setState(() {
                    _arabic = !_arabic;
                    _dirty = true;
                  }),
                ),
              ],
            ),
          ),
          StickyBar(
            child: Row(
              children: [
                Expanded(
                  child: AiwaButton(
                    label: l.commonCancel,
                    variant: AiwaButtonVariant.secondary,
                    size: AiwaButtonSize.lg,
                    fullWidth: true,
                    onPressed: () => context.pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AiwaButton(
                    label: _saving ? l.editSaving : l.commonSaveChanges,
                    size: AiwaButtonSize.lg,
                    fullWidth: true,
                    loading: _saving,
                    onPressed: canSave ? _save : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final List<Color> swatches;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.swatches,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? AppColors.plum100 : AppColors.paper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.plum700 : AppColors.divider,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              for (final (i, c) in swatches.indexed)
                Transform.translate(
                  // Overlap toward the reading end.
                  offset: Offset(
                    i *
                        (Directionality.of(context) == TextDirection.rtl
                            ? 5.0
                            : -5.0),
                    0,
                  ),
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.paper, width: 1.5),
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.label.copyWith(
                    fontSize: 13.5,
                    color: AppColors.ink,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, size: 15, color: AppColors.plum700),
            ],
          ),
        ),
      ),
    );
  }
}
