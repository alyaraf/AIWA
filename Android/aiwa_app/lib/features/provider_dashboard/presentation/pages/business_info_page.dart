import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_chip.dart';
import '../../../../shared/widgets/aiwa_text_field.dart';
import '../../../../shared/widgets/aiwa_toast.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../data/provider_manage_repository.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _categories = [
  'HAIR',
  'NAILS',
  'SPA',
  'MAKEUP',
  'LASHES',
  'SKIN',
  'MASSAGE',
];

/// Business info — `BusinessInfoScreen` (provider-manage.jsx:11-66).
class BusinessInfoPage extends StatefulWidget {
  const BusinessInfoPage({super.key});

  @override
  State<BusinessInfoPage> createState() => _BusinessInfoPageState();
}

class _BusinessInfoPageState extends State<BusinessInfoPage> {
  final _repo = sl<ProviderManageRepository>();
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _address = TextEditingController();
  final _surcharge = TextEditingController();
  Json? _d;
  String? _loadError, _saveError;
  String? _cat;
  /// Prototype default until the stored serviceRadiusKm loads.
  int _radius = 8;
  int? _savedRadius;
  bool _dirty = false, _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _bio, _address, _surcharge]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final r = await _repo.detail(providerIdOf(context));
    if (!mounted) return;
    r.fold(
      (f) {
        setState(
          () => _loadError = AppLocalizations.of(context).error(f.message),
        );
      },
      (d) {
        _name.text = d['businessName'] as String? ?? '';
        _bio.text = d['bio'] as String? ?? '';
        _address.text = d['address'] as String? ?? '';
        final fee = d['homeServiceTravelFee'] as num?;
        _surcharge.text = fee == null || fee == 0 ? '' : fee.toStringAsFixed(0);
        setState(() {
          _d = d;
          _cat = d['primaryCategory'] as String?;
          _savedRadius = (d['serviceRadiusKm'] as num?)?.round();
          _radius = (_savedRadius ?? _radius).clamp(1, 25); // slider range
        });
      },
    );
  }

  void _touch([_]) => setState(() => _dirty = true);

  String? get _nameErr => _name.text.trim().length < 2
      ? AppLocalizations.of(context).biNameRequired
      : null;
  String? get _addrErr => _address.text.trim().length < 4
      ? AppLocalizations.of(context).biAddressRequired
      : null;

  Future<void> _save() async {
    final d = _d!;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final nameOrAddressChanged =
        _name.text.trim() != d['businessName'] ||
        _address.text.trim() != d['address'];
    final fee = num.tryParse(_surcharge.text.trim());
    final results = [
      await _repo.updateProfile({
        ...d,
        'businessName': _name.text.trim(),
        'bio': _bio.text.trim(),
        'address': _address.text.trim(),
        'primaryCategory': _cat,
      }),
      if (fee != d['homeServiceTravelFee']) await _repo.setTravelFee(fee),
      if (_radius != _savedRadius) await _repo.setServiceRadius(_radius),
    ];
    if (!mounted) return;
    final failure = results
        .map((r) => r.fold((f) => f, (_) => null))
        .nonNulls
        .firstOrNull;
    if (nameOrAddressChanged && results.first.isRight()) {
      // Re-review may flip verificationStatus; refresh the signed-in user.
      context.read<AuthBloc>().add(AuthGetCurrentUserEvent());
    }
    if (failure != null) {
      setState(() {
        _saving = false;
        _saveError = AppLocalizations.of(context).error(failure.message);
      });
      return;
    }
    showAiwaToast(context, AppLocalizations.of(context).biSaved);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final valid = _nameErr == null && _addrErr == null;
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bone,
      body: Column(
        children: [
          ScreenHeader(
            eyebrow: l.revEyebrow,
            title: l.ppBusinessInfo,
            onBack: () => context.pop(),
          ),
          Expanded(
            child: _d == null
                ? Padding(
                    padding: const EdgeInsets.all(AppTheme.gutter),
                    child: _loadError != null
                        ? ErrorState(
                            body: _loadError!,
                            onRetry: _load,
                            compact: true,
                          )
                        : const SkeletonList(),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.gutter,
                      14,
                      AppTheme.gutter,
                      0,
                    ),
                    children: [
                      ValidatedField(
                        error: _nameErr,
                        builder: (e) => AiwaTextField(
                          label: l.provBizName,
                          controller: _name,
                          icon: LucideIcons.store,
                          error: e,
                          onChanged: _touch,
                        ),
                      ),
                      const SizedBox(height: 14),
                      AiwaTextField(
                        label: l.provBizBio,
                        controller: _bio,
                        maxLines: 4,
                        maxLength: 220,
                        showCounter: true,
                        hint: l.biBioHint,
                        onChanged: _touch,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        l.provBizPrimaryCategory,
                        style: AppTextStyles.label.copyWith(
                          fontSize: AppTextStyles.fsLabelSmPlus,
                          color: AppColors.ink2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final c in _categories)
                            AiwaChip(
                              label: l.category(c),
                              active: _cat == c,
                              onTap: () => setState(() {
                                _cat = c;
                                _dirty = true;
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ValidatedField(
                        error: _addrErr,
                        builder: (e) => AiwaTextField(
                          label: l.biBaseAddress,
                          controller: _address,
                          icon: LucideIcons.mapPin,
                          error: e,
                          onChanged: _touch,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.paper,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius14,
                          ),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    l.biServiceRadius,
                                    style: AppTextStyles.label.copyWith(
                                      fontSize: AppTextStyles.fsMetaPlus,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                                Text(
                                  l.distanceKm('$_radius'),
                                  style: AppTextStyles.mono.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.plum700,
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              value: _radius.toDouble(),
                              min: 1,
                              max: 25,
                              divisions: 24,
                              onChanged: (v) => setState(() {
                                _radius = v.round();
                                _dirty = true;
                              }),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                for (final t in [
                                  l.distanceKm('1'),
                                  l.distanceKm('25'),
                                ])
                                  Text(
                                    t,
                                    style: AppTextStyles.mono.copyWith(
                                      fontSize: 10.5,
                                      color: AppColors.ink4,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      AiwaTextField(
                        label: l.biSurcharge,
                        controller: _surcharge,
                        icon: LucideIcons.car,
                        optional: true,
                        keyboardType: TextInputType.number,
                        hint: l.biSurchargeHint,
                        onChanged: _touch,
                      ),
                      const SizedBox(height: 14),
                      InlineBanner(
                        tone: BannerTone.info,
                        icon: LucideIcons.badgeCheck,
                        title: l.biVerifiedStudio,
                        body: l.biReReview,
                      ),
                      if (_saveError != null) ...[
                        const SizedBox(height: 10),
                        InlineBanner(tone: BannerTone.danger, body: _saveError),
                      ],
                      const SizedBox(height: 14),
                    ],
                  ),
          ),
          StickyBar(
            child: Row(
              spacing: 10,
              children: [
                Expanded(
                  child: AiwaButton(
                    label: l.commonCancel,
                    variant: AiwaButtonVariant.secondary,
                    size: AiwaButtonSize.lg,
                    onPressed: () => context.pop(),
                  ),
                ),
                Expanded(
                  child: AiwaButton(
                    label: l.commonSaveChanges,
                    size: AiwaButtonSize.lg,
                    loading: _saving,
                    onPressed: valid && _dirty && !_saving && _d != null
                        ? _save
                        : null,
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
