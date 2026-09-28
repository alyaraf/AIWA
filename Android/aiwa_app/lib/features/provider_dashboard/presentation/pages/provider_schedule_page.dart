import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_toggle.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../data/provider_manage_repository.dart';
import 'package:aiwa_app/l10n/l10n.dart';

/// Backend DayOfWeek names in the prototype's Sun-first order; labels come
/// from [AiwaL10n.weekdayShort].
const weekDays = [
  'SUNDAY',
  'MONDAY',
  'TUESDAY',
  'WEDNESDAY',
  'THURSDAY',
  'FRIDAY',
  'SATURDAY',
];

/// "10:00:00" -> "10:00".
String hhmm(Object? t) => '$t'.length >= 5 ? '$t'.substring(0, 5) : '$t';

/// Schedule tab — `ProviderSchedule` (provider-screens.jsx:435-474).
class ProviderSchedulePage extends StatefulWidget {
  const ProviderSchedulePage({super.key});

  @override
  State<ProviderSchedulePage> createState() => _ProviderSchedulePageState();
}

class _ProviderSchedulePageState extends State<ProviderSchedulePage> {
  final _repo = sl<ProviderManageRepository>();
  Json? _detail;
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
      _detail = r.fold((_) => _detail, (d) => d);
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bone,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          PageTitle(eyebrow: l.schedEyebrow, title: l.tabSchedule),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gutter,
              14,
              AppTheme.gutter,
              0,
            ),
            child: d == null
                ? (_error != null
                      ? ErrorState(body: _error!, onRetry: _load, compact: true)
                      : const SkeletonList(count: 4))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      WeekList(availabilities: d['availabilities'] as List?),
                      const SizedBox(height: 16),
                      _TravelBuffer(detail: d),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.plum100,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text.rich(
                          TextSpan(
                            children: spansOf(l.schedTip('{tip}'), {
                              'tip': TextSpan(
                                text: l.schedTipLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            }),
                          ),
                          style: AppTextStyles.micro.copyWith(
                            fontSize: 12,
                            color: AppColors.plum700,
                            height: 1.5,
                          ),
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

/// Seven day rows with open/closed toggles. [staffMemberId] scopes it to one
/// staff member (shop plan); null is the provider's own week.
class WeekList extends StatefulWidget {
  final List? availabilities;
  final Object? staffMemberId;
  const WeekList({super.key, this.availabilities, this.staffMemberId});

  @override
  State<WeekList> createState() => _WeekListState();
}

class _WeekListState extends State<WeekList> {
  late final Map<String, Json> _days = {
    for (final a in widget.availabilities ?? const [])
      if ((a as Json)['staffMemberId'] == widget.staffMemberId)
        '${a['dayOfWeek']}': a,
  };
  String? _error;

  bool _open(String day) => _days[day]?['available'] == true;

  Future<void> _toggle(String day) async {
    final prev = _days[day];
    final next = {
      'dayOfWeek': day,
      // ponytail: new days open 10:00–20:00; per-day hours editing is only
      // hinted in the prototype's tip copy.
      'startTime': prev?['startTime'] ?? '10:00',
      'endTime': prev?['endTime'] ?? '20:00',
      'available': !_open(day),
    };
    setState(() {
      _days[day] = {...?prev, ...next};
      _error = null;
    });
    final r = await sl<ProviderManageRepository>().saveDay(
      dayOfWeek: day,
      startTime: hhmm(next['startTime']),
      endTime: hhmm(next['endTime']),
      available: next['available'] as bool,
      staffMemberId: widget.staffMemberId,
    );
    if (!mounted) return;
    r.fold(
      (f) => setState(() {
        prev == null ? _days.remove(day) : _days[day] = prev;
        _error = AppLocalizations.of(context).error(f.message);
      }),
      (saved) => setState(() => _days[day] = saved),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        if (_error != null) InlineBanner(tone: BannerTone.danger, body: _error),
        for (final (i, day) in weekDays.indexed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              spacing: 12,
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    l.weekdayShort(i).toUpperCase(),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.label.copyWith(
                      fontSize: 13,
                      letterSpacing: 0.78,
                      color: _open(day) ? AppColors.plum900 : AppColors.ink4,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    _open(day)
                        ? '${hhmm(_days[day]!['startTime'])} – ${hhmm(_days[day]!['endTime'])}'
                        : l.schedClosed,
                    style: AppTextStyles.mono.copyWith(
                      fontSize: 14,
                      color: _open(day) ? AppColors.ink : AppColors.ink4,
                    ),
                  ),
                ),
                AiwaToggle(value: _open(day), onChanged: (_) => _toggle(day)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Travel buffer stepper (provider-screens.jsx:460-471): 0–60, step 5,
/// saved to PUT /provider/profile travelBufferMinutes after a short pause.
class _TravelBuffer extends StatefulWidget {
  final Json detail;
  const _TravelBuffer({required this.detail});

  @override
  State<_TravelBuffer> createState() => _TravelBufferState();
}

class _TravelBufferState extends State<_TravelBuffer> {
  late int _v = widget.detail['travelBufferMinutes'] as int? ?? 15;
  Timer? _debounce;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _step(int delta) {
    final v = (_v + delta).clamp(0, 60);
    if (v == _v) return;
    setState(() {
      _v = v;
      _error = null;
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final r = await sl<ProviderManageRepository>().updateProfile({
        ...widget.detail,
        'travelBufferMinutes': v,
      });
      if (mounted) {
        setState(
          () => _error = r.fold(
            (f) => AppLocalizations.of(context).error(f.message),
            (_) => null,
          ),
        );
      }
    });
  }

  Widget _btn(String label, int delta) => Semantics(
    button: true,
    label: delta < 0
        ? AppLocalizations.of(context).schedDecrease
        : AppLocalizations.of(context).schedIncrease,
    child: InkWell(
      onTap: () => _step(delta),
      customBorder: const CircleBorder(),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.paper,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(color: AppColors.plum700),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.plum100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.directions_car_outlined,
                  size: 17,
                  color: AppColors.plum700,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).schedBufferTitle,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      AppLocalizations.of(context).schedBufferBody,
                      style: AppTextStyles.micro.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _btn('−', -5),
              SizedBox(
                width: 60,
                child: Text(
                  AppLocalizations.of(context).durationMinutes(_v),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.mono.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.plum900,
                  ),
                ),
              ),
              _btn('+', 5),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          InlineBanner(tone: BannerTone.danger, body: _error),
        ],
      ],
    );
  }
}
