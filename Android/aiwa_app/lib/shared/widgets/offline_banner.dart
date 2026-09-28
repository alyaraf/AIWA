import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Top bar shown while offline — `OfflineBanner` in states.jsx. Mounted once
/// above every route in app.dart; driven by connectivity_plus and by
/// connection errors from [ApiClient].
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _offline = false;
  final _subs = <StreamSubscription<dynamic>>[];

  static bool _none(List<ConnectivityResult> r) =>
      r.every((c) => c == ConnectivityResult.none);

  @override
  void initState() {
    super.initState();
    _subs.add(ApiClient.offline.stream.listen(_set));
    try {
      _subs.add(
        Connectivity().onConnectivityChanged.listen(
          (r) => _set(_none(r)),
          onError: (_) {},
        ),
      );
    } catch (_) {} // no plugin (tests / unsupported platform)
  }

  void _set(bool offline) {
    if (mounted && offline != _offline) setState(() => _offline = offline);
  }

  // ponytail: re-checks connectivity only; screens refetch via their own pull/Try again. Re-dispatch page loads here if Retry should refetch.
  Future<void> _retry() async {
    try {
      _set(_none(await Connectivity().checkConnectivity()));
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const drop = AppTheme.dur3;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !_offline,
        child: AnimatedSlide(
          offset: _offline ? Offset.zero : const Offset(0, -.2),
          duration: drop,
          curve: AppTheme.easeSoft,
          child: AnimatedOpacity(
            opacity: _offline ? 1 : 0,
            duration: drop,
            curve: AppTheme.easeSoft,
            child: Material(
              color: AppColors.plum900,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  MediaQuery.paddingOf(context).top + 8,
                  18,
                  11,
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.wifiOff,
                      size: 15,
                      color: AppColors.rose300,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).offlineBanner,
                        style: AppTextStyles.micro.copyWith(
                          fontSize: AppTextStyles.fsLabelSmPlus,
                          fontWeight: FontWeight.w500,
                          color: AppColors.bone,
                        ),
                      ),
                    ),
                    Semantics(
                      button: true,
                      child: GestureDetector(
                        onTap: _retry,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.bone.withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusPill,
                            ),
                          ),
                          child: Text(
                            AppLocalizations.of(context).commonRetry,
                            style: AppTextStyles.labelSm.copyWith(
                              fontSize: AppTextStyles.fsMicroPlus,
                              fontWeight: FontWeight.w700,
                              color: AppColors.bone,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
