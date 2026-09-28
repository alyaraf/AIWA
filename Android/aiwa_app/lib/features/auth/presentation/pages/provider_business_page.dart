import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_text_field.dart';
import '../../../../shared/widgets/dashed_button.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../widgets/step_header.dart';
import 'package:aiwa_app/l10n/l10n.dart';

class ProviderBusinessPage extends StatefulWidget {
  final Map<String, dynamic> registrationData;
  const ProviderBusinessPage({super.key, required this.registrationData});

  @override
  State<ProviderBusinessPage> createState() => _ProviderBusinessPageState();
}

class _ProviderBusinessPageState extends State<ProviderBusinessPage> {
  final _businessNameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _addressCtrl = TextEditingController(text: 'Maadi, Cairo');
  final List<TextEditingController> _staffCtrls = [TextEditingController()];
  String? _category;
  String _businessType = 'individual';
  bool _hasLocation = true;
  final double _lat = 30.0444, _lng = 31.2357;

  static const _categories = [
    ('HAIR', Icons.content_cut_rounded),
    ('NAILS', Icons.back_hand_outlined),
    ('SPA', Icons.spa_outlined),
    ('MAKEUP', Icons.brush_outlined),
    ('LASHES', Icons.visibility_outlined),
    ('SKIN', Icons.water_drop_outlined),
    ('MASSAGE', Icons.volunteer_activism_outlined),
    ('OTHER', Icons.auto_awesome_outlined),
  ];

