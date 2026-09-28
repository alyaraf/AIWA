import 'package:dartz/dartz.dart' hide State;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_avatar.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_icon_button.dart';
import '../../../../shared/widgets/aiwa_sheet.dart';
import '../../../../shared/widgets/aiwa_toast.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/reason_sheet.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../../../bookings/domain/repositories/booking_repository.dart';
import '../../domain/repositories/dashboard_repository.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

typedef _Next = ({
  String label,
  IconData icon,
  String note,
  Future<Either<Failure, BookingEntity>> Function(String id) call,
});

/// Provider booking detail — `ProviderBookingDetail`
/// (provider-screens.jsx:195-395). Pending: review & respond; accepted:
/// job progress + status-advance bar; terminal: read-only.
class ProviderBookingDetailPage extends StatefulWidget {
  final String bookingId;
  final BookingEntity? booking;

  const ProviderBookingDetailPage({
    super.key,
    required this.bookingId,
    this.booking,
  });

  @override
  State<ProviderBookingDetailPage> createState() =>
      _ProviderBookingDetailPageState();
}

class _ProviderBookingDetailPageState extends State<ProviderBookingDetailPage> {
  late BookingEntity? _b = widget.booking;
  String? _loadError;
  String? _error;
  bool _busy = false;

  /// Travel-fee quote sent and awaiting the customer.
  double? _quote;

  DashboardRepository get _repo => sl<DashboardRepository>();

  @override
  void initState() {
    super.initState();
    _load();
    // Pages pushed from here (payment, rate) change the booking too.
    providerBookingsChanged.addListener(_load);
  }

  @override
  void dispose() {
    providerBookingsChanged.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final r = await sl<BookingRepository>().getBookingDetail(widget.bookingId);
    if (!mounted) return;
    setState(
      () => r.fold(
        (f) => _loadError = AppLocalizations.of(context).error(f.message),
        (b) => _b = b,
      ),
    );
  }

  /// Runs [call], keeps the fresh booking; returns true on success.
  Future<bool> _act(
    Future<Either<Failure, BookingEntity>> Function() call, {
    String? toast,
    bool pop = false,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await call();
    if (!mounted) return false;
    return r.fold(
      (f) {
        setState(() {
          _busy = false;
          _error = AppLocalizations.of(context).error(f.message);
        });
        return false;
      },
      (b) {
        setState(() {
          _busy = false;
          _b = b;
        });
        providerBookingsChanged.value++;
        if (toast != null) showAiwaToast(context, toast);
        if (pop) context.pop();
        return true;
      },
    );
  }

  String get _id => widget.bookingId;

  Future<void> _propose() async {
    final b = _b!;
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: b.scheduledDateTime.isBefore(now)
          ? now
          : b.scheduledDateTime,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(b.scheduledDateTime),
    );
    if (time == null || !mounted) return;
    final hhmm =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    await _act(
      () => _repo.proposeTime(_id, DateFormat('yyyy-MM-dd').format(date), hhmm),
      toast: AppLocalizations.of(context).pbdAltTimeSent,
      pop: true,
    );
  }

  Future<void> _quoteFee() async {
    final b = _b!;
    final amount = await showAiwaSheet<double>(
      context,
      builder: (_) => _QuoteSheet(booking: b),
    );
    if (amount == null || !mounted) return;
    if (await _act(() => _repo.quoteTravelFee(_id, amount))) {
      setState(() => _quote = amount);
    }
  }

