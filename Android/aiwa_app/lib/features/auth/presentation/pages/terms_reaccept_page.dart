import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_toast.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../domain/repositories/auth_repository.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';

/// "We've updated our terms." — `TermsReacceptScreen` in
/// flow-additions-v3.jsx, opened from a TERMS notification.
class TermsReacceptPage extends StatefulWidget {
  const TermsReacceptPage({super.key});

  @override
  State<TermsReacceptPage> createState() => _TermsReacceptPageState();
}

class _TermsReacceptPageState extends State<TermsReacceptPage> {
  final _repo = sl<AuthRepository>();
  ({String version, String content})? _terms;

  /// Load error (shown in the terms box) or, once loaded, accept error.
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _repo.latestTerms('CUSTOMER_TERMS').then((r) {
      if (mounted) {
        setState(
          () => r.fold(
            (f) => _error = AppLocalizations.of(context).error(f.message),
            (t) => _terms = t,
          ),
        );
      }
    });
  }

  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await _repo.acceptTerms(_terms!.version);
    if (!mounted) return;
    setState(() => _busy = false);
    r.fold(
      (f) => setState(
        () => _error = AppLocalizations.of(context).error(f.message),
      ),
      (_) {
        showAiwaToast(context, AppLocalizations.of(context).authTermsAccepted);
        context.pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final boxStyle = AppTextStyles.bodySm.copyWith(
      fontSize: AppTextStyles.fsLabelSmPlus,
      color: AppColors.ink2,
      height: 1.5,
    );
    return Scaffold(
      backgroundColor: AppColors.bone,
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          insets.top + 26,
          24,
          insets.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EyebrowLabel(
              AppLocalizations.of(context).authPoliciesUpdated,
              color: AppColors.rose700,
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(context).authTermsUpdatedTitle,
              style: AppTextStyles.h1.copyWith(
                fontSize: 28,
                height: 1.08,
                letterSpacing: -0.56,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).authTermsUpdatedBody,
              style: AppTextStyles.bodySm.copyWith(
                fontSize: 14,
                color: AppColors.ink2,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 20),
            if (_terms == null && _error == null)
              const ShimmerBox(height: 76, radius: 14)
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(AppTheme.radius14),
                ),
                child: _terms == null
                    ? Text(_error!, style: boxStyle)
                    : Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: AppLocalizations.of(
                                context,
                              ).authTermsVersion(_terms!.version),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(text: ' — ${_terms!.content}'),
                          ],
                        ),
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                        style: boxStyle,
                      ),
              ),
            const Spacer(),
            if (_terms != null && _error != null) ...[
              InlineBanner(
                tone: BannerTone.danger,
                icon: LucideIcons.circleAlert,
                body: _error,
                compact: true,
              ),
              const SizedBox(height: 12),
            ],
            AiwaButton(
              label: AppLocalizations.of(context).authAgreeContinue,
              size: AiwaButtonSize.lg,
              fullWidth: true,
              loading: _busy,
              onPressed: _terms == null ? null : _accept,
            ),
          ],
        ),
      ),
    );
  }
}