  bool get _isValid =>
      _businessNameCtrl.text.trim().length >= 2 && _category != null;

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _bioCtrl.dispose();
    _addressCtrl.dispose();
    for (final c in _staffCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _continue() {
    context.push(
      AppRoutes.providerVerification,
      extra: {
        ...widget.registrationData,
        'businessName': _businessNameCtrl.text.trim(),
        'businessType': _businessType,
        'staff': _businessType == 'shop'
            ? _staffCtrls
                  .map((c) => c.text.trim())
                  .where((n) => n.isNotEmpty)
                  .toList()
            : <String>[],
        'bio': _bioCtrl.text,
        'address': _addressCtrl.text,
        'primaryCategory': _category,
        'latitude': _lat,
        'longitude': _lng,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AuthStepScaffold(
      stickyBar: true,
      bottom: AiwaButton(
        label: l.commonContinue,
        fullWidth: true,
        size: AiwaButtonSize.lg,
        onPressed: _isValid ? _continue : null,
      ),
      children: [
        StepHeader(
          step: 5,
          total: 6,
          title: l.provBizTitle,
          subtitle: l.provBizSubtitle,
          onBack: () => context.pop(),
        ),
        const SizedBox(height: 22),
        AiwaTextField(
          label: l.provBizName,
          placeholder: l.provBizNamePlaceholder,
          controller: _businessNameCtrl,
          icon: Icons.storefront_outlined,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        EyebrowLabel(l.provBizType),
        const SizedBox(height: 6),
        Row(
          children: [
            _TypeOption(
              label: l.provBizIndividual,
              icon: Icons.person_outline_rounded,
              active: _businessType == 'individual',
              onTap: () => setState(() => _businessType = 'individual'),
            ),
            const SizedBox(width: 10),
            _TypeOption(
              label: l.provBizShop,
              icon: Icons.storefront_outlined,
              active: _businessType == 'shop',
              onTap: () => setState(() => _businessType = 'shop'),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          l.provBizShopNote,
          style: AppTextStyles.micro.copyWith(fontSize: 11.5),
        ),
        if (_businessType == 'shop') ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: EyebrowLabel(l.provBizStaff)),
              Text(
                l.commonOptional,
                style: AppTextStyles.micro.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < _staffCtrls.length; i++)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: AiwaTextField(
                      controller: _staffCtrls[i],
                      placeholder: l.provBizStaffName(i + 1),
                      icon: Icons.person_outline_rounded,
                    ),
                  ),
                  if (_staffCtrls.length > 1)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: AppColors.danger700,
                        ),
                      ),
                      onTap: () {
                        final removed = _staffCtrls.removeAt(i);
                        setState(() {});
                        // Dispose after the field has detached from it.
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => removed.dispose(),
                        );
                      },
                    ),
                ],
              ),
            ),
          DashedButton(
            label: l.provBizAddStaff,
            onTap: () =>
                setState(() => _staffCtrls.add(TextEditingController())),
            radius: 12,
            padding: 10,
            fontSize: 13,
            iconSize: 14,
            gap: 6,
          ),
          const SizedBox(height: 5),
          Text(
            l.provBizStaffNote,
            style: AppTextStyles.micro.copyWith(fontSize: 11.5),
          ),
        ],
        const SizedBox(height: 14),
        AiwaTextField(
          label: l.provBizBio,
          optional: true,
          placeholder: l.provBizBioPlaceholder,
          hint: l.provBizBioHint,
          controller: _bioCtrl,
          maxLines: 3,
          maxLength: 240,
          // 14px text; line height 4/3 makes 3 lines + 14px pads = the 84px box.
          textStyle: AppTextStyles.bodySm.copyWith(
            color: AppColors.ink,
            height: 4 / 3,
          ),
          belowInput: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                '${_bioCtrl.text.length}/240',
                style: AppTextStyles.micro,
              ),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        EyebrowLabel(l.provBizPrimaryCategory),
        const SizedBox(height: 6),
        GridView.count(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.2,
          children: _categories.map((c) {
            final active = _category == c.$1;
            return GestureDetector(
              onTap: () => setState(() => _category = c.$1),
              child: AnimatedContainer(
                duration: AppTheme.dur2,
                curve: AppTheme.easeSoft,
                decoration: BoxDecoration(
                  color: active ? AppColors.plum700 : AppColors.paper,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? Colors.transparent : AppColors.divider,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      c.$2,
                      size: 18,
                      color: active ? AppColors.bone : AppColors.plum700,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l.category(c.$1),
                      style: AppTextStyles.labelSm.copyWith(
                        fontSize: 11.5,
                        color: active ? AppColors.bone : AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 5),
        Text(
          l.provBizPickOne,
          style: AppTextStyles.micro.copyWith(fontSize: 11.5),
        ),
        const SizedBox(height: 14),
        AiwaTextField(
          label: l.provBizAddress,
          placeholder: l.provBizAddressPlaceholder,
          controller: _addressCtrl,
          icon: Icons.location_on_outlined,
          suffixIcon: TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsetsDirectional.only(end: 14),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              splashFactory: NoSplash.splashFactory,
            ),
            onPressed: () => setState(() => _hasLocation = true),
            child: Text(
              l.commonUseGps,
              style: AppTextStyles.labelSm.copyWith(color: AppColors.plum700),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(12),
          ),
          child: CustomPaint(
            painter: DashedBorder(AppColors.divider, 12, width: 1),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _hasLocation
                          ? AppColors.success100
                          : AppColors.warn100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _hasLocation
                          ? Icons.check_rounded
                          : Icons.location_on_outlined,
                      size: 16,
                      color: _hasLocation
                          ? AppColors.success700
                          : AppColors.warn700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _hasLocation
                              ? l.provBizGpsLocked('$_lat', '$_lng')
                              : l.provBizNoGps,
                          style: AppTextStyles.labelSm.copyWith(
                            fontSize: 12.5,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(l.provBizNearby, style: AppTextStyles.micro),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _TypeOption({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppTheme.dur2,
          curve: AppTheme.easeSoft,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.plum700 : AppColors.paper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? Colors.transparent : AppColors.divider,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: active ? AppColors.bone : AppColors.plum700,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppTextStyles.label.copyWith(
                  color: active ? AppColors.bone : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