  Future<void> _cancel() async {
    final l = AppLocalizations.of(context);
    final r = await showReasonSheet(
      context,
      eyebrow: l.pbdCancelEyebrow,
      eyebrowColor: AppColors.danger700,
      title: l.pbdCancelTitle,
      warning: l.pbdCancelWarning,
      reasons: [
        l.pbdReasonEmergency,
        l.pbdReasonSick,
        l.pbdReasonOverbooked,
        l.pbdReasonUnreachable,
        l.flagReasonOther,
      ],
      otherLabel: null,
      confirmLabel: l.pbdCancelConfirm,
    );
    if (r == null || !mounted) return;
    await _act(
      () => sl<BookingRepository>().cancelBooking(_id, reason: r.reason),
      toast: l.pbdCancelledToast,
      pop: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = _b;
    final l = AppLocalizations.of(context);
    if (b == null) {
      return Scaffold(
        backgroundColor: AppColors.bone,
        body: _loadError != null
            ? ErrorState(body: _loadError!, onRetry: _load)
            : const Padding(
                padding: EdgeInsets.fromLTRB(22, 80, 22, 0),
                child: SkeletonList(count: 3),
              ),
      );
    }

    final steps = b.homeService
        ? [
            ('ACCEPTED', l.statusAccepted),
            ('ON_THE_WAY', l.statusOnTheWay),
            ('ARRIVED', l.statusArrived),
            ('IN_PROGRESS', l.statusInProgress),
          ]
        : [('ACCEPTED', l.statusAccepted), ('IN_PROGRESS', l.statusInProgress)];
    final stepIdx = steps.indexWhere((s) => s.$1 == b.status);
    final pending = b.status == 'PENDING';
    final customer = b.customerName ?? l.commonCustomer;
    final hasAddress = b.customerAddress?.isNotEmpty ?? false;

    Widget card({required Widget child, EdgeInsets? padding}) => Container(
      margin: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        14,
        AppTheme.gutter,
        0,
      ),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
    Widget banner(InlineBanner b) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        14,
        AppTheme.gutter,
        0,
      ),
      child: b,
    );

