import 'package:aiwa_app/features/providers/domain/repositories/provider_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/repositories/booking_repository.dart' show SosReport;
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_avatar.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_icon_button.dart';
import '../../../../shared/widgets/aiwa_toast.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/reason_sheet.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../../shared/widgets/slot_conflict_sheet.dart';
import '../../domain/entities/booking_entity.dart';
import '../bloc/live_booking_cubit.dart';
import 'booking_outcome_pages.dart' show OutcomeScreen;
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

typedef _Step = ({String status, IconData icon, String label, String hint});

/// STATUS_STEPS (flow-screens.jsx:226-233), keyed by backend BookingStatus.
List<_Step> _steps(AppLocalizations l) => [
  (
    status: 'PENDING',
    icon: LucideIcons.hourglass,
    label: l.statusPending,
    hint: l.trackPendingHint,
  ),
  (
    status: 'ACCEPTED',
    icon: LucideIcons.circleCheck,
    label: l.statusAccepted,
    hint: l.trackAcceptedHint,
  ),
  (
    status: 'ON_THE_WAY',
    icon: LucideIcons.navigation,
    label: l.statusOnTheWay,
    hint: l.trackOnTheWayHint,
  ),
  (
    status: 'ARRIVED',
    icon: LucideIcons.mapPin,
    label: l.statusArrived,
    hint: l.trackArrivedHint,
  ),
  (
    status: 'IN_PROGRESS',
    icon: LucideIcons.sparkles,
    label: l.statusInProgress,
    hint: l.trackInProgressHint,
  ),
  (
    status: 'COMPLETED',
    icon: LucideIcons.badgeCheck,
    label: l.statusCompleted,
    hint: l.trackCompletedHint,
  ),
];

String _waitingOn(AppLocalizations l, String status) => switch (status) {
  'PENDING' => l.trackWaitPending,
  'ACCEPTED' => l.trackWaitAccepted,
  'ON_THE_WAY' => l.trackWaitOnTheWay,
  'ARRIVED' => l.trackWaitArrived,
  'IN_PROGRESS' => l.trackWaitInProgress,
  _ => l.trackUpdatesAuto,
};

List<String> cancelReasons(AppLocalizations l) => [
  l.cancelReasonMind,
  l.cancelReasonOther,
  l.cancelReasonWrong,
  l.cancelReasonPrice,
  l.cancelReasonUnresponsive,
  l.cancelReasonElse,
];

/// BOOK-15..28 — one screen driven by the booking status.
class TrackingPage extends StatelessWidget {
  final String bookingId;
  final BookingEntity? booking;
  const TrackingPage({super.key, required this.bookingId, this.booking});

  @override
  Widget build(BuildContext context) => LiveBookingScope(
    bookingId: bookingId,
    booking: booking,
    poll: true,
    child: const _TrackingView(),
  );
}

class _TrackingView extends StatefulWidget {
  const _TrackingView();

  @override
  State<_TrackingView> createState() => _TrackingViewState();
}

class _TrackingViewState extends State<_TrackingView> {
  bool _proposalOpened = false;

  LiveBookingCubit get _cubit => context.read<LiveBookingCubit>();

