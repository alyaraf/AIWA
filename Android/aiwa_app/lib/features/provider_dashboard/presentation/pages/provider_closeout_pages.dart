import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/aiwa_avatar.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_chip.dart';
import '../../../../shared/widgets/aiwa_text_field.dart';
import '../../../../shared/widgets/aiwa_toast.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../../../bookings/presentation/pages/booking_action_pages.dart';
import '../../../reviews/domain/repositories/review_repository.dart';
import '../../domain/repositories/dashboard_repository.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../shared/widgets/star_rating.dart';
import '../../../../core/theme/app_theme.dart';

enum _Step { question, confirmed, dispute }

/// Provider `PaymentConfirmScreen` (flow-additions-v4.jsx:82-160):
/// 'Did {customer} pay in cash?' -> cash received / dispute.
class ProviderPaymentConfirmPage extends StatefulWidget {
  final BookingEntity booking;
  const ProviderPaymentConfirmPage({super.key, required this.booking});

  @override
  State<ProviderPaymentConfirmPage> createState() =>
      _ProviderPaymentConfirmPageState();
}

class _ProviderPaymentConfirmPageState
    extends State<ProviderPaymentConfirmPage> {
  var _step = _Step.question;
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  BookingEntity get _b => widget.booking;
  String get _name =>
      _b.customerName ?? AppLocalizations.of(context).closeTheCustomer;

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

  /// PATCH /complete. 'Cash received' stays local until Rate so Undo works
  /// (there's no endpoint to reopen a completed booking).
  Future<bool> _complete({required bool cash}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await sl<DashboardRepository>().completeBooking(
      _b.id,
      cashCollected: cash,
      // The explanation goes with a dispute (BookingDto.completionNote).
      note: cash ? null : _reason.text.trim(),
    );
    if (!mounted) return false;
    setState(() {
      _busy = false;
      _error = r.fold(
        (f) => AppLocalizations.of(context).error(f.message),
        (_) => null,
      );
    });
    if (r.isRight()) providerBookingsChanged.value++;
    return r.isRight();
  }

  Future<void> _rate() async {
    if (!await _complete(cash: true) || !mounted) return;
    context.pushReplacement(AppRoutes.providerRateCustomer(_b.id), extra: _b);
  }

  Future<void> _dispute() async {
    if (!await _complete(cash: false) || !mounted) return;
    showAiwaToast(context, AppLocalizations.of(context).closeDisputedToast);
    context.go(AppRoutes.providerBookings);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final amount = l.egp(_b.servicePrice);
    // Commission is on the service price only; the travel fee is pass-through.
    // ponytail: 15% mirrors the kit until completion returns commissionAmount.
    final commission = l.egp(_b.commissionAmount ?? _b.basePrice * .15);
    final lead = AppTextStyles.bodySm.copyWith(
      color: AppColors.ink2,
      height: 1.55,
    );
    return PopScope(
      // Leaving after 'Cash received' still closes the job.
      canPop: _step != _Step.confirmed,
      onPopInvokedWithResult: (didPop, _) async {
        final nav = Navigator.of(context);
        if (didPop || !await _complete(cash: true)) return;
        nav.pop();
      },
      child: PlainScreen(
        children: [
          EyebrowLabel(l.closeEyebrow),
          const SizedBox(height: 6),
          Text(
            l.closeDidPay(_name),
            style: AppTextStyles.h1.copyWith(
              fontSize: 26,
              height: 1.1,
              letterSpacing: -0.26,
            ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: lead,
              children: spansOf(l.payTotalDue('{amount}'), {
                'amount': TextSpan(
                  text: amount,
                  style: lead.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.plum900,
                  ),
                ),
              }),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            InlineBanner(tone: BannerTone.danger, body: _error),
          ],
          ...switch (_step) {
            _Step.question => [
              const SizedBox(height: 24),
              AiwaButton(
                label: l.closeCashReceived,
                icon: LucideIcons.check,
                size: AiwaButtonSize.lg,
                fullWidth: true,
                onPressed: () => setState(() => _step = _Step.confirmed),
              ),
              const SizedBox(height: 10),
              AiwaButton(
                label: l.closeMarkDisputed,
                icon: LucideIcons.triangleAlert,
                variant: AiwaButtonVariant.secondary,
                size: AiwaButtonSize.lg,
                fullWidth: true,
                onPressed: () => setState(() => _step = _Step.dispute),
              ),
            ],
            _Step.confirmed => [
              const SizedBox(height: 24),
              PaidCard(
                amount: amount,
                title: l.closeJobClosed,
                sub: l.closeReceiptSentTo(_name),
                commission: commission,
              ),
              const SizedBox(height: 16),
              AiwaButton(
                label: l.closeRate(_name),
                icon: LucideIcons.star,
                size: AiwaButtonSize.lg,
                fullWidth: true,
                loading: _busy,
                onPressed: _rate,
              ),
              const SizedBox(height: 8),
              AiwaButton(
                label: l.payUndo,
                variant: AiwaButtonVariant.ghost,
                fullWidth: true,
                onPressed: _busy
                    ? null
                    : () => setState(() => _step = _Step.question),
              ),
            ],
            _Step.dispute => [
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
                label: l.closeSubmitDisputed,
                variant: AiwaButtonVariant.danger,
                size: AiwaButtonSize.lg,
                fullWidth: true,
                loading: _busy,
                onPressed: _reason.text.trim().isEmpty ? null : _dispute,
              ),
              const SizedBox(height: 8),
              AiwaButton(
                label: l.commonBack,
                variant: AiwaButtonVariant.ghost,
                fullWidth: true,
                onPressed: () => setState(() => _step = _Step.question),
              ),
            ],
          },
        ],
      ),
    );
  }
}

