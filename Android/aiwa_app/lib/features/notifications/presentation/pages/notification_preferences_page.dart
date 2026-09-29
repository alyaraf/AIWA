import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_toggle.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../profile/data/account_repository.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// `NOTIF_CHANNELS` in flow-additions-v3.jsx → NotificationPreferencesDto key.
List<(String, String, IconData)> _channels(AppLocalizations l) => [
  ('notifyPush', l.npPush, LucideIcons.bell),
  ('notifySms', l.npSms, LucideIcons.messageSquare),
  ('notifyWhatsapp', l.providerWhatsApp, LucideIcons.messageCircle),
  ('notifyEmail', l.authModeEmail, LucideIcons.mail),
];

/// "22:00:00", "22:00" or [22, 0] → "22:00".
String? hhmm(Object? v) => switch (v) {
  final String s when s.length >= 5 => s.substring(0, 5),
  [final int h, final int m, ...] =>
    '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
  _ => null,
};

/// Notification preferences — `NotificationPreferencesScreen`.
class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  State<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends State<NotificationPreferencesPage> {
  final _repo = sl<AccountRepository>();
  Map<String, dynamic>? _prefs;
  String? _loadError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    final r = await _repo.notificationPreferences();
    if (!mounted) return;
    setState(
      () => r.fold(
        (f) => _loadError = AppLocalizations.of(context).error(f.message),
        (p) => _prefs = p,
      ),
    );
  }

  bool get _quietOn => hhmm(_prefs?['quietHoursStart']) != null;

  /// Optimistic PATCH; reverts and shows the failure if it doesn't stick.
  Future<void> _patch(
    Map<String, dynamic> patch,
    Map<String, dynamic> local,
  ) async {
    final before = _prefs!;
    setState(() {
      _prefs = {...before, ...local};
      _error = null;
    });
    final r = await _repo.updateNotificationPreferences(patch);
    if (!mounted) return;
    setState(
      () => r.fold((f) {
        _prefs = before;
        _error = AppLocalizations.of(context).error(f.message);
      }, (p) => _prefs = p),
    );
  }

  void _toggleChannel(String key) {
    final v = !(_prefs![key] as bool? ?? false);
    _patch({key: v}, {key: v});
  }

  void _toggleQuiet(bool on) => on
      ? _patch(
          {'quietHoursStart': '22:00', 'quietHoursEnd': '08:00'},
          {'quietHoursStart': '22:00', 'quietHoursEnd': '08:00'},
        )
      : _patch(
          {'clearQuietHours': true},
          {'quietHoursStart': null, 'quietHoursEnd': null},
        );

  Future<void> _pickTime(String key) async {
    final cur = hhmm(_prefs![key])!.split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(cur[0]),
        minute: int.parse(cur[1]),
      ),
    );
    if (t == null) return;
    final v =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    _patch({key: v}, {key: v});
  }

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(AppTheme.radius14),
      border: Border.all(color: AppColors.divider),
    ),
    child: child,
  );

  Widget _rowLabel(String text) => Expanded(
    child: Text(
      text,
      style: AppTextStyles.body.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.ink,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = _prefs;
    const pad = EdgeInsets.symmetric(horizontal: AppTheme.gutter);
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bone,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          ScreenHeader(
            eyebrow: l.editAccount,
            title: l.profNotificationPrefs,
            onBack: () => context.pop(),
          ),
          if (p == null)
            Padding(
              padding: const EdgeInsets.all(AppTheme.gutter),
              child: _loadError != null
                  ? ErrorState(body: _loadError!, onRetry: _load, compact: true)
                  : const SkeletonList(count: 4),
            )
          else ...[
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.gutter,
                  14,
                  AppTheme.gutter,
                  0,
                ),
                child: InlineBanner(tone: BannerTone.danger, body: _error),
              ),
            SectionHeader(title: l.npChannels),
            Padding(
              padding: pad,
              child: Column(
                spacing: 8,
                children: [
                  for (final (key, label, icon) in _channels(l))
                    _card(
                      Row(
                        spacing: 12,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.plum100,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius10,
                              ),
                            ),
                            child: Icon(
                              icon,
                              size: 16,
                              color: AppColors.plum700,
                            ),
                          ),
                          _rowLabel(label),
                          AiwaToggle(
                            value: p[key] == true,
                            onChanged: (_) => _toggleChannel(key),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            SectionHeader(title: l.npQuietHours),
            Padding(
              padding: pad,
              child: Column(
                children: [
                  _card(
                    Row(
                      spacing: 12,
                      children: [
                        _rowLabel(l.npMute),
                        AiwaToggle(value: _quietOn, onChanged: _toggleQuiet),
                      ],
                    ),
                  ),
                  AnimatedSize(
                    duration: AppTheme.dur2,
                    curve: AppTheme.easeSoft,
                    alignment: Alignment.topCenter,
                    child: !_quietOn
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              spacing: 10,
                              children: [
                                for (final (key, label) in [
                                  ('quietHoursStart', l.npFrom),
                                  ('quietHoursEnd', l.npTo),
                                ])
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _pickTime(key),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.paper,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: AppColors.divider,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            EyebrowLabel(label, fontSize: 10),
                                            const SizedBox(height: 4),
                                            Text(
                                              hhmm(p[key]) ?? '--:--',
                                              style: AppTextStyles.mono
                                                  .copyWith(
                                                    fontSize: 15,
                                                    color: AppColors.ink,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
