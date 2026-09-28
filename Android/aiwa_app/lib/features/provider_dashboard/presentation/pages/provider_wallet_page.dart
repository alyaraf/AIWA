import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_toast.dart';
import '../../../../shared/widgets/confirm_sheet.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../data/provider_manage_repository.dart';
import 'package:aiwa_app/l10n/l10n.dart';

// BACKEND GAP: SettlementSummaryDto has no negative limit; the prototype's
// EGP 500 is used until the platform setting is exposed.
const _limit = 500.0;

/// Next settlement: 7 days after the oldest outstanding entry — mirrors
/// SettlementController.dueDateOf, which the provider summary doesn't send.
DateTime? nextSettlement(List<Json> entries) {
  final dates = [
    for (final e in entries)
      if (e['status'] != 'SETTLED') DateTime.tryParse('${e['createdAt']}'),
  ].whereType<DateTime>();
  return dates.isEmpty
      ? null
      : dates
            .reduce((a, b) => a.isBefore(b) ? a : b)
            .add(const Duration(days: 7));
}

/// Wallet — `ProviderWallet` (provider-extras.jsx:15-82).
class ProviderWalletPage extends StatefulWidget {
  const ProviderWalletPage({super.key});

  @override
  State<ProviderWalletPage> createState() => _ProviderWalletPageState();
}

class _ProviderWalletPageState extends State<ProviderWalletPage> {
  final _repo = sl<ProviderManageRepository>();
  Json? _s;
  String? _error;
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await _repo.settlement();
    if (!mounted) return;
    setState(() {
      _error = r.fold(
        (f) => AppLocalizations.of(context).error(f.message),
        (_) => null,
      );
      _s = r.fold((_) => _s, (s) => s);
    });
  }

  Future<void> _settle(double due) async {
    final ok = await showConfirmSheet(
      context,
      eyebrow: AppLocalizations.of(context).walletEyebrow,
      title: AppLocalizations.of(
        context,
      ).walletSettleTitle(AppLocalizations.of(context).egpCents(due)),
      confirmLabel: AppLocalizations.of(context).walletSettleBalance,
      icon: Icons.payments_outlined,
      danger: false,
    );
    if (!ok || !mounted) return;
    setState(() => _paying = true);
    final r = await _repo.settle();
    if (!mounted) return;
    setState(() {
      _paying = false;
      _error = r.fold(
        (f) => AppLocalizations.of(context).error(f.message),
        (_) => null,
      );
      _s = r.fold((_) => _s, (s) => s);
    });
    if (r.isRight()) {
      showAiwaToast(context, AppLocalizations.of(context).walletSettled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final entries = [
      for (final e in s?['entries'] as List? ?? const []) e as Json,
    ];
    final due = (s?['dueAmount'] as num?)?.toDouble() ?? 0;
    // Backend blocks bookings via settlementPaused; that's the over-limit flag.
    final blocked = s?['settlementPaused'] == true || due >= _limit;
    final next = nextSettlement(entries);
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.bone,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          ScreenHeader(
            eyebrow: l.walletEyebrow,
            title: l.walletTitle,
            onBack: () => context.pop(),
          ),
          if (s == null)
            Padding(
              padding: const EdgeInsets.all(AppTheme.gutter),
              child: _error != null
                  ? ErrorState(body: _error!, onRetry: _load, compact: true)
                  : const SkeletonList(),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                16,
                AppTheme.gutter,
                0,
              ),
              child: Container(
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  gradient: AppTheme.heroGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  children: [
                    PositionedDirectional(
                      end: -50,
                      top: -70,
                      child: AiwaGlow(
                        size: 220,
                        color: AppColors.rose300,
                        opacity: .3,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          EyebrowLabel(l.walletOwed, color: AppColors.rose300),
                          const SizedBox(height: 6),
                          Text(
                            l.egpCents(due),
                            style: AppTextStyles.display.copyWith(
                              fontSize: 38,
                              color: AppColors.bone,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (due / _limit).clamp(0, 1),
                              minHeight: 6,
                              backgroundColor: Colors.white.withValues(
                                alpha: .18,
                              ),
                              color: blocked
                                  ? AppColors.danger500
                                  : AppColors.rose300,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l.walletLimit(l.egp(_limit)),
                            style: AppTextStyles.micro.copyWith(
                              fontSize: 12,
                              color: AppColors.rose300,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (blocked)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.gutter,
                  14,
                  AppTheme.gutter,
                  0,
                ),
                child: InlineBanner(
                  tone: BannerTone.danger,
                  icon: Icons.block_rounded,
                  title: l.walletBlocked,
                  body: l.walletBlockedBody,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                14,
                AppTheme.gutter,
                0,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 10,
                  children: [
                    _Tile(
                      label: l.walletNextSettlement,
                      child: Text(
                        next == null
                            ? '—'
                            : DateFormat.MMMEd(l.localeName).format(next),
                        style: AppTextStyles.h3.copyWith(
                          fontSize: 18,
                          color: AppColors.plum900,
                        ),
                      ),
                    ),
                    _Tile(
                      label: l.walletStatus,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: StatusPill(
                            status: blocked ? 'cancelled' : 'confirmed',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.gutter,
                  14,
                  AppTheme.gutter,
                  0,
                ),
                child: InlineBanner(tone: BannerTone.danger, body: _error),
              ),
            SectionHeader(title: l.walletLedger),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
              child: entries.isEmpty
                  ? EmptyState(
                      icon: Icons.payments_outlined,
                      title: l.walletNoCommission,
                      subtitle: l.walletNoCommissionBody,
                      compact: true,
                    )
                  : Column(
                      spacing: 8,
                      children: [for (final e in entries) _LedgerRow(e: e)],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                20,
                AppTheme.gutter,
                0,
              ),
              child: AiwaButton(
                label: l.walletSettleNow,
                icon: Icons.payments_outlined,
                size: AiwaButtonSize.lg,
                fullWidth: true,
                loading: _paying,
                onPressed: due > 0 && !_paying ? () => _settle(due) : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final Widget child;
  const _Tile({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [EyebrowLabel(label, fontSize: 10), child],
        ),
      ),
    );
  }
}

/// One CommissionLedgerDto. The DTO has no service/customer name, so rows
/// read by booking number.
class _LedgerRow extends StatelessWidget {
  final Json e;
  const _LedgerRow({required this.e});

  @override
  Widget build(BuildContext context) {
    final settled = e['status'] == 'SETTLED';
    final at = DateTime.tryParse(
      '${settled ? e['settledAt'] : e['createdAt']}',
    );
    final amount = (e['commissionAmount'] as num?)?.toDouble() ?? 0;
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        spacing: 12,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: settled ? AppColors.success100 : AppColors.plum100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              settled ? Icons.check_rounded : Icons.payments_outlined,
              size: 16,
              color: settled ? AppColors.success700 : AppColors.plum700,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e['bookingId'] == null
                      ? l.walletCommission
                      : l.walletCommissionBooking('${e['bookingId']}'),
                  style: AppTextStyles.label.copyWith(
                    fontSize: 13.5,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (settled) l.walletSettledTag,
                    if (e['status'] == 'OVERDUE') l.walletOverdue,
                    if (at != null)
                      DateFormat('MMM d · h:mm a', l.localeName).format(at),
                  ].join(' · '),
                  style: AppTextStyles.micro.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
          Text(
            l.egpCents(amount, sign: settled ? '+' : '−'),
            style: AppTextStyles.h3.copyWith(
              fontSize: 15,
              color: settled ? AppColors.success700 : AppColors.plum900,
            ),
          ),
        ],
      ),
    );
  }
}
