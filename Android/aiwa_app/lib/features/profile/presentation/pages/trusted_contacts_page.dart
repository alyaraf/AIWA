import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_avatar.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_icon_button.dart';
import '../../../../shared/widgets/aiwa_text_field.dart';
import '../../../../shared/widgets/confirm_sheet.dart';
import '../../../../shared/widgets/dashed_button.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../data/account_repository.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Trusted contacts for SOS — `TrustedContactsScreen` in account-screens.jsx.
class TrustedContactsPage extends StatefulWidget {
  const TrustedContactsPage({super.key});

  @override
  State<TrustedContactsPage> createState() => _TrustedContactsPageState();
}

class _TrustedContactsPageState extends State<TrustedContactsPage> {
  final _repo = sl<AccountRepository>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _rel = TextEditingController();
  List<TrustedContact> _contacts = const [];
  bool _adding = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo.trustedContacts().then((r) {
      // A failed load (the endpoint doesn't exist yet) shows the empty state.
      if (mounted) r.fold((_) {}, (c) => setState(() => _contacts = c));
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _rel.dispose();
    super.dispose();
  }

  int get _digits => _phone.text.replaceAll(RegExp(r'\D'), '').length;
  bool get _canAdd => _name.text.trim().length >= 2 && _digits >= 9;

  void _startAdding() => setState(() {
    _adding = true;
    _error = null;
  });

  Future<void> _add() async {
    setState(() => _saving = true);
    final r = await _repo.addTrustedContact(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      relationship: _rel.text.trim().isEmpty
          ? AppLocalizations.of(context).tcContactDefault
          : _rel.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      r.fold((f) => _error = AppLocalizations.of(context).error(f.message), (
        c,
      ) {
        _contacts = [..._contacts, c];
        _adding = false;
        _error = null;
        _name.clear();
        _phone.clear();
        _rel.clear();
      });
    });
  }

  Future<void> _remove(TrustedContact c) async {
    final ok = await showConfirmSheet(
      context,
      eyebrow: AppLocalizations.of(context).tcSafety,
      title: AppLocalizations.of(context).tcRemoveTitle,
      body: AppLocalizations.of(context).tcRemoveBody,
      confirmLabel: AppLocalizations.of(context).tcRemove,
      icon: LucideIcons.userRoundMinus,
    );
    if (!ok || !mounted) return;
    final r = await _repo.removeTrustedContact(c.id);
    if (!mounted) return;
    setState(
      () => r.fold(
        (f) => _error = AppLocalizations.of(context).error(f.message),
        (_) => _contacts = [..._contacts.where((x) => x.id != c.id)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    void onChanged(String _) => setState(() {});
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bone,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          ScreenHeader(
            eyebrow: l.tcSafety,
            title: l.profTrustedContacts,
            onBack: () => context.pop(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gutter,
              14,
              AppTheme.gutter,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InlineBanner(
                  tone: BannerTone.warn,
                  icon: LucideIcons.siren,
                  title: l.tcBannerTitle,
                  body: l.tcBannerBody,
                ),
                const SizedBox(height: 16),
                if (_error != null && !_adding) ...[
                  InlineBanner(tone: BannerTone.danger, body: _error),
                  const SizedBox(height: 10),
                ],
                if (_contacts.isEmpty && !_adding)
                  EmptyState(
                    compact: true,
                    tone: EmptyStateTone.gold,
                    icon: LucideIcons.userPlus,
                    title: l.tcEmpty,
                    subtitle: l.tcEmptyBody,
                    actionLabel: l.tcAddContact,
                    onAction: _startAdding,
                  ),
                for (final c in _contacts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _ContactCard(contact: c, onRemove: () => _remove(c)),
                  ),
                if (_adding)
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(color: AppColors.plum700, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        EyebrowLabel(l.tcNew, color: AppColors.plum700),
                        const SizedBox(height: 12),
                        if (_error != null) ...[
                          InlineBanner(tone: BannerTone.danger, body: _error),
                          const SizedBox(height: 12),
                        ],
                        ValidatedField(
                          error: _name.text.trim().length < 2
                              ? l.tcNameError
                              : null,
                          builder: (e) => AiwaTextField(
                            validated: true,
                            label: l.svcName,
                            controller: _name,
                            icon: LucideIcons.user,
                            placeholder: l.tcNamePlaceholder,
                            autoFocus: true,
                            error: e,
                            onChanged: onChanged,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ValidatedField(
                          error: _digits < 9 ? l.tcPhoneError : null,
                          builder: (e) => AiwaTextField(
                            validated: true,
                            label: l.editMobile,
                            controller: _phone,
                            icon: LucideIcons.phone,
                            keyboardType: TextInputType.phone,
                            placeholder: '+20 100 000 0000',
                            error: e,
                            onChanged: onChanged,
                          ),
                        ),
                        const SizedBox(height: 14),
                        AiwaTextField(
                          validated: true,
                          label: l.tcRelationship,
                          controller: _rel,
                          icon: LucideIcons.heart,
                          placeholder: l.tcRelationshipPlaceholder,
                          optional: true,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          spacing: 9,
                          children: [
                            Expanded(
                              child: AiwaButton(
                                label: l.commonCancel,
                                variant: AiwaButtonVariant.secondary,
                                fullWidth: true,
                                onPressed: () => setState(() {
                                  _adding = false;
                                  _error = null;
                                }),
                              ),
                            ),
                            Expanded(
                              child: AiwaButton(
                                label: l.tcAdd,
                                fullWidth: true,
                                loading: _saving,
                                onPressed: _canAdd && !_saving ? _add : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else if (_contacts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: DashedButton(
                      label: l.tcAddAnother,
                      onTap: _startAdding,
                      radius: 15,
                      padding: 13,
                      iconSize: 15,
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

class _ContactCard extends StatelessWidget {
  final TrustedContact contact;
  final VoidCallback onRemove;
  const _ContactCard({required this.contact, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        spacing: 13,
        children: [
          AiwaAvatar(name: contact.name, size: 42, palette: AvatarPalette.gold),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: AppTextStyles.label.copyWith(
                    fontSize: 14,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  contact.phone,
                  // Keeps '+20…' intact in the Arabic UI.
                  textDirection: TextDirection.ltr,
                  style: AppTextStyles.mono.copyWith(
                    fontSize: 12,
                    color: AppColors.ink3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.gold100,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
            child: Text(
              contact.relationship,
              style: AppTextStyles.labelSm.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.gold700,
              ),
            ),
          ),
          AiwaIconButton(icon: LucideIcons.trash2, size: 34, onTap: onRemove),
        ],
      ),
    );
  }
}
