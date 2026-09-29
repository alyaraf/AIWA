import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_avatar.dart';
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
import 'provider_schedule_page.dart' show WeekList, hhmm, weekDays;
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _palettes = [AvatarPalette.rose, AvatarPalette.gold, AvatarPalette.plum];

/// Staff & availability (shop plan) — `StaffManagementScreen`
/// (flow-additions-v4.jsx:19-80).
class ProviderStaffPage extends StatefulWidget {
  const ProviderStaffPage({super.key});

  @override
  State<ProviderStaffPage> createState() => _ProviderStaffPageState();
}

class _ProviderStaffPageState extends State<ProviderStaffPage> {
  final _repo = sl<ProviderManageRepository>();
  Json? _d;
  String? _error;
  Object? _openId;

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
      r.fold((_) {}, (d) {
        final firstLoad = _d == null;
        _d = d;
        final staff = d['staffMembers'] as List? ?? const [];
        if (firstLoad && staff.isNotEmpty) {
          _openId = (staff.first as Json)['id'];
        }
      });
    });
  }

  Future<void> _add([Json? s]) async {
    final ok = await showAiwaSheet<bool>(
      context,
      builder: (_) =>
          _StaffForm(s: s, services: _d?['services'] as List? ?? const []),
    );
    if (ok == true) _load();
  }

  Future<void> _editSchedule(Json s) async {
    await showAiwaSheet<void>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EyebrowLabel(AppLocalizations.of(ctx).schedEyebrow),
          const SizedBox(height: 2),
          Text(
            AppLocalizations.of(ctx).staffNameSchedule('${s['fullName']}'),
            style: AppTextStyles.h3,
          ),
          const SizedBox(height: 14),
          Flexible(
            child: SingleChildScrollView(
              child: WeekList(
                availabilities: _d?['availabilities'] as List?,
                staffMemberId: s['id'],
              ),
            ),
          ),
        ],
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final staff = [
      for (final s in _d?['staffMembers'] as List? ?? const [])
        if ((s as Json)['active'] != false) s,
    ];
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bone,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          ScreenHeader(
            eyebrow: l.staffShopPlan,
            title: l.staffTitle,
            onBack: () => context.pop(),
            trailing: AiwaButton(
              label: l.commonAdd,
              icon: LucideIcons.plus,
              size: AiwaButtonSize.sm,
              onPressed: _add,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gutter,
              18,
              AppTheme.gutter,
              0,
            ),
            child: _d == null
                ? (_error != null
                      ? ErrorState(body: _error!, onRetry: _load, compact: true)
                      : const SkeletonList())
                : staff.isEmpty
                ? EmptyState(
                    icon: LucideIcons.users,
                    title: l.staffEmpty,
                    subtitle: l.staffEmptyBody,
                    actionLabel: l.commonAdd,
                    onAction: _add,
                    compact: true,
                  )
                : Column(
                    spacing: 10,
                    children: [
                      for (final (i, s) in staff.indexed)
                        _StaffCard(
                          s: s,
                          palette: _palettes[i % _palettes.length],
                          availabilities:
                              _d!['availabilities'] as List? ?? const [],
                          services: _d!['services'] as List? ?? const [],
                          open: _openId == s['id'],
                          onToggle: () => setState(
                            () => _openId = _openId == s['id'] ? null : s['id'],
                          ),
                          onEdit: () => _editSchedule(s),
                          onEditDetails: () => _add(s),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final Json s;
  final AvatarPalette palette;
  final List availabilities;

  /// ProviderDetailDto.services; this member's are StaffMemberDto.serviceIds
  /// (empty = performs every service).
  final List services;
  final bool open;
  final VoidCallback onToggle, onEdit, onEditDetails;

  const _StaffCard({
    required this.s,
    required this.palette,
    required this.availabilities,
    required this.services,
    required this.open,
    required this.onToggle,
    required this.onEdit,
    required this.onEditDetails,
  });

  @override
  Widget build(BuildContext context) {
    final name = '${s['fullName']}';
    final l = AppLocalizations.of(context);
    final skills = [
      for (final k in '${s['skills'] ?? ''}'.split(','))
        if (k.trim().isNotEmpty) k.trim(),
    ];
    final week = {
      for (final a in availabilities)
        if ((a as Json)['staffMemberId'] == s['id']) '${a['dayOfWeek']}': a,
    };
    final ids = {for (final id in s['serviceIds'] as List? ?? const []) '$id'};
    final performs = [
      for (final v in services)
        if (ids.isEmpty || ids.contains('${(v as Json)['id']}')) v as Json,
    ];
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                spacing: 12,
                children: [
                  AiwaAvatar(
                    name: name,
                    size: 44,
                    palette: palette,
                    verified: true,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: AppTextStyles.h3.copyWith(
                            fontSize: 17,
                            height: 1.1,
                            color: AppColors.plum900,
                          ),
                        ),
                        if (s['title'] != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${s['title']}',
                            style: AppTextStyles.micro.copyWith(fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    open ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 18,
                    color: AppColors.ink3,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: AppTheme.dur2,
            curve: AppTheme.easeSoft,
            alignment: Alignment.topCenter,
            child: !open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (skills.isNotEmpty) ...[
                          EyebrowLabel(l.staffSkills),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final k in skills) AiwaChip(label: k),
                            ],
                          ),
                          const SizedBox(height: 14),
                        ],
                        if (performs.isNotEmpty) ...[
                          EyebrowLabel(l.providerTabServices),
                          const SizedBox(height: 6),
                          for (final v in performs)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${v['name']}',
                                      style: AppTextStyles.label.copyWith(
                                        fontSize: AppTextStyles.fsMetaPlus,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    l.egp((v['price'] as num? ?? 0).toDouble()),
                                    style: AppTextStyles.label.copyWith(
                                      fontSize: AppTextStyles.fsMetaPlus,
                                      color: AppColors.plum700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 14),
                        ],
                        EyebrowLabel(l.schedEyebrow),
                        const SizedBox(height: 6),
                        for (final (i, day) in weekDays.indexed)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 44,
                                  child: Text(
                                    l.weekdayShort(i),
                                    style: AppTextStyles.label.copyWith(
                                      fontSize: AppTextStyles.fsLabelSmPlus,
                                      color: week[day]?['available'] == true
                                          ? AppColors.ink
                                          : AppColors.ink4,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  week[day]?['available'] == true
                                      ? '${hhmm(week[day]!['startTime'])} – ${hhmm(week[day]!['endTime'])}'
                                      : l.staffOff,
                                  style: AppTextStyles.mono.copyWith(
                                    fontSize: AppTextStyles.fsLabelSmPlus,
                                    color: week[day]?['available'] == true
                                        ? AppColors.ink2
                                        : AppColors.ink4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        AiwaButton(
                          label: l.staffEditSchedule(name),
                          icon: LucideIcons.pencil,
                          variant: AiwaButtonVariant.secondary,
                          size: AiwaButtonSize.sm,
                          fullWidth: true,
                          onPressed: onEdit,
                        ),
                        const SizedBox(height: 8),
                        AiwaButton(
                          label: l.staffEditDetails,
                          icon: LucideIcons.userPen,
                          variant: AiwaButtonVariant.ghost,
                          size: AiwaButtonSize.sm,
                          fullWidth: true,
                          onPressed: onEditDetails,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Add (POST /provider/staff, [s] null) or edit (PUT /provider/staff/{id}):
/// name, role, skills, the services they do and deactivate (FE-23).
class _StaffForm extends StatefulWidget {
  final Json? s;

  /// ProviderDetailDto.services, for the "does these services" chips.
  final List services;

  const _StaffForm({this.s, required this.services});

  @override
  State<_StaffForm> createState() => _StaffFormState();
}

class _StaffFormState extends State<_StaffForm> {
  late final _name = TextEditingController(text: widget.s?['fullName']);
  late final _title = TextEditingController(text: widget.s?['title']);
  late final _skills = TextEditingController(text: widget.s?['skills']);

  /// Empty = performs every service (StaffMemberDto.serviceIds).
  late final Set<String> _serviceIds = {
    for (final id in widget.s?['serviceIds'] as List? ?? const []) '$id',
  };
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _title.dispose();
    _skills.dispose();
    super.dispose();
  }

  String? _text(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save({bool active = true}) async {
    setState(() => _busy = true);
    final repo = sl<ProviderManageRepository>();
    final s = widget.s;
    final r = s == null
        ? await repo.addStaff(
            fullName: _name.text.trim(),
            title: _text(_title),
            skills: _text(_skills),
          )
        : await repo.updateStaff('${s['id']}', {
            'fullName': _name.text.trim(),
            'title': _text(_title),
            'phone': s['phone'],
            'skills': _text(_skills) ?? '',
            'active': active,
            'serviceIds': [for (final id in _serviceIds) int.parse(id)],
          });
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    r.fold(
      (f) => setState(() {
        _busy = false;
        _error = l.error(f.message);
      }),
      (_) {
        showAiwaToast(
          context,
          s == null
              ? l.staffAdded
              : active
              ? l.staffSaved
              : l.staffDeactivated,
        );
        Navigator.pop(context, true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final editing = widget.s != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EyebrowLabel(l.staffShopPlan),
                      const SizedBox(height: 2),
                      Text(
                        editing ? l.staffEditDetails : l.provBizAddStaff,
                        style: AppTextStyles.h3,
                      ),
                    ],
                  ),
                ),
                AiwaIconButton(
                  icon: LucideIcons.x,
                  size: 34,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
            AiwaTextField(
              label: l.svcName,
              controller: _name,
              onChanged: (_) => setState(() {}),
            ),
            AiwaTextField(
              label: l.staffRole,
              controller: _title,
              optional: true,
            ),
            AiwaTextField(
              label: l.staffSkills,
              controller: _skills,
              optional: true,
              hint: l.staffSkillsHint,
            ),
            if (editing && widget.services.isNotEmpty) ...[
              EyebrowLabel(l.staffServicesHint),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final v in widget.services)
                    AiwaChip(
                      label: '${(v as Json)['name']}',
                      active: _serviceIds.contains('${v['id']}'),
                      onTap: () => setState(() {
                        final id = '${v['id']}';
                        if (!_serviceIds.remove(id)) _serviceIds.add(id);
                      }),
                    ),
                ],
              ),
            ],
            if (_error != null)
              InlineBanner(tone: BannerTone.danger, body: _error),
            AiwaButton(
              label: editing ? l.commonSave : l.commonAdd,
              size: AiwaButtonSize.lg,
              fullWidth: true,
              loading: _busy,
              onPressed: _name.text.trim().isNotEmpty && !_busy ? _save : null,
            ),
            if (editing)
              AiwaButton(
                label: l.staffDeactivate,
                icon: LucideIcons.userRoundMinus,
                variant: AiwaButtonVariant.ghost,
                fullWidth: true,
                onPressed: _busy ? null : () => _save(active: false),
              ),
          ],
        ),
      ),
    );
  }
}
