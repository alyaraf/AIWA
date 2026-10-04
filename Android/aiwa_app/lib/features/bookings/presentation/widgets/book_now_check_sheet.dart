import 'package:aiwa_app/features/providers/domain/repositories/provider_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_sheet.dart';
import '../../../providers/domain/entities/provider_detail_entity.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// BOOK_NOW_BLOCKS (system-screens.jsx:220-226).
enum BookNowBlock {
  offline(LucideIcons.wifiOff),
  busy(LucideIcons.clock),
  vacation(LucideIcons.palmtree),
  settlementPaused(LucideIcons.banknote),
  notApproved(LucideIcons.shieldAlert);

  final IconData icon;
  const BookNowBlock(this.icon);

  /// (eyebrow, title, body) in the active language.
  (String, String, String) copy(AppLocalizations l, String name) =>
      switch (this) {
        offline => (
          l.bookNowOfflineEyebrow,
          l.bookNowOfflineTitle(name),
          l.bookNowOfflineBody,
        ),
        busy => (
          l.bookNowBusyEyebrow,
          l.bookNowBusyTitle(name),
          l.bookNowBusyBody,
        ),
        vacation => (
          l.bookNowVacationEyebrow,
          l.bookNowVacationTitle(name),
          l.bookNowVacationBody,
        ),
        settlementPaused => (
          l.bookNowPausedEyebrow,
          l.bookNowPausedTitle(name),
          l.bookNowPausedBody,
        ),
        notApproved => (
          l.bookNowUnavailableEyebrow,
          l.bookNowUnavailableTitle(name),
          l.bookNowUnavailableBody,
        ),
      };
}

/// Derived from ProviderDetailDto flags (busyNow = mid-booking right now)
/// plus today's /bookings/slots (no Book Now slot left = busy too).
/// [freeToday] is null when the slot lookup failed — the backend then decides.
BookNowBlock? bookNowBlockFor(
  ProviderDetailEntity p, {
  required List<String>? freeToday,
  required DateTime now,
}) {
  if (p.vacationMode) return BookNowBlock.vacation;
  if (p.settlementPaused) return BookNowBlock.settlementPaused;
  if (p.offlineMode) return BookNowBlock.offline;
  if (!p.isVerified || !p.isActive) return BookNowBlock.notApproved;
  if (p.busyNow) return BookNowBlock.busy;
  if (freeToday == null) return null;
  final hhmm = DateFormat('HH:mm').format(now);
  final anyLeft = freeToday.any((t) => t.compareTo(hhmm) > 0);
  return anyLeft ? null : BookNowBlock.busy;
}

enum BookNowChoice { now, schedule, alternatives }

/// BookNowCheckSheet (system-screens.jsx:228-275). Pops [BookNowChoice.now]
/// on its own when nothing blocks; the caller does the navigation.
Future<BookNowChoice?> showBookNowCheckSheet(
  BuildContext context, {
  required ProviderDetailEntity provider,
  String? serviceId,
}) => showAiwaSheet<BookNowChoice>(
  context,
  builder: (_) => _BookNowCheck(provider: provider, serviceId: serviceId),
);

class _BookNowCheck extends StatefulWidget {
  final ProviderDetailEntity provider;
  final String? serviceId;
  const _BookNowCheck({required this.provider, this.serviceId});

  @override
  State<_BookNowCheck> createState() => _BookNowCheckState();
}

class _BookNowCheckState extends State<_BookNowCheck>
    with SingleTickerProviderStateMixin {
  bool _checking = true;
  BookNowBlock? _block;

  // aiwa-pulse 1.1s.
  late final _pulse = AnimationController(
    vsync: this,
    duration: AppTheme.durPulse,
    lowerBound: .55,
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<List<String>?> _freeToday() async {
    final p = widget.provider;
    final serviceId =
        widget.serviceId ??
        p.services.where((s) => s.available).firstOrNull?.id;
    if (serviceId == null) return null;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final r = await sl<ProviderRepository>().getAvailableSlots(p.id, serviceId, today);
    return r.fold((_) => null, (s) => [for (final x in s) ...x.times]);
  }

  Future<void> _run() async {
    final results = await Future.wait([
      _freeToday(),
      Future<void>.delayed(const Duration(milliseconds: 850)),
    ]);
    if (!mounted) return;
    final block = bookNowBlockFor(
      widget.provider,
      freeToday: results.first as List<String>?,
      now: DateTime.now(),
    );
    if (block == null) {
      Navigator.of(context).pop(BookNowChoice.now);
      return;
    }
    setState(() {
      _checking = false;
      _block = block;
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.provider.displayName;
    return PopScope(
      canPop: !_checking,
      child: AnimatedSize(
        duration: AppTheme.dur2,
        child: _checking ? _checkingView(name) : _blockedView(name, _block!),
      ),
    );
  }

  Widget _checkingView(String name) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 130),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 18),
      child: Column(
        children: [
          FadeTransition(
            opacity: _pulse,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.plum100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.radar,
                size: 21,
                color: AppColors.plum700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            AppLocalizations.of(context).bookNowChecking,
            style: AppTextStyles.h3.copyWith(fontSize: 19, letterSpacing: 0),
          ),
          const SizedBox(height: 5),
          Text(
            AppLocalizations.of(context).bookNowConfirming(name),
            textAlign: TextAlign.center,
            style: AppTextStyles.micro.copyWith(
              fontSize: AppTextStyles.fsLabelSmPlus,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _blockedView(String name, BookNowBlock b) {
    final (eyebrow, title, body) = b.copy(AppLocalizations.of(context), name);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetWarnHead(icon: b.icon, eyebrow: eyebrow, title: title, body: body),
        const SizedBox(height: 18),
        AiwaButton(
          label: AppLocalizations.of(context).bookNowChooseScheduled,
          icon: LucideIcons.calendar,
          size: AiwaButtonSize.lg,
          fullWidth: true,
          onPressed: () => Navigator.of(context).pop(BookNowChoice.schedule),
        ),
        const SizedBox(height: 9),
        AiwaButton(
          label: AppLocalizations.of(context).bookNowSeeOthers,
          icon: LucideIcons.search,
          variant: AiwaButtonVariant.secondary,
          size: AiwaButtonSize.lg,
          fullWidth: true,
          onPressed: () =>
              Navigator.of(context).pop(BookNowChoice.alternatives),
        ),
      ],
    );
  }
}
