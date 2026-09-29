import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_avatar.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_icon_button.dart';
import '../../../../shared/widgets/aiwa_text_field.dart';
import '../../../../shared/widgets/aiwa_toast.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/reason_sheet.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../domain/entities/booking_entity.dart';
import '../bloc/live_booking_cubit.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Back button + content column used by Proposed time and Payment confirm
/// (customer and provider)
/// (padding '70px 24px 32px').
class PlainScreen extends StatelessWidget {
  final List<Widget> children;
  const PlainScreen({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: AppColors.bone,
      // Scrolls when the keyboard is up; Spacers still fill a tall screen.
      body: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            insets.top + 26,
            24,
            insets.bottom + 32,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: box.maxHeight - insets.vertical - 58,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: AiwaIconButton(
                      icon: LucideIcons.arrowLeftDir,
                      onTap: () => Navigator.maybePop(context),
                    ),
                  ),
                  const SizedBox(height: 22),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shimmer / error while the booking loads; [builder] once it's here.
Widget _withBooking(
  BuildContext context,
  LiveBookingState s,
  Widget Function(BookingEntity b) builder,
) {
  final b = s.booking;
  if (b != null) return builder(b);
  return Scaffold(
    backgroundColor: AppColors.bone,
    body: s.loadError != null
        ? ErrorState(
            body: AppLocalizations.of(context).error(s.loadError!),
            onRetry: context.read<LiveBookingCubit>().load,
          )
        : const Padding(
            padding: EdgeInsets.fromLTRB(22, 80, 22, 0),
            child: SkeletonList(count: 2),
          ),
  );
}

TextStyle get _title =>
    AppTextStyles.h1.copyWith(height: 1.1, letterSpacing: 0);

TextStyle get _lead =>
    AppTextStyles.bodySm.copyWith(color: AppColors.ink2, height: 1.55);

// ─────────────────────────────────────────────────────────────
// BOOK-30 / 31 / V01 — Proposed time
// ─────────────────────────────────────────────────────────────

/// mm:ss for the proposal countdown.
String mmss(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

class ProposedTimePage extends StatelessWidget {
  final String bookingId;
  final BookingEntity? booking;
  const ProposedTimePage({super.key, required this.bookingId, this.booking});

  @override
  Widget build(BuildContext context) => LiveBookingScope(
    bookingId: bookingId,
    booking: booking,
    child: const _ProposedTimeView(),
  );
}

class _ProposedTimeView extends StatefulWidget {
  const _ProposedTimeView();

  @override
  State<_ProposedTimeView> createState() => _ProposedTimeViewState();
}

class _ProposedTimeViewState extends State<_ProposedTimeView> {
  // BookingDto.proposalExpiresAt drives the countdown; an older backend
  // without it falls back to a 30:00 window from when the screen opened.
  int _left = 30 * 60;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      // Keeps ticking so a server expiry beyond 30:00 still counts down.
      setState(() {
        if (_left > 0) _left--;
      });
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  LiveBookingCubit get _cubit => context.read<LiveBookingCubit>();

  Future<void> _accept(BookingEntity b) async {
    if (!await _cubit.respondToProposal(true) || !mounted) return;
    showAiwaToast(context, AppLocalizations.of(context).proposedAccepted);
    context.canPop() ? context.pop() : context.go('/booking/${b.id}/track');
  }

  Future<void> _decline(BookingEntity b, {required bool expired}) async {
    if (!expired && !await _cubit.respondToProposal(false)) return;
    if (!mounted) return;
    context.pushReplacement(
      '/booking/${b.id}/rejected',
      extra: _cubit.state.booking ?? b,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveBookingCubit, LiveBookingState>(
      builder: (context, s) => _withBooking(context, s, (b) {
        // Already answered or released server-side counts as expired too.
        final exp = b.proposalExpiresAt;
        final left = exp == null
            ? _left
            : exp.difference(DateTime.now()).inSeconds.clamp(0, 1 << 30);
        final expired = left <= 0 || !(b.status == 'PENDING' && b.hasProposal);
        final urgent = left < 120;
        final l = AppLocalizations.of(context);
        final cd = AppTextStyles.micro.copyWith(
          fontSize: AppTextStyles.fsLabelSmPlus,
          color: urgent ? AppColors.danger700 : AppColors.ink3,
        );
        return PlainScreen(
          children: [
            EyebrowLabel(l.proposedEyebrow, color: AppColors.rose700),
            const SizedBox(height: 6),
            Text(
              l.proposedTitle(b.displayProviderName),
              style: _title.copyWith(fontSize: 28, height: 1.08),
            ),
            const SizedBox(height: 8),
            Text(l.proposedLead, style: _lead),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppColors.plum700, width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.plum100,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Icon(
                      LucideIcons.calendarClock,
                      size: 22,
                      color: AppColors.plum700,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.hasProposal
                              ? l.formatWhen(
                                  b.proposedDate!,
                                  b.proposedStartTime!,
                                )
                              : l.formatWhen(b.scheduledDate, b.scheduledTime),
                          style: AppTextStyles.h4.copyWith(
                            fontSize: 20,
                            height: 1.1,
                          ),
                        ),
                        if (b.hasProposal) ...[
                          const SizedBox(height: 3),
                          Text(
                            l.proposedInsteadOf(
                              l.formatWhen(b.scheduledDate, b.scheduledTime),
                            ),
                            style: AppTextStyles.micro.copyWith(
                              fontSize: AppTextStyles.fsLabelSmPlus,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (expired)
              InlineBanner(
                tone: BannerTone.warn,
                icon: LucideIcons.hourglass,
                title: l.proposedExpiredTitle,
                body: l.proposedExpiredBody,
              )
            else
              Row(
                children: [
                  Icon(LucideIcons.hourglass, size: 14, color: cd.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: cd,
                        children: spansOf(l.proposedRespondWithin('{time}'), {
                          'time': TextSpan(
                            text: mmss(left),
                            style: AppTextStyles.mono.copyWith(
                              fontSize: AppTextStyles.fsLabelSmPlus,
                              fontWeight: FontWeight.w700,
                              color: cd.color,
                            ),
                          ),
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            if (s.actionError != null) ...[
              const SizedBox(height: 12),
              InlineBanner(
                tone: BannerTone.danger,
                body: l.error(s.actionError!),
              ),
            ],
            const Spacer(),
            if (expired) ...[
              AiwaButton(
                label: l.outcomeSeeAlternatives,
                icon: LucideIcons.search,
                size: AiwaButtonSize.lg,
                fullWidth: true,
                onPressed: () => _decline(b, expired: true),
              ),
              const SizedBox(height: 10),
              AiwaButton(
                label: l.outcomeBackToBookings,
                variant: AiwaButtonVariant.secondary,
                size: AiwaButtonSize.lg,
                fullWidth: true,
                onPressed: () => context.go(AppRoutes.myBookings),
              ),
            ] else ...[
              AiwaButton(
                label: l.proposedAccept,
                icon: LucideIcons.check,
                size: AiwaButtonSize.lg,
                fullWidth: true,
                loading: s.busy,
                onPressed: () => _accept(b),
              ),
              const SizedBox(height: 10),
              AiwaButton(
                label: l.proposedDecline,
                variant: AiwaButtonVariant.secondary,
                size: AiwaButtonSize.lg,
                fullWidth: true,
                onPressed: s.busy ? null : () => _decline(b, expired: false),
              ),
            ],
          ],
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOOK-38 / 39 / 40 — Payment confirm (customer)
// ─────────────────────────────────────────────────────────────

enum _PayStep { question, confirmed, dispute }

class PaymentConfirmPage extends StatelessWidget {
  final String bookingId;
  final BookingEntity? booking;
  const PaymentConfirmPage({super.key, required this.bookingId, this.booking});

  @override
  Widget build(BuildContext context) => LiveBookingScope(
    bookingId: bookingId,
    booking: booking,
    child: const _PaymentView(),
  );
}

class _PaymentView extends StatefulWidget {
  const _PaymentView();

  @override
  State<_PaymentView> createState() => _PaymentViewState();
}

class _PaymentViewState extends State<_PaymentView> {
  var _step = _PayStep.question;
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  LiveBookingCubit get _cubit => context.read<LiveBookingCubit>();

  /// "Yes, I paid" stays local so Undo works; the PATCH goes out when the
  /// customer moves on (Rate / back).
  Future<void> _commitPaid({required bool thenReview}) async {
    if (!await _cubit.confirmPayment(paid: true) || !mounted) return;
    showAiwaToast(context, AppLocalizations.of(context).payConfirmedToast);
    final b = _cubit.state.booking!;
    // The prototype only toasts and pops; the label promises a rating.
    thenReview
        ? context.pushReplacement('/review/${b.id}', extra: b)
        : context.pop();
  }

  Future<void> _submitUnpaid() async {
    final ok = await _cubit.confirmPayment(
      paid: false,
      reason: _reason.text.trim(),
    );
    if (!ok || !mounted) return;
    showAiwaToast(context, AppLocalizations.of(context).payUnpaidToast);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step != _PayStep.confirmed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _commitPaid(thenReview: false);
      },
      child: BlocBuilder<LiveBookingCubit, LiveBookingState>(
        builder: (context, s) => _withBooking(context, s, (b) {
          final l = AppLocalizations.of(context);
          final amount = l.egp(b.servicePrice);
          return PlainScreen(
            children: [
              EyebrowLabel(l.payEyebrow),
              const SizedBox(height: 6),
              Text(
                l.payTitle(b.displayProviderName),
                style: _title.copyWith(fontSize: 26, letterSpacing: -0.26),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: _lead,
                  children: spansOf(l.payTotalDue('{amount}'), {
                    'amount': TextSpan(
                      text: amount,
                      style: _lead.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.plum900,
                      ),
                    ),
                  }),
                ),
              ),
              if (s.actionError != null) ...[
                const SizedBox(height: 16),
                InlineBanner(
                  tone: BannerTone.danger,
                  body: l.error(s.actionError!),
                ),
              ],
              ...switch (_step) {
                _PayStep.question => [
                  const SizedBox(height: 24),
                  AiwaButton(
                    label: l.payYes,
                    icon: LucideIcons.check,
                    size: AiwaButtonSize.lg,
                    fullWidth: true,
                    onPressed: () => setState(() => _step = _PayStep.confirmed),
                  ),
                  const SizedBox(height: 10),
                  AiwaButton(
                    label: l.payNo,
                    icon: LucideIcons.triangleAlert,
                    variant: AiwaButtonVariant.secondary,
                    size: AiwaButtonSize.lg,
                    fullWidth: true,
                    onPressed: () => setState(() => _step = _PayStep.dispute),
                  ),
                ],
                _PayStep.confirmed => [
                  const SizedBox(height: 24),
                  PaidCard(amount: amount),
                  const SizedBox(height: 16),
                  AiwaButton(
                    label: l.payRate,
                    icon: LucideIcons.star,
                    size: AiwaButtonSize.lg,
                    fullWidth: true,
                    loading: s.busy,
                    onPressed: () => _commitPaid(thenReview: true),
                  ),
                  const SizedBox(height: 8),
                  AiwaButton(
                    label: l.payUndo,
                    variant: AiwaButtonVariant.ghost,
                    fullWidth: true,
                    onPressed: s.busy
                        ? null
                        : () => setState(() => _step = _PayStep.question),
                  ),
                ],
                _PayStep.dispute => [
                  const SizedBox(height: 22),
                  EyebrowLabel(l.payWhatHappened),
                  const SizedBox(height: 10),
                  AiwaTextField(
                    controller: _reason,
                    placeholder: l.payExplainPlaceholder,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 14),
                  AiwaButton(
                    label: l.paySubmitUnpaid,
                    variant: AiwaButtonVariant.danger,
                    size: AiwaButtonSize.lg,
                    fullWidth: true,
                    loading: s.busy,
                    onPressed: _reason.text.trim().isEmpty
                        ? null
                        : _submitUnpaid,
                  ),
                  const SizedBox(height: 8),
                  AiwaButton(
                    label: l.commonBack,
                    variant: AiwaButtonVariant.ghost,
                    fullWidth: true,
                    onPressed: () => setState(() => _step = _PayStep.question),
                  ),
                ],
              },
            ],
          );
        }),
      ),
    );
  }
}

/// 'Payment confirmed' / 'Cash received · job closed' card.
class PaidCard extends StatelessWidget {
  final String amount;
  final String? title;
  final String? sub;

  /// Provider only: 'AIWA commission (15%) · added to ledger' value.
  final String? commission;

  const PaidCard({
    super.key,
    required this.amount,
    this.title,
    this.sub,
    this.commission,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final k = AppTextStyles.meta.copyWith(fontSize: AppTextStyles.fsMetaPlus);
    final v = k.copyWith(fontWeight: FontWeight.w600, color: AppColors.ink);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppTheme.radius20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.success100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.check,
                  size: 22,
                  color: AppColors.success700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title ?? l.paidTitle,
                      style: AppTextStyles.bodyLg.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub ?? l.paidSub,
                      style: AppTextStyles.micro.copyWith(
                        fontSize: AppTextStyles.fsLabelSmPlus,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: Text(l.paidCashCollected, style: k)),
              Text(amount, style: v),
            ],
          ),
          if (commission != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text(l.paidCommission, style: k)),
                Text(commission!, style: v.copyWith(color: AppColors.gold700)),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text(l.paidBookingStatus, style: k)),
              Text(
                l.statusCompleted,
                style: v.copyWith(color: AppColors.success700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOOK-35 — Complaint
// ─────────────────────────────────────────────────────────────

typedef _Cat = ({String id, String label, IconData icon, String hint});

List<_Cat> _categories(AppLocalizations l) => [
  (
    id: 'behavior',
    label: l.complaintBehavior,
    icon: LucideIcons.userX,
    hint: l.complaintBehaviorHint,
  ),
  (
    id: 'quality',
    label: l.complaintQuality,
    icon: LucideIcons.thumbsDown,
    hint: l.complaintQualityHint,
  ),
  (
    id: 'pricing',
    label: l.complaintPricing,
    icon: LucideIcons.banknote,
    hint: l.complaintPricingHint,
  ),
  (
    id: 'safety',
    label: l.complaintSafety,
    icon: LucideIcons.shieldAlert,
    hint: l.complaintSafetyHint,
  ),
  (
    id: 'noshow',
    label: l.complaintNoShow,
    icon: LucideIcons.userX,
    hint: l.complaintNoShowHint,
  ),
  (
    id: 'other',
    label: l.complaintOther,
    icon: LucideIcons.ellipsis,
    hint: l.complaintOtherHint,
  ),
];

class ComplaintPage extends StatelessWidget {
  final String bookingId;
  final BookingEntity? booking;
  const ComplaintPage({super.key, required this.bookingId, this.booking});

  @override
  Widget build(BuildContext context) => LiveBookingScope(
    bookingId: bookingId,
    booking: booking,
    child: const _ComplaintView(),
  );
}

class _ComplaintView extends StatefulWidget {
  const _ComplaintView();

  @override
  State<_ComplaintView> createState() => _ComplaintViewState();
}

class _ComplaintViewState extends State<_ComplaintView> {
  _Cat? _cat;
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final c = _cat!;
    final text = _text.text.trim();
    final ok = await context.read<LiveBookingCubit>().submitComplaint(
      c.id.toUpperCase(),
      // /complaints requires a description; the details are optional here.
      text.isEmpty ? c.label : text,
    );
    if (!ok || !mounted) return;
    showAiwaToast(context, AppLocalizations.of(context).complaintSubmitted);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveBookingCubit, LiveBookingState>(
      builder: (context, s) => _withBooking(
        context,
        s,
        (b) => Scaffold(
          backgroundColor: AppColors.bone,
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              ScreenHeader(
                eyebrow: AppLocalizations.of(context).complaintEyebrow,
                title: AppLocalizations.of(context).payWhatHappened,
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
                    _AboutCard(booking: b),
                    const SizedBox(height: 22),
                    EyebrowLabel(
                      AppLocalizations.of(context).complaintPickCategory,
                    ),
                    const SizedBox(height: 10),
                    for (final c in _categories(
                      AppLocalizations.of(context),
                    )) ...[
                      ReasonRow(
                        label: c.label,
                        hint: c.hint,
                        icon: c.icon,
                        selected: _cat?.id == c.id,
                        onTap: () => setState(() => _cat = c),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 14),
                    EyebrowLabel(
                      AppLocalizations.of(context).complaintTellMore,
                    ),
                    const SizedBox(height: 10),
                    AiwaTextField(
                      controller: _text,
                      placeholder: AppLocalizations.of(
                        context,
                      ).complaintPlaceholder,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(
                              LucideIcons.lock,
                              size: 14,
                              color: AppColors.plum700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context).complaintPrivate,
                              style: AppTextStyles.micro.copyWith(
                                fontSize: 12,
                                height: 1.5,
                                color: AppColors.ink2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (s.actionError != null) ...[
                      const SizedBox(height: 12),
                      InlineBanner(
                        tone: BannerTone.danger,
                        body: AppLocalizations.of(
                          context,
                        ).error(s.actionError!),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: StickyBar(
            child: AiwaButton(
              label: AppLocalizations.of(context).complaintSubmit,
              size: AiwaButtonSize.lg,
              fullWidth: true,
              loading: s.busy,
              onPressed: _cat == null ? null : _submit,
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  final BookingEntity booking;
  const _AboutCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppTheme.radius14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          AiwaAvatar(
            name: booking.displayProviderName,
            size: 36,
            imageUrl: booking.providerImageUrl,
            verified: booking.providerVerified,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(
                    context,
                  ).complaintAbout(booking.displayProviderName),
                  style: AppTextStyles.label.copyWith(height: 1.3),
                ),
                Text(
                  AppLocalizations.of(context).complaintBookingNo(booking.id),
                  style: AppTextStyles.micro.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          EyebrowLabel(
            AppLocalizations.of(context).complaintPrivateTag,
            fontSize: 10,
            color: AppColors.rose700,
          ),
        ],
      ),
    );
  }
}
