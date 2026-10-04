import 'package:aiwa_app/features/home/domain/repositories/home_repository.dart';
import 'package:aiwa_app/features/providers/domain/repositories/provider_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_avatar.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_icon_button.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/system_screen.dart' show PopIn;
import '../../../home/domain/entities/provider_summary_entity.dart';
import '../../../home/presentation/widgets/provider_card.dart' show RatingMeta;
import '../../domain/entities/booking_entity.dart';
import '../bloc/live_booking_cubit.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Centered terminal: icon circle, eyebrow, serif title, body, CTAs.
/// Expired booking (system-screens.jsx:189-215) and the travel-fee
/// decline (flow-screens.jsx:265-281).
class OutcomeScreen extends StatelessWidget {
  final IconData icon;
  final Color bg, fg;
  final Color? eyebrowColor;
  final String eyebrow, title, body;
  final double titleSize;
  final VoidCallback? onBack;
  final Widget? extra;
  final List<Widget> actions;

  const OutcomeScreen({
    super.key,
    required this.icon,
    required this.bg,
    required this.fg,
    this.eyebrowColor,
    required this.eyebrow,
    required this.title,
    required this.body,
    this.titleSize = 27,
    this.onBack,
    this.extra,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: AppColors.bone,
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          insets.top + 26,
          24,
          insets.bottom + 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (onBack != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: AiwaIconButton(
                  icon: LucideIcons.arrowLeftDir,
                  onTap: onBack,
                ),
              ),
            const Spacer(),
            Center(
              child: PopIn(
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                  child: Icon(icon, size: 29, color: fg),
                ),
              ),
            ),
            const SizedBox(height: 18),
            EyebrowLabel(
              eyebrow,
              color: eyebrowColor,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 7),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.h1.copyWith(
                fontSize: titleSize,
                height: 1.1,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 9),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 285),
                child: Text(
                  body,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.ink2,
                    height: 1.6,
                  ),
                ),
              ),
            ),
            if (extra != null) ...[const SizedBox(height: 22), extra!],
            const Spacer(),
            ...actions,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOOK-33 — Expired booking
// ─────────────────────────────────────────────────────────────

class ExpiredBookingPage extends StatelessWidget {
  final String bookingId;
  final BookingEntity? booking;
  const ExpiredBookingPage({super.key, required this.bookingId, this.booking});

