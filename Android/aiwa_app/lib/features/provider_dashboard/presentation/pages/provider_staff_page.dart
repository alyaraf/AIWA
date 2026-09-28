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

  Future<void> _add() async {
    final ok = await showAiwaSheet<bool>(
      context,
      builder: (_) => const _AddStaff(),
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
              icon: Icons.add_rounded,
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
                    icon: Icons.group_outlined,
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
                          open: _openId == s['id'],
                          onToggle: () => setState(
                            () => _openId = _openId == s['id'] ? null : s['id'],
                          ),
                          onEdit: () => _editSchedule(s),
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
  final bool open;
  final VoidCallback onToggle, onEdit;

  const _StaffCard({
    required this.s,
    required this.palette,
    required this.availabilities,
    required this.open,
    required this.onToggle,
    required this.onEdit,
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
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(18),
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
                    open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
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
                        // BACKEND GAP: no staff↔service link, so the
                        // prototype's 'Services & pricing' list is omitted.
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
                                      fontSize: 12.5,
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
                                    fontSize: 12.5,
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
                          icon: Icons.edit_outlined,
                          variant: AiwaButtonVariant.secondary,
                          size: AiwaButtonSize.sm,
                          fullWidth: true,
                          onPressed: onEdit,
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

/// POST /provider/staff — the prototype's 'Add' has no form, so this is
/// StaffMemberRequest's minimum.
class _AddStaff extends StatefulWidget {
  const _AddStaff();

  @override
  State<_AddStaff> createState() => _AddStaffState();
}

class _AddStaffState extends State<_AddStaff> {
  final _name = TextEditingController();
  final _title = TextEditingController();
  final _skills = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _title.dispose();
    _skills.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final r = await sl<ProviderManageRepository>().addStaff(
      fullName: _name.text.trim(),
      title: _title.text.trim().isEmpty ? null : _title.text.trim(),
      skills: _skills.text.trim().isEmpty ? null : _skills.text.trim(),
    );
    if (!mounted) return;
    r.fold(
      (f) => setState(() {
        _busy = false;
        _error = AppLocalizations.of(context).error(f.message);
      }),
      (_) {
        showAiwaToast(context, AppLocalizations.of(context).staffAdded);
        Navigator.pop(context, true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
                    Text(l.provBizAddStaff, style: AppTextStyles.h3),
                  ],
                ),
              ),
              AiwaIconButton(
                icon: Icons.close_rounded,
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
          AiwaTextField(label: l.staffRole, controller: _title, optional: true),
          AiwaTextField(
            label: l.staffSkills,
            controller: _skills,
            optional: true,
            hint: l.staffSkillsHint,
          ),
          if (_error != null)
            InlineBanner(tone: BannerTone.danger, body: _error),
          AiwaButton(
            label: l.commonAdd,
            size: AiwaButtonSize.lg,
            fullWidth: true,
            loading: _busy,
            onPressed: _name.text.trim().isNotEmpty && !_busy ? _save : null,
          ),
        ],
      ),
    );
  }
}
