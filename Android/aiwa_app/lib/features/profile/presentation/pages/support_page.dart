import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_toast.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../data/account_repository.dart';
import 'package:aiwa_app/l10n/l10n.dart';

/// "Talk to AIWA" — `WhatsAppSupportScreen` in customer-extras.jsx.
class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  /// SupportContactDto; null once loaded means no line is configured.
  Map<String, dynamic>? _contact;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    sl<AccountRepository>().supportContact().then((r) {
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _contact = r.fold((_) => null, (c) => c);
      });
    });
  }

  String? get _number {
    final n = (_contact?['whatsappNumber'] as String?)?.replaceAll(
      RegExp(r'\D'),
      '',
    );
    return n == null || n.isEmpty ? null : n;
  }

  Future<void> _openWhatsApp() async {
    showAiwaToast(context, AppLocalizations.of(context).supOpening);
    await launchUrl(
      Uri.parse('https://wa.me/$_number'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _contact;
    final l = AppLocalizations.of(context);
    final arHours = c?['availabilityHoursAr'] as String?;
    final rows = [
      (
        Icons.phone_outlined,
        l.supNumber,
        c?['whatsappNumberDisplay'] ?? c?['whatsappNumber'],
      ),
      (
        Icons.schedule_rounded,
        l.supHours,
        l.localeName == 'ar' && (arHours?.isNotEmpty ?? false)
            ? arHours
            : c?['availabilityHoursEn'],
      ),
      (Icons.mail_outline_rounded, l.supEmail, c?['supportEmail']),
      (Icons.language_rounded, l.supLanguages, 'العربية · English'),
    ];
    return Scaffold(
      backgroundColor: AppColors.bone,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          ScreenHeader(
            eyebrow: l.supEyebrow,
            title: l.supTitle,
            onBack: () => context.pop(),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(
              AppTheme.gutter,
              18,
              AppTheme.gutter,
              0,
            ),
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              gradient: AppTheme.heroGradient,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Stack(
              children: [
                PositionedDirectional(
                  end: -40,
                  top: -40,
                  child: AiwaGlow(size: 180, color: AppColors.rose300),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.bone,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 28,
                          color: AppColors.plum900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 260),
                        child: Text(
                          l.supHero,
                          style: AppTextStyles.h2.copyWith(
                            fontSize: 26,
                            height: 1.1,
                            letterSpacing: 0,
                            color: AppColors.bone,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: Text(
                          l.supHeroBody,
                          style: AppTextStyles.bodySm.copyWith(
                            fontSize: 13,
                            height: 1.55,
                            color: AppColors.rose300,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      AiwaButton(
                        label: l.supOpenWhatsApp,
                        variant: AiwaButtonVariant.accent,
                        size: AiwaButtonSize.lg,
                        icon: Icons.open_in_new_rounded,
                        onPressed: _number == null ? null : _openWhatsApp,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(
              AppTheme.gutter,
              22,
              AppTheme.gutter,
              0,
            ),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                for (final (i, (icon, label, value)) in rows.indexed)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: i < rows.length - 1
                          ? Border(bottom: BorderSide(color: AppColors.divider))
                          : null,
                    ),
                    child: Row(
                      spacing: 12,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.plum100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, size: 15, color: AppColors.plum700),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label.toUpperCase(),
                                style: AppTextStyles.micro.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: .88,
                                ),
                              ),
                              const SizedBox(height: 2),
                              if (value != null)
                                Text(
                                  '$value',
                                  style: AppTextStyles.body.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.ink,
                                  ),
                                )
                              else if (!_loaded)
                                const ShimmerBox(width: 120, height: 14)
                              else
                                Text(
                                  '—',
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.ink4,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
            child: EyebrowLabel(l.supCommonQuestions),
          ),
          const SizedBox(height: 10),
          // The prototype gives the FAQ rows no destination.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
            child: Column(
              spacing: 8,
              children: [
                for (final q in [
                  l.supQCancel,
                  l.supQPaid,
                  l.supQNoShow,
                  l.supQBecome,
                ])
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            q,
                            style: AppTextStyles.body.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppColors.ink3,
                        ),
                      ],
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
