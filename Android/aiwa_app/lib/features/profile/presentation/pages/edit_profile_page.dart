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
import '../widgets/secure_action_sheet.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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

  /// The number once its change went through (the page keeps the old user).
  String? _savedPhone;

  /// An email still waiting for its code (CR-05).
  late String? _pendingEmail = _user?.pendingEmail;

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
      maxWidth: 512,
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
    // A new number is confirmed by a code sent to it and the current password
    // (PATCH /auth/me/phone); other sessions are signed out and the repository
    // stores the new tokens.
    final phone = _phone.text.trim();
    if (phone != (_savedPhone ?? _user?.phone ?? '')) {
      final sent = await _repo.sendOtp(phone: phone);
      if (sent.isLeft()) return sent.fold((f) => f, (_) => null);
      if (!mounted) return null;
      final l = AppLocalizations.of(context);
      final done = await showSecureActionSheet(
        context,
        title: l.authEnterCode,
        body: l.authCodeSentTo(phone),
        askCode: true,
        confirmLabel: l.authVerify,
        onSubmit: (password, code) async => (await _repo.changePhone(
          phone: phone,
          code: code,
          currentPassword: password,
        )).fold((f) => f, (_) => null),
      );
      if (!done) return ServerFailure(l.authEnterCode);
      _savedPhone = phone;
    }
    final email = _email.text.trim();
    // A different address needs the current password and a code sent to it.
    final emailChanged =
        email.isNotEmpty &&
        email.toLowerCase() != (_user?.email ?? '').toLowerCase();
    final Failure? failure;
    if (emailChanged) {
      failure = await _changeEmail(email);
    } else {
      final profile = await _repo.updateProfile(
        fullName: _name.text.trim(),
        email: email.isEmpty ? null : email,
      );
      failure = profile.fold((f) => f, (_) => null);
    }
    if (failure != null || _arabic == _wasArabic) return failure;
    final lang = await _repo.updateLanguage(language: _arabic ? 'AR' : 'EN');
    return lang.fold((f) => f, (_) => null);
  }

  /// PATCH /auth/me with the password, then the code step. Closing the code
  /// step is not a failure: the address stays pending until confirmed.
  Future<Failure?> _changeEmail(String email) async {
    final l = AppLocalizations.of(context);
    final saved = await showSecureActionSheet(
      context,
      title: l.editConfirmTitle,
      body: l.editConfirmBody,
      confirmLabel: l.commonConfirm,
      onSubmit: (password, _) async => (await _repo.updateProfile(
        fullName: _name.text.trim(),
        email: email,
        currentPassword: password,
      )).fold((f) => f, (_) => null),
    );
    if (!saved) return ServerFailure(l.editConfirmBody);
    _pendingEmail = email;
    if (!mounted) return null;
    await _enterEmailCode(email);
    return null;
  }

  /// Code step for the pending [email]; true once it is confirmed.
  Future<bool> _enterEmailCode(String email) async {
    final l = AppLocalizations.of(context);
    final ok = await showSecureActionSheet(
      context,
      title: l.editEmailCodeTitle,
      body: l.authCodeSentTo(email),
      askPassword: false,
      askCode: true,
      confirmLabel: l.authVerify,
      onSubmit: (_, code) async =>
          (await _repo.verifyEmail(code: code)).fold((f) => f, (_) => null),
    );
    if (ok) _pendingEmail = null;
    return ok;
  }

  Future<void> _confirmPendingEmail() async {
    final ok = await _enterEmailCode(_pendingEmail!);
    if (!ok || !mounted) return;
    context.read<AuthBloc>().add(AuthGetCurrentUserEvent());
    showAiwaToast(context, AppLocalizations.of(context).editEmailConfirmed);
    setState(() {});
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
                          icon: LucideIcons.camera,
                          onPressed: _changePhoto,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l.editPhotoHint,
                          style: AppTextStyles.micro.copyWith(
                            fontSize: AppTextStyles.fsMicroPlus,
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
                if (_pendingEmail != null) ...[
                  InlineBanner(
                    body: l.editEmailPending(_pendingEmail!),
                    action: l.authEnterCode,
                    onAction: _confirmPendingEmail,
                  ),
                  const SizedBox(height: 14),
                ],
                ValidatedField(
                  error: _nameErr,
                  builder: (e) => AiwaTextField(
                    validated: true,
                    label: l.authFullName,
                    controller: _name,
                    icon: LucideIcons.user,
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
                    icon: LucideIcons.phone,
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
                    icon: LucideIcons.mail,
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
                    fontSize: AppTextStyles.fsLabelSmPlus,
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
                  icon: LucideIcons.globe,
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
            borderRadius: BorderRadius.circular(AppTheme.radius14),
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
                    fontSize: AppTextStyles.fsMetaPlus,
                    color: AppColors.ink,
                  ),
                ),
              ),
              if (selected)
                Icon(LucideIcons.check, size: 15, color: AppColors.plum700),
            ],
          ),
        ),
      ),
    );
  }
}