  @override
  void initState() {
    super.initState();
    // The listener only sees changes; the seeded booking may already be
    // rejected / expired / carrying a proposal.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onChange(context, _cubit.state);
    });
  }

  /// Back from Tracking lands on the Bookings tab (prototype.jsx:694).
  void _back() => context.go(AppRoutes.myBookings);

  Future<void> _push(String path, BookingEntity b) async {
    await context.push(path, extra: b);
    if (mounted) _cubit.load();
  }

  Future<void> _cancel() async {
    final r = await showReasonSheet(
      context,
      eyebrow: AppLocalizations.of(context).trackCancelEyebrow,
      title: AppLocalizations.of(context).trackCancelTitle,
      reasons: cancelReasons(AppLocalizations.of(context)),
      otherLabel: AppLocalizations.of(context).cancelReasonElse,
    );
    if (r == null || !mounted) return;
    // The cancel endpoint takes one `reason`; the optional note rides along.
    final sent = r.note.isEmpty ? r.reason : '${r.reason}: ${r.note}';
    if (await _cubit.cancel(sent) && mounted) {
      showAiwaToast(
        context,
        AppLocalizations.of(context).trackCancelledToast(r.reason),
      );
      _back();
    }
  }

  /// Date picker, then the free times that day (FE-37).
  Future<void> _reschedule(BookingEntity b) async {
    final l = AppLocalizations.of(context);
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date == null || !mounted) return;
    final day = DateFormat('yyyy-MM-dd').format(date);
    final r = await sl<ProviderRepository>().getAvailableSlots(b.providerId, b.serviceId, day);
    if (!mounted) return;
    final times = r.fold(
      (_) => const <String>[],
      (slots) => [
        for (final s in slots)
          if (DateFormat('yyyy-MM-dd').format(s.date) == day) ...s.times,
      ],
    );
    if (times.isEmpty) {
      showAiwaToast(context, l.rescheduleNoSlots);
      return;
    }
    final locale = Localizations.localeOf(context).toString();
    String label(String t) => DateFormat('h:mm a', locale)
        .format(DateFormat('HH:mm').parse(t.substring(0, 5)));
    final time = await showSlotConflictSheet(
      context,
      providerName: b.displayProviderName,
      alternatives: times,
      labelOf: label,
      eyebrow: l.trackReschedule,
      title: l.rescheduleTitle,
      body: l.rescheduleBody(
        b.displayProviderName,
        DateFormat.MMMEd(locale).format(date),
      ),
    );
    if (time == null || !mounted) return;
    if (await _cubit.reschedule(day, time) && mounted) {
      showAiwaToast(context, l.rescheduledToast(label(time)));
    }
  }

  Future<void> _call() async {
    final n = await _cubit.maskedPhone();
    if (n != null) await launchUrl(Uri(scheme: 'tel', path: n));
  }

  /// Status changes that leave Tracking, and a provider's proposed time.
  void _onChange(BuildContext context, LiveBookingState s) {
    final b = s.booking;
    if (b == null) return;
    final id = b.id;
    switch (b.status) {
      case 'REJECTED':
        context.pushReplacement('/booking/$id/rejected', extra: b);
      case 'EXPIRED':
        context.pushReplacement('/booking/$id/expired', extra: b);
      case 'PENDING' when b.hasProposal && !_proposalOpened:
        _proposalOpened = true;
        _push('/booking/$id/proposed-time', b);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LiveBookingCubit, LiveBookingState>(
      listenWhen: (a, b) =>
          a.booking?.status != b.booking?.status ||
          a.booking?.hasProposal != b.booking?.hasProposal,
      listener: _onChange,
      builder: (context, s) {
        final b = s.booking;
        if (b == null) {
          return Scaffold(
            backgroundColor: AppColors.bone,
            body: s.loadError != null
                ? ErrorState(
                    body: AppLocalizations.of(context).error(s.loadError!),
                    onRetry: _cubit.load,
                  )
                : const Padding(
                    padding: EdgeInsets.fromLTRB(22, 80, 22, 0),
                    child: SkeletonList(count: 3),
                  ),
          );
        }
        if (s.declinedFee) {
          return _declinedFee(context, b.travelFeeQuote ?? b.travelFee ?? 0);
        }
        return Scaffold(
          backgroundColor: AppColors.bone,
          body: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(status: b.status, onBack: _back),
                // Everything below overlaps the header by 20 (margin -20).
                Transform.translate(
                  offset: const Offset(0, -20),
                  child: _body(b, s),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _body(BookingEntity b, LiveBookingState s) {
    final st = b.status;
    final done = st == 'COMPLETED';
    final onSite = const {'ON_THE_WAY', 'ARRIVED', 'IN_PROGRESS'}.contains(st);
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProviderCard(
            booking: b,
            onCall: _call,
            onChat: () => _push('/booking/${b.id}/chat', b),
          ),
          // CR-09 / AU-17 (owner rule 2026-10-04): venue visits get SOS too, once started.
          if ((b.homeService && onSite) || (!b.homeService && st == 'IN_PROGRESS')) ...[
            const SizedBox(height: 14),
            // After "I'm safe" (logged) a second emergency can be raised.
            _SafetyCard(
              onSos: s.sos == SosStage.none || s.sos == SosStage.logged
                  ? _cubit.sos
                  : null,
            ),
            if (s.sosFailed) ...[
              const SizedBox(height: 10),
              InlineBanner(
                tone: BannerTone.danger,
                body: l.trackSosFailed,
                action: l.commonRetry,
                onAction: _cubit.sos,
              ),
            ],
          ],
          if (s.sos != SosStage.none) ...[
            const SizedBox(height: 10),
            _SosBanner(stage: s.sos, report: s.sosReport, onSafe: _cubit.imSafe),
          ],
          if (!b.homeService &&
              const {'ACCEPTED', 'ON_THE_WAY', 'ARRIVED'}.contains(st)) ...[
            const SizedBox(height: 14),
            _CheckInCard(
              booking: b,
              busy: s.busy,
              onCheckIn: b.checkedInAt == null ? _cubit.checkIn : null,
            ),
          ],
          const SizedBox(height: 22),
          EyebrowLabel(l.trackStatusTimeline),
          const SizedBox(height: 14),
          _Timeline(status: st),
          if (done && !b.paymentSettled) ...[
            const SizedBox(height: 6),
            _PaymentRow(
              booking: b,
              onConfirm: () => _push('/booking/${b.id}/payment', b),
            ),
          ],
          // The provider quoted a travel fee for this booking and waits for an answer.
          if (b.hasPendingTravelQuote) ...[
            const SizedBox(height: 14),
            _TravelFeeQuote(
              booking: b,
              busy: s.busy,
              onDecline: () => _cubit.respondToTravelFee(false),
              onAccept: () => _cubit.respondToTravelFee(true),
            ),
          ],
          if (!b.hasPendingTravelQuote && (b.travelFee ?? 0) > 0) ...[
            const SizedBox(height: 14),
            _TotalRow(booking: b),
          ],
          if (s.actionError != null) ...[
            const SizedBox(height: 14),
            InlineBanner(
              tone: BannerTone.danger,
              body: l.error(s.actionError!),
            ),
          ],
          const SizedBox(height: 22),
          if (b.canCancel) ...[
            AiwaButton(
              label: l.trackCancelBooking,
              icon: LucideIcons.x,
              variant: AiwaButtonVariant.secondary,
              fullWidth: true,
              loading: s.busy,
              onPressed: _cancel,
            ),
            const SizedBox(height: 10),
            AiwaButton(
              label: l.trackReschedule,
              icon: LucideIcons.calendarClock,
              variant: AiwaButtonVariant.secondary,
              fullWidth: true,
              loading: s.busy,
              onPressed: () => _reschedule(b),
            ),
            const SizedBox(height: 10),
          ],
          if (done && !b.reviewed) ...[
            AiwaButton(
              label: l.bookingsLeaveReview,
              icon: LucideIcons.star,
              fullWidth: true,
              onPressed: () => _push('/review/${b.id}', b),
            ),
            const SizedBox(height: 10),
          ],
          AiwaButton(
            label: l.trackReportProblem,
            icon: LucideIcons.flag,
            variant: AiwaButtonVariant.ghost,
            fullWidth: true,
            onPressed: () => _push('/booking/${b.id}/complaint', b),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String status;
  final VoidCallback onBack;
  const _Header({required this.status, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final steps = _steps(l);
    final i = steps.indexWhere((x) => x.status == status);
    final cur = steps[i < 0 ? 0 : i];
    final glass = Colors.white;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppTheme.gutter,
        MediaQuery.paddingOf(context).top + 14,
        AppTheme.gutter,
        28,
      ),
      decoration: BoxDecoration(
        // linear-gradient(160deg, plum700, plum900)
        gradient: LinearGradient(
          begin: const Alignment(-.34, -1),
          end: const Alignment(.34, 1),
          colors: [AppColors.plum700, AppColors.plum900],
        ),
      ),
      foregroundDecoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(.4, -.4),
          radius: .9,
          colors: [glass.withValues(alpha: .08), glass.withValues(alpha: 0)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AiwaIconButton(
                icon: LucideIcons.arrowLeftDir,
                variant: AiwaIconButtonVariant.glass,
                onTap: onBack,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EyebrowLabel(l.trackTracking, color: AppColors.rose300),
                    const SizedBox(height: 2),
                    Text(
                      cur.label,
                      style: AppTextStyles.h3.copyWith(
                        fontSize: 22,
                        height: 1.05,
                        letterSpacing: 0,
                        color: AppColors.bone,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: glass.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: glass.withValues(alpha: .18)),
            ),
            child: Row(
              children: [
                Pulse(
                  active: status == 'IN_PROGRESS',
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.bone,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(cur.icon, size: 26, color: AppColors.plum900),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cur.label,
                        style: AppTextStyles.h4.copyWith(
                          fontSize: 19,
                          height: 1.1,
                          color: AppColors.bone,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cur.hint,
                        style: AppTextStyles.micro.copyWith(
                          fontSize: AppTextStyles.fsLabelSmPlus,
                          height: 1.45,
                          color: AppColors.rose300,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.radio, size: 12, color: AppColors.rose300),
              const SizedBox(width: 5),
              Text(
                _waitingOn(l, status),
                style: AppTextStyles.micro.copyWith(
                  fontSize: AppTextStyles.fsMicroPlus,
                  color: AppColors.rose300,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// `aiwa-pulse` 1.6s: scale 1 -> 1.05 and back.
class Pulse extends StatefulWidget {
  final Widget child;
  final bool active;
  const Pulse({super.key, required this.child, this.active = true});

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(Pulse old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.active && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.active) {
      _c.value = 0;
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: Tween(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
    child: widget.child,
  );
}

class _ProviderCard extends StatelessWidget {
  final BookingEntity booking;
  final VoidCallback onCall;
  final VoidCallback onChat;
  const _ProviderCard({
    required this.booking,
    required this.onCall,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          AiwaAvatar(
            name: b.displayProviderName,
            size: 48,
            imageUrl: b.providerImageUrl,
            verified: b.providerVerified,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.displayProviderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h4.copyWith(fontSize: 17, height: 1.1),
                ),
                const SizedBox(height: 2),
                Text(
                  '${bidiIsolate(b.serviceName)} · ${AppLocalizations.of(context).formatWhen(b.scheduledDate, b.scheduledTime)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.micro.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AiwaIconButton(icon: LucideIcons.phone, size: 36, onTap: onCall),
          const SizedBox(width: 8),
          AiwaIconButton(
            icon: LucideIcons.messageCircle,
            size: 36,
            onTap: onChat,
          ),
        ],
      ),
    );
  }
}

/// Icon tile + title + sub, used by the safety and check-in cards.
class _TileHead extends StatelessWidget {
  final IconData icon;
  final Color bg, fg;
  final String title, sub;
  const _TileHead({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.title,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppTheme.radius10),
        ),
        child: Icon(icon, size: 16, color: fg),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.label.copyWith(
                fontSize: AppTextStyles.fsMetaPlus,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              sub,
              style: AppTextStyles.micro.copyWith(
                fontSize: AppTextStyles.fsMicroPlus,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

BoxDecoration get _card => BoxDecoration(
  color: AppColors.paper,
  borderRadius: BorderRadius.circular(AppTheme.radius16),
  border: Border.all(color: AppColors.divider),
);

/// SOS for either side of a live booking (AU-17: providers get it too). Needs a
/// [LiveBookingScope] above it; shows the button, a retry banner and the delivery report.
class SosSection extends StatelessWidget {
  const SosSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BlocBuilder<LiveBookingCubit, LiveBookingState>(
      builder: (context, s) {
        final cubit = context.read<LiveBookingCubit>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SafetyCard(
              onSos: s.sos == SosStage.none || s.sos == SosStage.logged ? cubit.sos : null,
            ),
            if (s.sosFailed) ...[
              const SizedBox(height: 10),
              InlineBanner(
                tone: BannerTone.danger,
                body: l.trackSosFailed,
                action: l.commonRetry,
                onAction: cubit.sos,
              ),
            ],
            if (s.sos != SosStage.none) ...[
              const SizedBox(height: 10),
              _SosBanner(stage: s.sos, report: s.sosReport, onSafe: cubit.imSafe),
            ],
          ],
        );
      },
    );
  }
}

class _SafetyCard extends StatelessWidget {
  final VoidCallback? onSos;
  const _SafetyCard({required this.onSos});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Describes what SOS really does (SafetyService); no live location
          // or ID check exists, so the kit's claim is not shown (FE-29).
          _TileHead(
            icon: LucideIcons.shieldCheck,
            bg: AppColors.success100,
            fg: AppColors.success700,
            title: AppLocalizations.of(context).trackSafetyTitle,
            sub: AppLocalizations.of(context).trackSafetySub,
          ),
          const SizedBox(height: 12),
          Material(
            color: AppColors.danger100,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              onTap: onSos,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.siren,
                      size: 16,
                      color: AppColors.danger700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context).trackSos,
                      style: AppTextStyles.label.copyWith(
                        fontSize: AppTextStyles.fsMetaPlus,
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SosBanner extends StatelessWidget {
  final SosStage stage;
  final SosReport? report;
  final VoidCallback onSafe;
  const _SosBanner({required this.stage, this.report, required this.onSafe});

  /// Only what the delivery records show (R2-03).
  static String detail(AppLocalizations l, SosReport? r) {
    if (r == null) return '';
    final parts = <String>[
      if (r.contactsPending > 0) l.trackSosTexting,
      if (r.contactsTexted > 0) l.trackSosTexted(r.contactsTexted),
      if (r.contactsFailed > 0) l.trackSosTextFailed(r.contactsFailed),
      if (r.contactsPending + r.contactsTexted + r.contactsFailed == 0) l.trackSosNoContacts,
    ];
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg) = switch (stage) {
      SosStage.alerting => (
        AppColors.danger100,
        AppColors.danger500.withValues(alpha: .4),
        AppColors.danger700,
      ),
      SosStage.notified => (
        AppColors.warn100,
        AppColors.warn500.withValues(alpha: .4),
        AppColors.warn700,
      ),
      _ => (AppColors.plum100, AppColors.divider, AppColors.plum700),
    };
    final style = AppTextStyles.micro.copyWith(
      fontSize: AppTextStyles.fsLabelSmPlus,
      height: 1.45,
      color: fg,
    );
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radius14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          switch (stage) {
            // No spinners: the loader pulses.
            SosStage.alerting => Pulse(
              child: Icon(LucideIcons.refreshCw, size: 18, color: fg),
            ),
            SosStage.notified => Icon(
              LucideIcons.shieldAlert,
              size: 18,
              color: fg,
            ),
            _ => Icon(LucideIcons.fileCheck, size: 18, color: fg),
          },
          const SizedBox(width: 10),
          Expanded(
            child: switch (stage) {
              SosStage.alerting => Text(l.trackSosAlerting, style: style),
              SosStage.notified => Text.rich(
                TextSpan(
                  style: style,
                  children: spansOf(l.trackSosNotified('{bold}', detail(l, report)), {
                    'bold': TextSpan(
                      text: report?.supportAlerted == false
                          ? l.trackSosRecordedBold
                          : l.trackSosNotifiedBold,
                      style: style.copyWith(fontWeight: FontWeight.w700),
                    ),
                  }),
                ),
              ),
              _ => Text(l.trackSosLogged, style: style),
            },
          ),
          if (stage == SosStage.notified)
            GestureDetector(
              onTap: onSafe,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: Text(
                  l.trackImSafe,
                  style: style.copyWith(
                    fontSize: AppTextStyles.fsMicroPlus,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CheckInCard extends StatelessWidget {
  final BookingEntity booking;
  final bool busy;
  final VoidCallback? onCheckIn;
  const _CheckInCard({
    required this.booking,
    required this.busy,
    required this.onCheckIn,
  });

  @override
  Widget build(BuildContext context) {
    final checkedIn = booking.checkedInAt != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _card,
      child: Row(
        children: [
          Expanded(
            child: _TileHead(
              icon: LucideIcons.mapPinCheck,
              bg: AppColors.plum100,
              fg: AppColors.plum700,
              title: AppLocalizations.of(context).trackCheckInTitle,
              sub: AppLocalizations.of(
                context,
              ).trackCheckInSub(booking.displayProviderName),
            ),
          ),
          const SizedBox(width: 12),
          AiwaButton(
            label: checkedIn
                ? AppLocalizations.of(context).trackCheckedIn
                : AppLocalizations.of(context).trackCheckIn,
            icon: checkedIn ? LucideIcons.check : null,
            variant: AiwaButtonVariant.secondary,
            size: AiwaButtonSize.sm,
            loading: busy && !checkedIn,
            onPressed: onCheckIn,
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final String status;
  const _Timeline({required this.status});

  @override
  Widget build(BuildContext context) {
    final steps = _steps(AppLocalizations.of(context));
    final at = steps.indexWhere((s) => s.status == status);
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _stepRow(steps[i], i < at, i == at, i > at, i < steps.length - 1),
      ],
    );
  }

  Widget _stepRow(_Step s, bool done, bool active, bool upcoming, bool line) {
    final on = done || active;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: AppTheme.dur2,
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? AppColors.plum700
                      : done
                      ? AppColors.plum100
                      : AppColors.paper,
                  border: Border.all(
                    color: on ? AppColors.plum700 : AppColors.divider,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  done ? LucideIcons.check : s.icon,
                  size: done ? 14 : 13,
                  color: active
                      ? AppColors.bone
                      : done
                      ? AppColors.plum700
                      : AppColors.ink4,
                ),
              ),
              if (line)
                Expanded(
                  child: Container(
                    width: 2,
                    constraints: const BoxConstraints(minHeight: 26),
                    color: done ? AppColors.plum700 : AppColors.divider,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.label,
                    style: AppTextStyles.bodySm.copyWith(
                      height: 1.2,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                      color: on ? AppColors.ink : AppColors.ink4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.hint,
                    style: AppTextStyles.micro.copyWith(
                      fontSize: 12,
                      height: 1.45,
                      color: upcoming ? AppColors.ink4 : AppColors.ink3,
                    ),
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

class _PaymentRow extends StatelessWidget {
  final BookingEntity booking;
  final VoidCallback onConfirm;
  const _PaymentRow({required this.booking, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.plum100,
        borderRadius: BorderRadius.circular(AppTheme.radius14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(AppTheme.radius10),
            ),
            child: Icon(
              LucideIcons.banknote,
              size: 18,
              color: AppColors.plum700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).trackConfirmCash,
                  style: AppTextStyles.label.copyWith(
                    fontSize: 14,
                    height: 1.3,
                    color: AppColors.plum900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppLocalizations.of(context).trackDueTo(
                    AppLocalizations.of(context).egp(booking.servicePrice),
                    booking.displayProviderName,
                  ),
                  style: AppTextStyles.micro.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          AiwaButton(
            label: AppLocalizations.of(context).commonConfirm,
            variant: AiwaButtonVariant.secondary,
            size: AiwaButtonSize.sm,
            onPressed: onConfirm,
          ),
        ],
      ),
    );
  }
}

class _TravelFeeQuote extends StatelessWidget {
  final BookingEntity booking;
  final bool busy;
  final VoidCallback onDecline;
  final VoidCallback onAccept;
  const _TravelFeeQuote({
    required this.booking,
    required this.busy,
    required this.onDecline,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final fee = booking.travelFeeQuote ?? booking.travelFee ?? 0;
    final base = booking.basePrice;
    final sub = AppTextStyles.micro.copyWith(
      fontSize: AppTextStyles.fsLabelSmPlus,
      height: 1.5,
    );
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.gold500, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.gold100,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(
                  LucideIcons.car,
                  size: 19,
                  color: AppColors.gold700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.trackFeeWants(booking.displayProviderName, l.egp(fee)),
                      style: AppTextStyles.bodySm.copyWith(
                        fontSize: 14.5,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text.rich(
                      TextSpan(
                        style: sub,
                        children: spansOf(
                          l.trackFeeTotal(l.egp(base), l.egp(fee), '{total}'),
                          {
                            'total': TextSpan(
                              text: l.egp(base + fee),
                              style: sub.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink2,
                              ),
                            ),
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AiwaButton(
                  label: l.commonDecline,
                  variant: AiwaButtonVariant.secondary,
                  size: AiwaButtonSize.sm,
                  fullWidth: true,
                  onPressed: busy ? null : onDecline,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AiwaButton(
                  label: l.trackAcceptConfirm,
                  icon: LucideIcons.check,
                  size: AiwaButtonSize.sm,
                  fullWidth: true,
                  onPressed: busy ? null : onAccept,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final BookingEntity booking;
  const _TotalRow({required this.booking});

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.meta.copyWith(fontSize: 13);
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppTheme.radius14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l.trackServicePlusTravel(
                l.egp(booking.basePrice),
                l.egp(booking.travelFee!),
              ),
              style: style,
            ),
          ),
          Text(
            l.trackTotalAmount(l.egp(booking.servicePrice)),
            style: style.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.plum900,
            ),
          ),
        ],
      ),
    );
  }
}

/// BOOK-28 — after declining the travel fee.
Widget _declinedFee(BuildContext context, double fee) => OutcomeScreen(
  icon: LucideIcons.calendarX,
  bg: AppColors.cream,
  fg: AppColors.ink3,
  eyebrow: AppLocalizations.of(context).trackDeclinedEyebrow,
  title: AppLocalizations.of(context).trackDeclinedTitle,
  titleSize: 26,
  body: AppLocalizations.of(
    context,
  ).trackDeclinedBody(AppLocalizations.of(context).egp(fee)),
  actions: [
    AiwaButton(
      label: AppLocalizations.of(context).trackFindAnother,
      icon: LucideIcons.search,
      size: AiwaButtonSize.lg,
      fullWidth: true,
      onPressed: () => context.go(AppRoutes.myBookings),
    ),
  ],
);