/// `RateCustomerScreen` (provider-extras.jsx:84-122) — two-way rating.
class RateCustomerPage extends StatefulWidget {
  final BookingEntity booking;
  const RateCustomerPage({super.key, required this.booking});

  @override
  State<RateCustomerPage> createState() => _RateCustomerPageState();
}

class _RateCustomerPageState extends State<RateCustomerPage> {
  /// Sent to the backend as-is; shown via [AiwaL10n.reviewTag].
  static const _tags = [
    'On time',
    'Respectful',
    'Clear about needs',
    'Paid in full',
    'Late',
    'Difficult to reach',
  ];

  var _rating = 0;
  final _picked = <String>{};
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await sl<ReviewRepository>().submitReview(
      bookingId: widget.booking.id,
      rating: _rating.toDouble(),
      tags: _picked.toList(),
      direction: 'PROVIDER_TO_CUSTOMER',
    );
    if (!mounted) return;
    r.fold(
      (f) => setState(() {
        _busy = false;
        _error = AppLocalizations.of(context).error(f.message);
      }),
      (_) {
        showAiwaToast(context, AppLocalizations.of(context).rateSubmitted);
        context.go(AppRoutes.providerBookings);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final name = widget.booking.customerName ?? l.rateCustomerFallback;
    return Scaffold(
      backgroundColor: AppColors.bone,
      bottomNavigationBar: StickyBar(
        child: AiwaButton(
          label: l.rateSubmit,
          size: AiwaButtonSize.lg,
          fullWidth: true,
          loading: _busy,
          onPressed: _rating > 0 ? _submit : null,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ScreenHeader(
            eyebrow: l.rateEyebrow,
            title: l.closeRate(name),
            onBack: () => context.pop(),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(22, 14, 22, 0),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                AiwaAvatar(name: name, size: 64),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var n = 1; n <= 5; n++)
                      Semantics(
                        button: true,
                        label: l.rateStars(n),
                        child: GestureDetector(
                          onTap: () => setState(() => _rating = n),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: AiwaStar(
                              filled: _rating >= n,
                              size: 36,
                              color: _rating >= n
                                  ? AppColors.gold500
                                  : AppColors.ink4,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EyebrowLabel(l.rateQuickTags),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in _tags)
                      AiwaChip(
                        label: l.reviewTag(t),
                        active: _picked.contains(t),
                        onTap: () => setState(
                          () => _picked.contains(t)
                              ? _picked.remove(t)
                              : _picked.add(t),
                        ),
                      ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  InlineBanner(tone: BannerTone.danger, body: _error),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
