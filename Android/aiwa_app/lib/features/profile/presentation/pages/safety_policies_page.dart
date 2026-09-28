import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import 'package:aiwa_app/l10n/l10n.dart';

/// `POLICY_DOCS` in account-screens.jsx.
List<(String, IconData, String, String?)> _docs(AppLocalizations l) => [
  ('terms', Icons.description_outlined, l.polTerms, null),
  ('safety', Icons.verified_user_outlined, l.polSafety, l.polSafetySub),
  ('cancel', Icons.event_busy_outlined, l.polCancel, l.polCancelSub),
  ('privacy', Icons.lock_outline_rounded, l.polPrivacy, l.polPrivacySub),
  ('conduct', Icons.handshake_outlined, l.polConduct, l.polConductSub),
];

/// Safety & policies — `SafetyPoliciesScreen` in account-screens.jsx.
class SafetyPoliciesPage extends StatefulWidget {
  const SafetyPoliciesPage({super.key});

  @override
  State<SafetyPoliciesPage> createState() => _SafetyPoliciesPageState();
}

class _SafetyPoliciesPageState extends State<SafetyPoliciesPage> {
  String? _open;
  ({String version, String content})? _terms;

  @override
  void initState() {
    super.initState();
    sl<AuthRepository>().latestTerms('CUSTOMER_TERMS').then((r) {
      if (mounted) r.fold((_) {}, (t) => setState(() => _terms = t));
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final accepted = auth is AuthAuthenticated
        ? auth.user.acceptedTermsVersion
        : null;
    final upToDate =
        accepted != null && (_terms == null || _terms!.version == accepted);
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bone,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          ScreenHeader(
            eyebrow: l.editAccount,
            title: l.ppSafety,
            onBack: () => context.pop(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gutter,
              14,
              AppTheme.gutter,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                upToDate
                    ? InlineBanner(
                        tone: BannerTone.success,
                        icon: Icons.check_circle_outline_rounded,
                        title: l.polUpToDate,
                        // Backend gap: UserDto has no termsAcceptedAt, so the
                        // date the prototype shows is replaced by the version.
                        body: l.polUpToDateBody(accepted),
                      )
                    : InlineBanner(
                        tone: BannerTone.warn,
                        title: l.polUpdated,
                        action: l.polReview,
                        onAction: () => context.push(AppRoutes.termsReaccept),
                      ),
                const SizedBox(height: 16),
                for (final (id, icon, title, sub) in _docs(l))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SettingsRow(
                          icon: icon,
                          label: title,
                          sub:
                              sub ??
                              (accepted != null
                                  ? l.polAccepted(accepted)
                                  : l.polNotAccepted),
                          boxed: true,
                          onTap: () =>
                              setState(() => _open = _open == id ? null : id),
                          right: Icon(
                            _open == id
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 17,
                            color: AppColors.ink4,
                          ),
                        ),
                        AnimatedSize(
                          duration: AppTheme.dur2,
                          curve: AppTheme.easeSoft,
                          alignment: Alignment.topCenter,
                          child: _open == id
                              ? _PolicyPanel(
                                  text: id == 'terms' && _terms != null
                                      ? _terms!.content
                                      : l.polPlaceholder(title),
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SectionHeader(title: l.polSafetyTools),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
            child: Column(
              spacing: 9,
              children: [
                SettingsRow(
                  icon: Icons.person_add_alt_outlined,
                  label: l.profTrustedContacts,
                  sub: l.polTrustedSub,
                  boxed: true,
                  gold: true,
                  onTap: () => context.push(AppRoutes.trustedContacts),
                ),
                // The prototype gives "How SOS works" no destination.
                SettingsRow(
                  icon: Icons.emergency_outlined,
                  label: l.polHowSos,
                  sub: l.polHowSosSub,
                  boxed: true,
                  gold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyPanel extends StatelessWidget {
  final String text;
  const _PolicyPanel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 7),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: AppTextStyles.micro.copyWith(
              fontSize: 12.5,
              color: AppColors.ink2,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 10),
          // Backend gap: TermsPolicyDto carries no PDF link, so this stays
          // disabled (the prototype wires no handler either).
          AiwaButton(
            label: AppLocalizations.of(context).polDownloadPdf,
            variant: AiwaButtonVariant.ghost,
            size: AiwaButtonSize.sm,
            icon: Icons.download_rounded,
            onPressed: null,
          ),
        ],
      ),
    );
  }
}