    return Scaffold(
      backgroundColor: AppColors.bone,
      bottomNavigationBar: pending
          ? _pendingBar(b, hasAddress)
          : stepIdx >= 0
          ? _progressBar(b)
          : null,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ScreenHeader(
            eyebrow: l.pbdEyebrow,
            title: l.pbdTitle,
            onBack: () => context.pop(),
            trailing: StatusPill(status: b.status),
          ),
          if (stepIdx >= 0)
            card(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: _JobProgress(
                labels: [for (final s in steps) s.$2],
                index: stepIdx,
              ),
            ),
          card(
            child: Row(
              children: [
                AiwaAvatar(name: customer, size: 54),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer,
                        style: AppTextStyles.h3.copyWith(
                          fontSize: 20,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // ponytail: every customer account is phone-OTP
                          // verified, so the badge is unconditional.
                          Icon(
                            LucideIcons.badgeCheck,
                            size: 12,
                            color: AppColors.gold500,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            l.providerVerified,
                            style: AppTextStyles.micro.copyWith(fontSize: 12),
                          ),
                          if (b.customerBookingCount != null) ...[
                            Text(
                              '   ·   ',
                              style: AppTextStyles.micro.copyWith(fontSize: 12),
                            ),
                            Text(
                              l.pbdPriorBookings(b.customerBookingCount!),
                              style: AppTextStyles.micro.copyWith(fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // No-op in the kit too.
                const AiwaIconButton(icon: LucideIcons.messageCircle),
              ],
            ),
          ),
          if (b.homeService)
            card(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.plum100,
                      borderRadius: BorderRadius.circular(AppTheme.radius10),
                    ),
                    child: Icon(
                      LucideIcons.mapPin,
                      size: 16,
                      color: AppColors.plum700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.pbdHomeAddress,
                          style: AppTextStyles.labelSm.copyWith(
                            fontSize: 11,
                            letterSpacing: 0.55,
                            color: AppColors.ink3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasAddress ? b.customerAddress! : l.pbdNoAddress,
                          style: AppTextStyles.bodySm.copyWith(
                            fontSize: AppTextStyles.fsMetaPlus,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          card(
            child: _Details(booking: b, quote: _quote),
          ),
          if (b.homeService && !hasAddress && pending)
            banner(
              InlineBanner(
                tone: BannerTone.warn,
                icon: LucideIcons.triangleAlert,
                title: l.pbdNoAddress,
                body: l.pbdNoAddressBody,
              ),
            ),
          if (_quote != null)
            banner(
              InlineBanner(
                tone: BannerTone.gold,
                icon: LucideIcons.car,
                title: l.pbdQuoteSent(l.egp(_quote!)),
                body: l.pbdQuoteSentBody,
              ),
            ),
          if (b.homeService && b.travelFee != null)
            banner(
              InlineBanner(
                tone: BannerTone.success,
                icon: LucideIcons.check,
                title: l.pbdFeeAccepted,
                body: l.pbdFeeAcceptedBody,
              ),
            ),
          if (_error != null)
            banner(InlineBanner(tone: BannerTone.danger, body: _error)),
          if (b.customerNote?.isNotEmpty ?? false)
            Container(
              margin: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                14,
                AppTheme.gutter,
                0,
              ),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(AppTheme.radius14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EyebrowLabel(l.pbdCustomerNote),
                  const SizedBox(height: 6),
                  Text(
                    l.commonQuoted(b.customerNote!),
                    style: AppTextStyles.meta.copyWith(
                      color: AppColors.ink2,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _pendingBar(BookingEntity b, bool hasAddress) {
    final canQuote =
        b.homeService && hasAddress && b.travelFee == null && _quote == null;
    final l = AppLocalizations.of(context);
    return StickyBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // The kit leaves Decline tappable while a quote is out.
              Expanded(
                child: AiwaButton(
                  label: l.commonDecline,
                  variant: AiwaButtonVariant.secondary,
                  size: AiwaButtonSize.lg,
                  fullWidth: true,
                  onPressed: _busy
                      ? null
                      : () =>
                            _act(() => _repo.rejectBooking(_id, ''), pop: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AiwaButton(
                  label: l.commonAccept,
                  icon: LucideIcons.check,
                  size: AiwaButtonSize.lg,
                  fullWidth: true,
                  loading: _busy,
                  onPressed: _quote != null
                      ? null
                      : () => _act(() => _repo.acceptBooking(_id)),
                ),
              ),
            ],
          ),
          if (canQuote) ...[
            const SizedBox(height: 8),
            AiwaButton(
              label: l.pbdQuoteInstead,
              icon: LucideIcons.car,
              variant: AiwaButtonVariant.ghost,
              size: AiwaButtonSize.sm,
              onPressed: _busy ? null : _quoteFee,
            ),
          ],
          if (_quote == null) ...[
            const SizedBox(height: 8),
            AiwaButton(
              label: l.pbdProposeInstead,
              icon: LucideIcons.calendarClock,
              variant: AiwaButtonVariant.ghost,
              size: AiwaButtonSize.sm,
              onPressed: _busy ? null : _propose,
            ),
          ],
        ],
      ),
    );
  }

  Widget _progressBar(BookingEntity b) {
    final l = AppLocalizations.of(context);
    final _Next? next = switch ((b.homeService, b.status)) {
      (true, 'ACCEPTED') => (
        label: l.pbdOnMyWay,
        icon: LucideIcons.navigation,
        note: l.pbdOnMyWayNote,
        call: _repo.bookingOnTheWay,
      ),
      (true, 'ON_THE_WAY') => (
        label: l.pbdArrived,
        icon: LucideIcons.mapPin,
        note: l.pbdArrivedNote,
        call: _repo.bookingArrived,
      ),
      (true, 'ARRIVED') => (
        label: l.pbdStartService,
        icon: LucideIcons.play,
        note: l.pbdStartNote,
        call: _repo.bookingInProgress,
      ),
      (false, 'ACCEPTED') => (
        label: l.pbdStartService,
        icon: LucideIcons.play,
        note: l.pbdStartVenueNote,
        call: _repo.bookingInProgress,
      ),
      _ => null,
    };
    return StickyBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            next?.note ?? l.pbdFinishNote,
            textAlign: TextAlign.center,
            style: AppTextStyles.micro.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (b.status != 'IN_PROGRESS') ...[
                AiwaButton(
                  label: l.commonCancel,
                  icon: LucideIcons.x,
                  variant: AiwaButtonVariant.secondary,
                  size: AiwaButtonSize.lg,
                  onPressed: _busy ? null : _cancel,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: next != null
                    ? AiwaButton(
                        label: next.label,
                        icon: next.icon,
                        size: AiwaButtonSize.lg,
                        fullWidth: true,
                        loading: _busy,
                        onPressed: () => _act(() => next.call(_id)),
                      )
                    : AiwaButton(
                        label: l.pbdMarkCompleted,
                        icon: LucideIcons.checkCheck,
                        size: AiwaButtonSize.lg,
                        fullWidth: true,
                        onPressed: () => context.push(
                          AppRoutes.providerBookingPayment(_id),
                          extra: b,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JobProgress extends StatelessWidget {
  final List<String> labels;
  final int index;
  const _JobProgress({required this.labels, required this.index});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EyebrowLabel(AppLocalizations.of(context).pbdJobProgress, fontSize: 10),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= index
                            ? AppColors.plum700
                            : AppColors.divider,
                        borderRadius: BorderRadius.circular(AppTheme.radius2),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[i],
                      style: AppTextStyles.micro.copyWith(
                        fontSize: 11,
                        height: 1.2,
                        fontWeight: i == index
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: i <= index ? AppColors.plum900 : AppColors.ink3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Service / Duration / Requested / prices / 'Total · cash'.
class _Details extends StatelessWidget {
  final BookingEntity booking;
  final double? quote;
  const _Details({required this.booking, this.quote});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final fee = b.travelFee ?? quote;
    final total = b.basePrice + (fee ?? 0);
    final k = AppTextStyles.meta;
    final v = AppTextStyles.label.copyWith(fontSize: 14);
    final l = AppLocalizations.of(context);
    Widget row(String key, Widget value) => Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(key, style: k),
        const SizedBox(width: 12),
        Expanded(
          child: Align(alignment: AlignmentDirectional.centerEnd, child: value),
        ),
      ],
    );
    final rows = [
      row(
        l.bookingService,
        Text(b.serviceName, style: v, textAlign: TextAlign.end),
      ),
      row(
        l.pbdDuration,
        Text(l.durationLabel(b.serviceDurationMinutes), style: v),
      ),
      row(
        l.pbdRequested,
        Text(l.relativeWhen(b.scheduledDate, b.scheduledTime), style: v),
      ),
      row(l.pbdServicePrice, Text(l.egp(b.basePrice), style: v)),
      if (fee != null)
        row(
          b.travelFee == null ? l.pbdTravelFeePending : l.pbdTravelFee,
          Text(l.egp(fee), style: v.copyWith(color: AppColors.gold700)),
        ),
      row(l.bookingTotalCash, Text(l.egp(total), style: AppTextStyles.price)),
    ];
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 12),
          ],
          rows[i],
        ],
      ],
    );
  }
}

/// 'Quote a travel fee' sheet; pops the amount.
class _QuoteSheet extends StatefulWidget {
  final BookingEntity booking;
  const _QuoteSheet({required this.booking});

  @override
  State<_QuoteSheet> createState() => _QuoteSheetState();
}

class _QuoteSheetState extends State<_QuoteSheet> {
  final _fee = TextEditingController(text: '120');

  @override
  void initState() {
    super.initState();
    _fee.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _fee.dispose();
    super.dispose();
  }

  void _send() {
    final n = double.tryParse(_fee.text);
    if (n == null || n <= 0) return;
    Navigator.pop(context, n);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final l = AppLocalizations.of(context);
    final first = (b.customerName ?? l.closeTheCustomer).split(' ').first;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.gold100,
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.car, size: 21, color: AppColors.gold700),
          ),
          const SizedBox(height: 12),
          EyebrowLabel(l.pbdQuoteEyebrow, color: AppColors.gold700),
          const SizedBox(height: 4),
          Text(
            l.pbdQuoteTitle(first),
            style: AppTextStyles.h3.copyWith(fontSize: 23, height: 1.12),
          ),
          const SizedBox(height: 7),
          Text(
            b.customerAddress ?? '',
            style: AppTextStyles.meta.copyWith(
              color: AppColors.ink2,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.pbdQuotePassThrough(l.egp(b.basePrice)),
            style: AppTextStyles.micro.copyWith(
              fontSize: AppTextStyles.fsLabelSmPlus,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final v in const [80, 120, 180]) ...[
                if (v != 80) const SizedBox(width: 8),
                Expanded(child: _preset(v)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(AppTheme.radius14),
              border: Border.all(color: AppColors.divider, width: 1.5),
            ),
            child: Row(
              children: [
                Text(
                  l.currencyEgp,
                  style: AppTextStyles.mono.copyWith(
                    fontSize: 14,
                    color: AppColors.ink3,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _fee,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    cursorColor: AppColors.plum700,
                    style: AppTextStyles.mono.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: AiwaButton(
                  label: l.commonCancel,
                  variant: AiwaButtonVariant.secondary,
                  size: AiwaButtonSize.lg,
                  fullWidth: true,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AiwaButton(
                  label: l.pbdSendQuote,
                  icon: LucideIcons.send,
                  size: AiwaButtonSize.lg,
                  fullWidth: true,
                  onPressed: _send,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _preset(int v) {
    final on = _fee.text == '$v';
    return GestureDetector(
      onTap: () => _fee.text = '$v',
      child: AnimatedContainer(
        duration: AppTheme.dur2,
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? AppColors.plum700 : AppColors.paper,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: on ? Colors.transparent : AppColors.divider,
            width: 1.5,
          ),
        ),
        child: Text(
          AppLocalizations.of(context).egp(v),
          style: AppTextStyles.label.copyWith(
            fontSize: AppTextStyles.fsMetaPlus,
            color: on ? AppColors.paper : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
