import 'package:flutter/material.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_chip.dart';
import '../../../../shared/widgets/aiwa_icon_button.dart';
import '../../../../shared/widgets/aiwa_sheet.dart';
import '../../../../shared/widgets/aiwa_text_field.dart';
import '../../../../shared/widgets/aiwa_toast.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../data/provider_manage_repository.dart';
import 'package:aiwa_app/l10n/l10n.dart';

/// Services tab — `ProviderServices` (provider-screens.jsx:401-430).
class ProviderServicesPage extends StatefulWidget {
  const ProviderServicesPage({super.key});

  @override
  State<ProviderServicesPage> createState() => _ProviderServicesPageState();
}

class _ProviderServicesPageState extends State<ProviderServicesPage> {
  final _repo = sl<ProviderManageRepository>();
  List<Json>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await _repo.detail(providerIdOf(context));
    if (!mounted) return;
    setState(() {
      _error = r.fold(
        (f) => AppLocalizations.of(context).error(f.message),
        (_) => null,
      );
      _items = r.fold(
        (_) => _items,
        (d) => [for (final s in d['services'] as List? ?? const []) s as Json],
      );
    });
  }

  Future<void> _edit([Json? s]) async {
    final saved = await showAiwaSheet<bool>(
      context,
      builder: (_) => _ServiceForm(existing: s),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bone,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.plum700,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            PageTitle(
              eyebrow: l.svcEyebrow,
              title: l.tabServices,
              trailing: AiwaButton(
                label: l.svcNew,
                icon: Icons.add_rounded,
                size: AiwaButtonSize.sm,
                onPressed: () => _edit(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                14,
                AppTheme.gutter,
                0,
              ),
              child: items == null
                  ? (_error != null
                        ? ErrorState(
                            body: _error!,
                            onRetry: _load,
                            compact: true,
                          )
                        : const SkeletonList())
                  : items.isEmpty
                  ? EmptyState(
                      icon: Icons.list_rounded,
                      title: l.svcEmpty,
                      subtitle: l.svcEmptyBody,
                      actionLabel: l.svcNew,
                      onAction: () => _edit(),
                      compact: true,
                    )
                  : Column(
                      spacing: 10,
                      children: [
                        for (final s in items)
                          _ServiceRow(s: s, onEdit: () => _edit(s)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  final Json s;
  final VoidCallback onEdit;
  const _ServiceRow({required this.s, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    // ponytail: GET /providers/{id}/services is active-only, so 'Hidden'
    // rows only show if the backend ever returns inactive ones.
    final active = s['active'] != false;
    final l = AppLocalizations.of(context);
    final meta = AppTextStyles.micro.copyWith(
      fontSize: 12,
      color: AppColors.ink3,
    );
    return Opacity(
      opacity: active ? 1 : .55,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${s['name']}',
                    style: AppTextStyles.body.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        l.durationMinutes(s['durationMinutes'] as int? ?? 0),
                        style: meta,
                      ),
                      const MetaDot(),
                      Text(
                        s['pricingType'] == 'STARTS_AT'
                            ? l.svcStartsAt
                            : l.svcFixedPrice,
                        style: meta,
                      ),
                      if (!active) ...[
                        const MetaDot(),
                        Text(
                          l.svcHidden,
                          style: meta.copyWith(
                            color: AppColors.danger700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Text(
              l.egp(s['price'] as num? ?? 0),
              style: AppTextStyles.h3.copyWith(
                fontSize: 18,
                color: AppColors.plum900,
              ),
            ),
            const SizedBox(width: 14),
            AiwaIconButton(icon: Icons.edit_outlined, size: 34, onTap: onEdit),
          ],
        ),
      ),
    );
  }
}

/// New / edit service. The prototype's 'New' and pencil have no form, so
/// this is the minimum ServiceRequest needs.
class _ServiceForm extends StatefulWidget {
  final Json? existing;
  const _ServiceForm({this.existing});

  @override
  State<_ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends State<_ServiceForm> {
  late final _name = TextEditingController(
    text: widget.existing?['name'] as String?,
  );
  late final _price = TextEditingController(
    text: (widget.existing?['price'] as num?)?.toStringAsFixed(0),
  );
  late final _duration = TextEditingController(
    text: '${widget.existing?['durationMinutes'] ?? 60}',
  );
  late bool _fixed = widget.existing?['pricingType'] != 'STARTS_AT';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _duration.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      (num.tryParse(_price.text) ?? 0) > 0 &&
      (int.tryParse(_duration.text) ?? 0) >= 5;

  Future<void> _run(Future<dynamic> Function() call, String toast) async {
    setState(() => _busy = true);
    final r = await call();
    if (!mounted) return;
    r.fold(
      (f) => setState(() {
        _busy = false;
        _error = AppLocalizations.of(context).error(f.message);
      }),
      (_) {
        showAiwaToast(context, toast);
        Navigator.pop(context, true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.existing?['id']?.toString();
    final repo = sl<ProviderManageRepository>();
    final l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EyebrowLabel(l.svcEyebrow),
              const SizedBox(height: 2),
              Text(
                id == null ? l.svcNewService : l.svcEditService,
                style: AppTextStyles.h3,
              ),
            ],
          ),
          AiwaTextField(
            label: l.svcName,
            controller: _name,
            onChanged: (_) => setState(() {}),
          ),
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: AiwaTextField(
                  label: l.svcPrice,
                  controller: _price,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: AiwaTextField(
                  label: l.svcDuration,
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          Row(
            spacing: 7,
            children: [
              AiwaChip(
                label: l.svcFixedPrice,
                active: _fixed,
                onTap: () => setState(() => _fixed = true),
              ),
              AiwaChip(
                label: l.svcStartsAt,
                active: !_fixed,
                onTap: () => setState(() => _fixed = false),
              ),
            ],
          ),
          if (_error != null)
            InlineBanner(tone: BannerTone.danger, body: _error),
          Row(
            spacing: 10,
            children: [
              if (id != null)
                Expanded(
                  child: AiwaButton(
                    label: l.svcHide,
                    variant: AiwaButtonVariant.secondary,
                    size: AiwaButtonSize.lg,
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => repo.hideService(id),
                            l.svcHiddenToast,
                          ),
                  ),
                ),
              Expanded(
                child: AiwaButton(
                  label: l.commonSave,
                  size: AiwaButtonSize.lg,
                  loading: _busy,
                  onPressed: _valid && !_busy
                      ? () => _run(
                          () => repo.saveService(
                            id: id,
                            name: _name.text.trim(),
                            price: num.parse(_price.text),
                            durationMinutes: int.parse(_duration.text),
                            fixed: _fixed,
                          ),
                          l.svcSavedToast,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