  @override
  Widget build(BuildContext context) => LiveBookingScope(
    bookingId: bookingId,
    booking: booking,
    child: BlocBuilder<LiveBookingCubit, LiveBookingState>(
      builder: (context, s) {
        final b = s.booking;
        final l = AppLocalizations.of(context);
        return OutcomeScreen(
          icon: LucideIcons.hourglass,
          bg: AppColors.warn100,
          fg: AppColors.warn700,
          eyebrowColor: AppColors.warn700,
          eyebrow: l.outcomeExpiredEyebrow,
          title: l.outcomeExpiredTitle,
          body: l.outcomeExpiredBody(
            b?.displayProviderName ?? l.outcomeTheProvider,
          ),
          onBack: () => context.pop(),
          // The kit's "Three providers nearby are free" banner was dropped:
          // no count backs it (FE-29).
          actions: [
            AiwaButton(
              label: l.outcomeSeeAlternatives,
              icon: LucideIcons.search,
              size: AiwaButtonSize.lg,
              fullWidth: true,
              onPressed: () => context.go(
                Uri(
                  path: AppRoutes.search,
                  queryParameters: {'category': ?b?.providerCategory},
                ).toString(),
              ),
            ),
            const SizedBox(height: 9),
            AiwaButton(
              label: l.outcomeBackToBookings,
              variant: AiwaButtonVariant.ghost,
              size: AiwaButtonSize.sm,
              fullWidth: true,
              onPressed: () => context.go(AppRoutes.myBookings),
            ),
          ],
        );
      },
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// BOOK-32 — Rejected: reason + alternatives
// ─────────────────────────────────────────────────────────────

/// Slots are (days from today, start); labels are formatted in the widget.
typedef _Extras = ({
  List<(int, DateTime)> slots,
  List<ProviderSummaryEntity> alts,
  bool similar,
});

/// Next 3 free slots (today, then tomorrow) for the same service, and
/// providers near the original one — same category first.
Future<_Extras> _loadExtras(BookingEntity b) async {
  final slots = <(int, DateTime)>[];
  final now = DateTime.now();
  for (final i in const [0, 1]) {
    if (slots.length >= 3) break;
    final d = DateTime(now.year, now.month, now.day + i);
    final r = await sl<ProviderRepository>().getAvailableSlots(
      b.providerId,
      b.serviceId,
      DateFormat('yyyy-MM-dd').format(d),
    );
    for (final s in r.getOrElse(() => const [])) {
      for (final t in s.times) {
        final at = DateTime.tryParse(
          '${DateFormat('yyyy-MM-dd').format(d)} ${t.length == 5 ? '$t:00' : t}',
        );
        if (at == null || at.isBefore(now) || slots.length >= 3) continue;
        slots.add((i, at));
      }
    }
  }

  var alts = <ProviderSummaryEntity>[];
  var similar = false;
  final lat = b.providerLat, lng = b.providerLng;
  if (lat != null && lng != null) {
    Future<List<ProviderSummaryEntity>> near(String? category) async =>
        (await sl<HomeRepository>().getNearbyProviders(
          lat: lat,
          lng: lng,
          category: category,
          size: 5,
        )).fold(
          (_) => const <ProviderSummaryEntity>[],
          (p) => p.content
              .where((x) => x.id.toString() != b.providerId)
              .take(4)
              .toList(),
        );
    alts = await near(b.providerCategory);
    similar = alts.isNotEmpty;
    if (!similar) alts = await near(null);
  }
  return (slots: slots, alts: alts, similar: similar);
}

class RejectedPage extends StatelessWidget {
  final String bookingId;
  final BookingEntity? booking;
  const RejectedPage({super.key, required this.bookingId, this.booking});

  @override
  Widget build(BuildContext context) => LiveBookingScope(
    bookingId: bookingId,
    booking: booking,
    child: const _RejectedView(),
  );
}

class _RejectedView extends StatefulWidget {
  const _RejectedView();

  @override
  State<_RejectedView> createState() => _RejectedViewState();
}

class _RejectedViewState extends State<_RejectedView> {
  Future<_Extras>? _extras;

  /// Back lands on the Bookings tab (prototype.jsx:716).
  void _back() => context.go(AppRoutes.myBookings);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveBookingCubit, LiveBookingState>(
      builder: (context, s) {
        final b = s.booking;
        final l = AppLocalizations.of(context);
        if (b == null) {
          return Scaffold(
            backgroundColor: AppColors.bone,
            body: Column(
              children: [
                ScreenHeader(
                  eyebrow: l.rejectedEyebrow,
                  eyebrowColor: AppColors.rose700,
                  title: l.rejectedTitleGeneric,
                  onBack: _back,
                ),
                const Padding(
                  padding: EdgeInsets.all(AppTheme.gutter),
                  child: SkeletonList(count: 2),
                ),
              ],
            ),
          );
        }
        _extras ??= _loadExtras(b);
        final name = b.displayProviderName;
        final first = name.split(' ').first;
        void toProvider() => context.push('/provider/${b.providerId}');
        return Scaffold(
          backgroundColor: AppColors.bone,
          body: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              ScreenHeader(
                eyebrow: l.rejectedEyebrow,
                eyebrowColor: AppColors.rose700,
                title: l.rejectedTitle(name),
                onBack: _back,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.gutter,
                  16,
                  AppTheme.gutter,
                  0,
                ),
                child: FutureBuilder<_Extras>(
                  future: _extras,
                  builder: (context, snap) {
                    final x = snap.data;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (b.rejectionReason != null) ...[
                          _ReasonCard(first: first, reason: b.rejectionReason!),
                          const SizedBox(height: 18),
                        ],
                        _AnotherTimeCard(
                          first: first,
                          slots: x?.slots,
                          onTap: toProvider,
                        ),
                        const SizedBox(height: 26),
                        if (x == null)
                          const SkeletonList(count: 2)
                        else if (x.alts.isNotEmpty) ...[
                          SectionHeader(
                            title: x.similar
                                ? l.rejectedSimilar
                                : l.rejectedOtherNearby,
                            padding: EdgeInsets.zero,
                          ),
                          for (final p in x.alts) ...[
                            _AltRow(
                              provider: p,
                              onTap: () => context.push('/provider/${p.id}'),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReasonCard extends StatelessWidget {
  final String first, reason;
  const _ReasonCard({required this.first, required this.reason});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger100,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(AppTheme.radius10),
            ),
            child: Icon(LucideIcons.x, size: 16, color: AppColors.danger700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).rejectedReasonFrom(first),
                  style: AppTextStyles.label.copyWith(
                    fontSize: AppTextStyles.fsMetaPlus,
                    height: 1.3,
                    color: AppColors.danger700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  AppLocalizations.of(context).commonQuoted(reason),
                  style: AppTextStyles.meta.copyWith(
                    height: 1.5,
                    color: AppColors.ink2,
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

class _AnotherTimeCard extends StatelessWidget {
  final String first;

  /// (days from today, start); null while loading.
  final List<(int, DateTime)>? slots;
  final VoidCallback onTap;
  const _AnotherTimeCard({
    required this.first,
    required this.slots,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.plum100,
                  borderRadius: BorderRadius.circular(AppTheme.radius10),
                ),
                child: Icon(
                  LucideIcons.calendarClock,
                  size: 17,
                  color: AppColors.plum700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).rejectedBookAnother(first),
                      style: AppTextStyles.label.copyWith(
                        fontSize: 14.5,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context).rejectedNextSlots,
                      style: AppTextStyles.micro.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (slots == null || slots!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: slots == null
                        ? const ShimmerBox(height: 52, radius: 12)
                        : i < slots!.length
                        ? _SlotButton(slot: slots![i], onTap: onTap)
                        : const SizedBox(),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 12),
          AiwaButton(
            label: AppLocalizations.of(context).rejectedSeeAllTimes,
            icon: LucideIcons.calendar,
            fullWidth: true,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

class _SlotButton extends StatelessWidget {
  final (int, DateTime) slot;
  final VoidCallback onTap;
  const _SlotButton({required this.slot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.bone,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Text(
              slot.$1 == 0
                  ? AppLocalizations.of(context).commonToday
                  : AppLocalizations.of(context).commonTomorrow,
              style: AppTextStyles.micro,
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat(
                'h:mm a',
                Localizations.localeOf(context).toString(),
              ).format(slot.$2),
              style: AppTextStyles.bodySm.copyWith(
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: AppColors.plum700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AltRow extends StatelessWidget {
  final ProviderSummaryEntity provider;
  final VoidCallback onTap;
  const _AltRow({required this.provider, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = provider;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(AppTheme.radius16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            AiwaAvatar(
              name: p.businessName,
              size: 48,
              imageUrl: p.profileImageUrl,
              verified: p.isVerified,
              palette: AvatarPalette.values[p.id.abs() % 4],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.businessName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h4.copyWith(fontSize: 17, height: 1.1),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.of(context).category(p.primaryCategory),
                    style: AppTextStyles.micro.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: RatingMeta(
                      rating: p.averageRating,
                      distance: AppLocalizations.of(
                        context,
                      ).distance(p.distanceKm),
                      openNow: p.openNow,
                      gap: 8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AiwaButton(
              label: AppLocalizations.of(context).commonBook,
              variant: AiwaButtonVariant.secondary,
              size: AiwaButtonSize.sm,
              onPressed: onTap,
            ),
          ],
        ),
      ),
    );
  }
}
