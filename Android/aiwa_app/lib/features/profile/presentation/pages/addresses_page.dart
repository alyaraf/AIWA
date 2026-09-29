import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_icon_button.dart';
import '../../../../shared/widgets/aiwa_text_field.dart';
import '../../../../shared/widgets/aiwa_toast.dart';
import '../../../../shared/widgets/aiwa_toggle.dart';
import '../../../../shared/widgets/confirm_sheet.dart';
import '../../../../shared/widgets/dashed_button.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../bookings/domain/entities/saved_address_entity.dart';
import '../../../onboarding/presentation/pages/permission_priming_page.dart';
import '../../data/account_repository.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

IconData _labelIcon(String label) => switch (label) {
  'Home' => LucideIcons.house,
  'Work' => LucideIcons.briefcase,
  _ => LucideIcons.mapPin,
};

/// Saved addresses — `AddressesScreen` in customer-extras-2.jsx.
class AddressesPage extends StatefulWidget {
  const AddressesPage({super.key});

  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  final _repo = sl<AccountRepository>();
  List<SavedAddressEntity>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await _repo.addresses();
    if (!mounted) return;
    setState(() {
      _error = r.fold(
        (f) => AppLocalizations.of(context).error(f.message),
        (_) => null,
      );
      _items = r.fold((_) => _items, (a) => a);
    });
  }

  Future<void> _open(String location, [SavedAddressEntity? extra]) async {
    await context.push(location, extra: extra);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bone,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          ScreenHeader(
            eyebrow: l.editAccount,
            title: l.profSavedAddresses,
            onBack: () => context.pop(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gutter,
              18,
              AppTheme.gutter,
              0,
            ),
            child: _error != null && items == null
                ? ErrorState(body: _error!, onRetry: _load, compact: true)
                : items == null
                ? const SkeletonList(count: 2)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 10,
                    children: [
                      if (items.isEmpty)
                        EmptyState(
                          compact: true,
                          icon: LucideIcons.mapPin,
                          title: l.addrEmpty,
                          subtitle: l.addrEmptyBody,
                        ),
                      for (final a in items)
                        _AddressCard(
                          address: a,
                          onEdit: () => _open('/addresses/${a.id}/edit', a),
                        ),
                      DashedButton(
                        label: l.bookingAddAddress,
                        onTap: () => _open(AppRoutes.addressNew),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final SavedAddressEntity address;
  final VoidCallback onEdit;
  const _AddressCard({required this.address, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.plum100,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(
              _labelIcon(address.label),
              size: 18,
              color: AppColors.plum700,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).addressLabel(address.label),
                  style: AppTextStyles.label.copyWith(
                    fontSize: 14,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  address.addressLine,
                  style: AppTextStyles.micro.copyWith(
                    fontSize: AppTextStyles.fsLabelSmPlus,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AiwaIconButton(icon: LucideIcons.pencil, size: 34, onTap: onEdit),
        ],
      ),
    );
  }
}

/// New / edit address — `AddressFormScreen` in account-screens.jsx.
class AddressFormPage extends StatefulWidget {
  final SavedAddressEntity? existing;
  const AddressFormPage({super.key, this.existing});

  @override
  State<AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends State<AddressFormPage> {
  final _repo = sl<AccountRepository>();
  late String _label = switch (widget.existing?.label) {
    final l? when const ['Home', 'Work', 'Other'].contains(l) => l,
    null => 'Home',
    _ => 'Other',
  };
  // The backend stores one addressLine, so an edit pre-fills it as the street.
  late final _street = TextEditingController(
    text: widget.existing?.addressLine,
  );
  final _building = TextEditingController();
  final _floor = TextEditingController();
  final _apartment = TextEditingController();
  final _landmark = TextEditingController();
  final _notes = TextEditingController();
  late bool _isDefault = widget.existing?.isDefault ?? false;
  Position? _pin;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    for (final c in [
      _street,
      _building,
      _floor,
      _apartment,
      _landmark,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _streetErr => _street.text.trim().length < 4
      ? AppLocalizations.of(context).addrStreetError
      : null;
  String? get _buildingErr => _building.text.trim().isEmpty
      ? AppLocalizations.of(context).addrBuildingError
      : null;
  bool get _valid => _streetErr == null && _buildingErr == null;

  /// "14 Road 9, Maadi, Floor 3, Apt 7, opposite Sakia, [notes]".
  // ponytail: the backend has one addressLine column (255), so the extra
  // fields are folded into it; split them out when SavedAddress grows columns.
  String get _addressLine {
    final l = AppLocalizations.of(context);
    final line = [
      '${_building.text.trim()} ${_street.text.trim()}',
      if (_floor.text.trim().isNotEmpty) l.addrFloorN(_floor.text.trim()),
      if (_apartment.text.trim().isNotEmpty) l.addrAptN(_apartment.text.trim()),
      if (_landmark.text.trim().isNotEmpty) _landmark.text.trim(),
      if (_notes.text.trim().isNotEmpty) _notes.text.trim(),
    ].join(', ');
    return line.length > 255 ? line.substring(0, 255) : line;
  }

  Future<void> _dropPin() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (!mounted) return;
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      // Its fallback ("Pick my area manually") returns here to type it in.
      context.push(PermissionDeniedPage.path(PermissionKind.location));
      return;
    }
    try {
      final p = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _pin = p);
    } catch (_) {}
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final r = _editing
        ? await _repo.updateAddress(
            widget.existing!.id,
            label: _label,
            addressLine: _addressLine,
            latitude: _pin?.latitude,
            longitude: _pin?.longitude,
            isDefault: _isDefault,
          )
        : await _repo.addAddress(
            label: _label,
            addressLine: _addressLine,
            latitude: _pin?.latitude,
            longitude: _pin?.longitude,
            isDefault: _isDefault,
          );
    if (!mounted) return;
    r.fold(
      (f) => setState(() {
        _saving = false;
        _error = AppLocalizations.of(context).error(f.message);
      }),
      (_) {
        showAiwaToast(
          context,
          _editing
              ? AppLocalizations.of(context).addrUpdated
              : AppLocalizations.of(context).addrAdded,
        );
        context.pop(true);
      },
    );
  }

  Future<void> _delete() async {
    final ok = await showConfirmSheet(
      context,
      eyebrow: AppLocalizations.of(context).addrRemove,
      title: AppLocalizations.of(
        context,
      ).addrDeleteTitle(AppLocalizations.of(context).addressLabel(_label)),
      body: AppLocalizations.of(context).addrDeleteBody,
      confirmLabel: AppLocalizations.of(context).commonDelete,
      icon: LucideIcons.trash2,
    );
    if (!ok || !mounted) return;
    final r = await _repo.deleteAddress(widget.existing!.id);
    if (!mounted) return;
    r.fold(
      (f) => setState(
        () => _error = AppLocalizations.of(context).error(f.message),
      ),
      (_) {
        showAiwaToast(context, AppLocalizations.of(context).addrDeleted);
        context.pop(true);
      },
    );
  }

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: AppTextStyles.label.copyWith(
        fontSize: AppTextStyles.fsLabelSmPlus,
        color: AppColors.ink2,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    void onChanged(String _) => setState(() {});
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bone,
      body: Column(
        children: [
          ScreenHeader(
            eyebrow: l.profSavedAddresses,
            title: _editing ? l.addrEditTitle : l.addrNewTitle,
            onBack: () => context.pop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                14,
                AppTheme.gutter,
                24,
              ),
              children: [
                _MapPlaceholder(dropped: _pin != null, onDropPin: _dropPin),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  InlineBanner(tone: BannerTone.danger, body: _error),
                  const SizedBox(height: 14),
                ],
                _fieldLabel(l.addrLabel),
                Row(
                  spacing: 8,
                  children: [
                    for (final v in const ['Home', 'Work', 'Other'])
                      Expanded(
                        child: _LabelOption(
                          label: v,
                          selected: _label == v,
                          onTap: () => setState(() => _label = v),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                ValidatedField(
                  error: _streetErr,
                  builder: (e) => AiwaTextField(
                    validated: true,
                    label: l.addrStreet,
                    controller: _street,
                    icon: LucideIcons.signpost,
                    placeholder: l.addrStreetPlaceholder,
                    error: e,
                    onChanged: onChanged,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 9,
                  children: [
                    Expanded(
                      flex: 14,
                      child: ValidatedField(
                        error: _buildingErr,
                        builder: (e) => AiwaTextField(
                          validated: true,
                          label: l.addrBuilding,
                          controller: _building,
                          placeholder: '14',
                          error: e,
                          onChanged: onChanged,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 10,
                      child: AiwaTextField(
                        validated: true,
                        label: l.addrFloor,
                        controller: _floor,
                        placeholder: '3',
                        optional: true,
                      ),
                    ),
                    Expanded(
                      flex: 10,
                      child: AiwaTextField(
                        validated: true,
                        label: l.addrApt,
                        controller: _apartment,
                        placeholder: '7',
                        optional: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AiwaTextField(
                  validated: true,
                  label: l.addrLandmark,
                  controller: _landmark,
                  icon: LucideIcons.landmark,
                  placeholder: l.addrLandmarkPlaceholder,
                  optional: true,
                  hint: l.addrLandmarkHint,
                ),
                const SizedBox(height: 14),
                AiwaTextField(
                  validated: true,
                  label: l.addrNotes,
                  controller: _notes,
                  placeholder: l.addrNotesPlaceholder,
                  optional: true,
                  maxLines: 3,
                  maxLength: 140,
                  showCounter: true,
                  onChanged: onChanged,
                ),
                const SizedBox(height: 14),
                SettingsRow(
                  icon: LucideIcons.star,
                  label: l.addrDefault,
                  sub: l.addrDefaultSub,
                  boxed: true,
                  onTap: () => setState(() => _isDefault = !_isDefault),
                  right: AiwaToggle(
                    value: _isDefault,
                    onChanged: (v) => setState(() => _isDefault = v),
                  ),
                ),
                if (_editing) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _delete,
                    icon: const Icon(LucideIcons.trash2, size: 15),
                    label: Text(l.addrDeleteThis),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger700,
                      side: BorderSide(color: AppColors.danger100, width: 1.5),
                      padding: const EdgeInsets.all(13),
                      textStyle: AppTextStyles.label.copyWith(fontSize: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius14),
                      ),
                    ),
                  ),
                ],
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
                    label: _editing ? l.addrSave : l.addrAdd,
                    size: AiwaButtonSize.lg,
                    fullWidth: true,
                    loading: _saving,
                    onPressed: _valid && !_saving ? _save : null,
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

class _LabelOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LabelOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.paper : AppColors.ink;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppTheme.dur2,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? AppColors.plum700 : AppColors.paper,
            borderRadius: BorderRadius.circular(AppTheme.radius14),
            border: Border.all(
              color: selected ? Colors.transparent : AppColors.divider,
              width: 1.5,
            ),
          ),
          child: Column(
            spacing: 5,
            children: [
              Icon(
                _labelIcon(label),
                size: 17,
                color: selected ? AppColors.paper : AppColors.plum700,
              ),
              Text(
                AppLocalizations.of(context).addressLabel(label),
                style: AppTextStyles.label.copyWith(
                  fontSize: AppTextStyles.fsLabelSmPlus,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 132px map stand-in with a centred pin and a "Drop pin" pill.
// ponytail: no map SDK is installed; "Drop pin" stores the device position.
class _MapPlaceholder extends StatelessWidget {
  final bool dropped;
  final VoidCallback onDropPin;
  const _MapPlaceholder({required this.dropped, required this.onDropPin});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.divider),
        gradient: LinearGradient(
          begin: const Alignment(-.6, -1),
          end: const Alignment(.6, 1),
          colors: [AppColors.plum100, AppColors.cream, AppColors.gold100],
          stops: const [0, .55, 1],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(AppColors.divider.withValues(alpha: .5)),
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.plum700,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.scrim.withValues(alpha: .3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(LucideIcons.mapPin, size: 18, color: AppColors.paper),
          ),
          PositionedDirectional(
            end: 10,
            bottom: 10,
            child: GestureDetector(
              onTap: onDropPin,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.paper.withValues(alpha: .94),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    Icon(
                      dropped ? LucideIcons.check : LucideIcons.crosshair,
                      size: 13,
                      color: AppColors.plum700,
                    ),
                    Text(
                      dropped
                          ? AppLocalizations.of(context).addrPinDropped
                          : AppLocalizations.of(context).addrDropPin,
                      style: AppTextStyles.label.copyWith(
                        fontSize: 12,
                        color: AppColors.plum700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color color;
  const _GridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    for (var x = 0.0; x < size.width; x += 26) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), p);
    }
    for (var y = 0.0; y < size.height; y += 26) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.color != color;
}
