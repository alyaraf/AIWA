import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_text_field.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../widgets/step_header.dart';

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
  bool _hasLocation = false;
  final double _lat = 30.0444, _lng = 31.2357;

  static const _categories = [
    ('HAIR', 'Hair', Icons.content_cut_rounded),
    ('NAILS', 'Nails', Icons.back_hand_outlined),
    ('SPA', 'Spa', Icons.spa_outlined),
    ('MAKEUP', 'Makeup', Icons.brush_outlined),
    ('LASHES', 'Lashes', Icons.visibility_outlined),
    ('SKIN', 'Skin', Icons.water_drop_outlined),
    ('MASSAGE', 'Massage', Icons.volunteer_activism_outlined),
    ('OTHER', 'Other', Icons.auto_awesome_outlined),
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
    return AuthStepScaffold(
      stickyBar: true,
      bottom: AiwaButton(
        label: 'Continue',
        fullWidth: true,
        size: AiwaButtonSize.lg,
        onPressed: _isValid ? _continue : null,
      ),
      children: [
        StepHeader(
          step: 5,
          total: 6,
          title: 'Set up your studio',
          subtitle: 'Customers will see this on your profile.',
          onBack: () => context.pop(),
        ),
        const SizedBox(height: 22),
        AiwaTextField(
          label: 'Business name',
          placeholder: 'e.g. Nadia Studio',
          controller: _businessNameCtrl,
          icon: Icons.storefront_outlined,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        const EyebrowLabel('Business type'),
        const SizedBox(height: 6),
        Row(
          children: [
            _TypeOption(
              label: 'Individual',
              icon: Icons.person_outline_rounded,
              active: _businessType == 'individual',
              onTap: () => setState(() => _businessType = 'individual'),
            ),
            const SizedBox(width: 10),
            _TypeOption(
              label: 'Shop / salon',
              icon: Icons.storefront_outlined,
              active: _businessType == 'shop',
              onTap: () => setState(() => _businessType = 'shop'),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          'Shops can add staff members with their own calendars.',
          style: AppTextStyles.micro.copyWith(fontSize: 11.5),
        ),
        if (_businessType == 'shop') ...[
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(child: EyebrowLabel('Staff members')),
              Text(
                'Optional',
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
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: AiwaTextField(
                      controller: _staffCtrls[i],
                      placeholder: 'Staff member ${i + 1} name',
                      icon: Icons.person_outline_rounded,
                    ),
                  ),
                  if (_staffCtrls.length > 1)
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.danger700,
                      ),
                      onPressed: () {
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
          _DashedButton(
            label: 'Add staff member',
            onTap: () =>
                setState(() => _staffCtrls.add(TextEditingController())),
          ),
          const SizedBox(height: 5),
          Text(
            "Add the team who'll take bookings. You can add more later.",
            style: AppTextStyles.micro.copyWith(fontSize: 11.5),
          ),
        ],
        const SizedBox(height: 14),
        AiwaTextField(
          label: 'Short bio',
          optional: true,
          placeholder: 'Cairo-trained colorist with a soft, editorial touch…',
          hint: '2–3 lines on what makes you stand out.',
          controller: _bioCtrl,
          maxLines: 3,
          maxLength: 240,
          showCounter: true,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        const EyebrowLabel('Primary category'),
        const SizedBox(height: 6),
        GridView.count(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.95,
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
                      c.$3,
                      size: 18,
                      color: active ? AppColors.bone : AppColors.plum700,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      c.$2,
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
          'Pick the one you do most.',
          style: AppTextStyles.micro.copyWith(fontSize: 11.5),
        ),
        const SizedBox(height: 14),
        AiwaTextField(
          label: 'Studio address',
          placeholder: 'Street, neighborhood, city',
          controller: _addressCtrl,
          icon: Icons.location_on_outlined,
          suffixIcon: TextButton(
            onPressed: () => setState(() => _hasLocation = true),
            child: Text(
              'Use GPS',
              style: AppTextStyles.labelSm.copyWith(color: AppColors.plum700),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
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
                          ? 'GPS locked — $_lat, $_lng'
                          : 'No GPS — tap "Use GPS"',
                      style: AppTextStyles.labelSm.copyWith(
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Customers nearby can find you',
                      style: AppTextStyles.micro,
                    ),
                  ],
                ),
              ),
            ],
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

/// Dashed-looking "+ Add" row (hairline border, no fill).
class _DashedButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DashedButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 14, color: AppColors.plum700),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.label.copyWith(color: AppColors.plum700),
            ),
          ],
        ),
      ),
    );
  }
}
