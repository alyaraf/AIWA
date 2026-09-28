import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/aiwa_icon_button.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../providers/presentation/bloc/provider_bloc.dart';
import '../../../providers/presentation/bloc/provider_event.dart';
import '../../../providers/presentation/bloc/provider_state.dart';
import '../widgets/book_now_check_sheet.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';

/// BookingTypeScreen (flow-screens.jsx:162-221): Book now vs Schedule.
class BookingTypePage extends StatefulWidget {
  final String providerId;
  final String? serviceId;
  final String? staffId;

  const BookingTypePage({
    super.key,
    required this.providerId,
    this.serviceId,
    this.staffId,
  });

  @override
  State<BookingTypePage> createState() => _BookingTypePageState();
}

class _BookingTypePageState extends State<BookingTypePage> {
  late final ProviderBloc _bloc = sl<ProviderBloc>()
    ..add(ProviderLoadEvent(widget.providerId));

  void _toBooking(String mode) => context.push(
    Uri(
      path: '/booking/${widget.providerId}',
      queryParameters: {
        'mode': mode,
        'serviceId': ?widget.serviceId,
        'staffId': ?widget.staffId,
      },
    ).toString(),
  );

  Future<void> _bookNow() async {
    final s = _bloc.state;
    if (s is! ProviderLoaded) return;
    final choice = await showBookNowCheckSheet(
      context,
      provider: s.provider,
      serviceId: widget.serviceId,
    );
    if (!mounted) return;
    switch (choice) {
      case BookNowChoice.now:
        _toBooking('now');
      case BookNowChoice.schedule:
        _toBooking('scheduled');
      case BookNowChoice.alternatives:
        context.go(AppRoutes.search);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final insets = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: AppColors.bone,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          insets.top + 14,
          24,
          insets.bottom + 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AiwaIconButton(
              icon: LucideIcons.arrowLeftDir,
              onTap: () => context.pop(),
            ),
            const SizedBox(height: 22),
            EyebrowLabel(l.bookingTypeEyebrow),
            const SizedBox(height: 6),
            Text(
              l.bookingTypeTitle,
              style: AppTextStyles.h1.copyWith(
                fontSize: 30,
                height: 1.05,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 8),
            BlocBuilder<ProviderBloc, ProviderState>(
              bloc: _bloc,
              builder: (_, s) => s is ProviderLoaded
                  ? Text(
                      l.bookingTypeAccepts(s.provider.displayName),
                      style: AppTextStyles.body.copyWith(
                        fontSize: 14,
                        height: 1.55,
                        color: AppColors.ink2,
                      ),
                    )
                  : const ShimmerBox(width: 260, height: 18),
            ),
            const SizedBox(height: 24),
            _TypeCard(
              dark: true,
              eyebrow: l.bookingTypeNowEyebrow,
              title: l.bookingTypeNowTitle,
              facts: [
                (LucideIcons.clock, l.bookingTypeNowEta),
                (LucideIcons.mapPin, l.bookingTypeNowComes),
              ],
              onTap: _bookNow,
            ),
            const SizedBox(height: 12),
            _TypeCard(
              dark: false,
              eyebrow: l.bookingTypeScheduleEyebrow,
              title: l.bookingTypeScheduleTitle,
              facts: [
                (LucideIcons.calendar, l.bookingTypeUpTo14),
                (LucideIcons.circleCheck, l.bookingTypeProviderConfirms),
              ],
              onTap: () => _toBooking('scheduled'),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(AppTheme.radius14),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      LucideIcons.info,
                      size: 16,
                      color: AppColors.plum700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: spansOf(l.bookingTypeCashNote('{cash}'), {
                          'cash': TextSpan(
                            text: l.bookingCashOnVisit,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        }),
                      ),
                      style: AppTextStyles.body.copyWith(
                        fontSize: AppTextStyles.fsLabelSmPlus,
                        height: 1.5,
                        color: AppColors.ink2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final bool dark;
  final String eyebrow;
  final String title;
  final List<(IconData, String)> facts;
  final VoidCallback onTap;

  const _TypeCard({
    required this.dark,
    required this.eyebrow,
    required this.title,
    required this.facts,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = dark ? AppColors.bone : AppColors.ink2;
    // Full width: the page Column is start-aligned, which would otherwise
    // shrink-wrap each card to its (shorter, Arabic) copy.
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: dark ? AppColors.plum700 : AppColors.paper,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius22),
          side: dark
              ? BorderSide.none
              : BorderSide(color: AppColors.divider, width: 1.5),
        ),
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              if (dark)
                PositionedDirectional(
                  end: -30,
                  top: -30,
                  child: AiwaGlow(
                    size: 140,
                    color: AppColors.bone,
                    opacity: .15,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EyebrowLabel(
                      eyebrow,
                      color: dark ? AppColors.rose300 : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: AppTextStyles.h1.copyWith(
                        fontSize: 26,
                        height: 1.1,
                        letterSpacing: 0,
                        color: dark ? AppColors.bone : AppColors.plum900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 18,
                      runSpacing: 6,
                      children: [
                        for (final (icon, text) in facts)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 14, color: fg),
                              const SizedBox(width: 5),
                              Text(
                                text,
                                style: AppTextStyles.body.copyWith(
                                  fontSize: 13,
                                  color: fg,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
