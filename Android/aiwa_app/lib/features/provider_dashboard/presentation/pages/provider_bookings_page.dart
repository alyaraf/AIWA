import 'package:dartz/dartz.dart' hide State;
import 'package:flutter/material.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_avatar.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../../domain/repositories/dashboard_repository.dart';
import 'dashboard_page.dart';
import 'package:aiwa_app/l10n/l10n.dart';

/// Provider Bookings tab — `ProviderBookings` (provider-screens.jsx:145-190).
class ProviderBookingsPage extends StatefulWidget {
  const ProviderBookingsPage({super.key});

  @override
  State<ProviderBookingsPage> createState() => _ProviderBookingsPageState();
}

class _ProviderBookingsPageState extends State<ProviderBookingsPage> {
  /// Tabs filter client-side: the backend ignores `status`.
  static const _tabs = [
    {'PENDING'},
    {'ACCEPTED', 'ON_THE_WAY', 'ARRIVED', 'IN_PROGRESS'},
    {'COMPLETED', 'CANCELLED', 'REJECTED', 'NO_SHOW', 'EXPIRED'},
  ];

  var _tab = 0;
  late Future<Either<Failure, PagedData<BookingEntity>>> _load = _fetch();

  Future<Either<Failure, PagedData<BookingEntity>>> _fetch() =>
      sl<DashboardRepository>().getProviderBookings(
        size: providerBookingsPageSize,
      );

  void _reload() => setState(() => _load = _fetch());

  @override
  void initState() {
    super.initState();
    providerBookingsChanged.addListener(_reload);
  }

  @override
  void dispose() {
    providerBookingsChanged.removeListener(_reload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bone,
      body: CustomScrollView(
        physics: AiwaRefresh.physics,
        slivers: [
          AiwaRefresh(onRefresh: () async => _reload()),
          SliverToBoxAdapter(
            child: PageTitle(
              eyebrow: AppLocalizations.of(context).provBookingsEyebrow,
              title: AppLocalizations.of(context).bookingsTitle,
              bottom: 8,
            ),
          ),
          SliverToBoxAdapter(child: _tabRow()),
          FutureBuilder(
            future: _load,
            builder: (context, snap) {
              final r = snap.data;
              if (r == null) {
                return const SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    AppTheme.gutter,
                    14,
                    AppTheme.gutter,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(child: SkeletonList(count: 3)),
                );
              }
              return r.fold(
                (f) => SliverToBoxAdapter(
                  child: ErrorState(
                    body: AppLocalizations.of(context).error(f.message),
                    onRetry: _reload,
                    compact: true,
                  ),
                ),
                (page) {
                  final list = page.content
                      .where((b) => _tabs[_tab].contains(b.status))
                      .toList();
                  // Past reads newest first; the API sorts oldest first.
                  if (_tab == 2) {
                    list.sort(
                      (a, b) =>
                          b.scheduledDateTime.compareTo(a.scheduledDateTime),
                    );
                  }
                  if (list.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text(
                          AppLocalizations.of(context).provNothingHere,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.meta,
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.gutter,
                      14,
                      AppTheme.gutter,
                      0,
                    ),
                    sliver: SliverList.separated(
                      itemCount: list.length,
                      itemBuilder: (_, i) => _BookingRow(booking: list[i]),
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                    ),
                  );
                },
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _tabRow() => Container(
    padding: const EdgeInsets.fromLTRB(AppTheme.gutter, 14, AppTheme.gutter, 0),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.divider)),
    ),
    child: Row(
      children: [
        for (var i = 0; i < _tabs.length; i++)
          GestureDetector(
            onTap: () => setState(() => _tab = i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: AppTheme.dur2,
              margin: const EdgeInsetsDirectional.only(end: 18),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: i == _tab ? AppColors.plum700 : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                [
                  AppLocalizations.of(context).provTabPending,
                  AppLocalizations.of(context).provTabUpcoming,
                  AppLocalizations.of(context).provTabPast,
                ][i],
                style: AppTextStyles.label.copyWith(
                  fontSize: 14,
                  color: i == _tab ? AppColors.plum700 : AppColors.ink3,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Compact row: avatar, name, service · duration, date; pill over price.
class _BookingRow extends StatelessWidget {
  final BookingEntity booking;
  const _BookingRow({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final l = AppLocalizations.of(context);
    final customer = b.customerName ?? l.commonCustomer;
    return Material(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openProviderBooking(context, b),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              AiwaAvatar(name: customer, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${b.serviceName} · ${l.durationLabel(b.serviceDurationMinutes)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.micro.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                          color: AppColors.ink3,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            l.relativeWhen(b.scheduledDate, b.scheduledTime),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.micro.copyWith(
                              fontSize: 12,
                              color: AppColors.ink2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusPill(status: b.status),
                  const SizedBox(height: 6),
                  Text(
                    l.egp(b.servicePrice),
                    style: AppTextStyles.h4.copyWith(fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
