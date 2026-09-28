import 'dart:ui' show ImageFilter;
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
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../shared/widgets/star_rating.dart';

/// Provider Today tab — `ProviderDashboard` (provider-screens.jsx:35-139).
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _bloc = sl<DashboardBloc>()..add(DashboardLoadEvent());

  void _reload() => _bloc.add(DashboardLoadEvent());

  @override
  void initState() {
    super.initState();
    providerBookingsChanged.addListener(_reload);
  }

  @override
  void dispose() {
    providerBookingsChanged.removeListener(_reload);
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bone,
      body: BlocBuilder<DashboardBloc, DashboardState>(
        bloc: _bloc,
        builder: (context, state) {
          if (state is DashboardError) {
            return ErrorState(
              body: AppLocalizations.of(context).error(state.message),
              onRetry: _reload,
            );
          }
          if (state is! DashboardLoaded) {
            return ListView(
              padding: EdgeInsets.zero,
              children: const [
                ShimmerBox(height: 230, radius: 0),
                Padding(
                  padding: EdgeInsets.all(AppTheme.gutter),
                  child: SkeletonList(count: 3),
                ),
              ],
            );
          }
          final pending = state.pending;
          final confirmed = state.stats.todayBookings
              .where((b) => _onTheBooks.contains(b.status))
              .toList();
          return CustomScrollView(
            physics: AiwaRefresh.physics,
            slivers: [
              AiwaRefresh(onRefresh: () async => _reload()),
              SliverToBoxAdapter(child: _Hero(stats: state.stats)),
              if (pending.isNotEmpty)
                SliverToBoxAdapter(
                  child: _PendingCallout(
                    count: pending.length,
                    onTap: () => context.go(AppRoutes.providerBookings),
                  ),
                ),
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: AppLocalizations.of(context).dashNewRequests,
                  action: AppLocalizations.of(
                    context,
                  ).dashPendingCount(pending.length),
                ),
              ),
              _list([for (final b in pending) _RequestCard(booking: b)]),
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: AppLocalizations.of(context).dashConfirmedToday,
                ),
              ),
              if (confirmed.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      AppLocalizations.of(context).dashNothingElse,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.meta,
                    ),
                  ),
                )
              else
                _list([for (final b in confirmed) _TodayRow(booking: b)]),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  static const _onTheBooks = {
    'ACCEPTED',
    'ON_THE_WAY',
    'ARRIVED',
    'IN_PROGRESS',
    'COMPLETED',
  };

  Widget _list(List<Widget> children) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
    sliver: SliverList.separated(
      itemCount: children.length,
      itemBuilder: (_, i) => children[i],
      separatorBuilder: (_, _) => const SizedBox(height: 10),
    ),
  );
}

/// Opens the provider booking detail; the list reloads via
/// [providerBookingsChanged] when something changes there.
void openProviderBooking(BuildContext context, BookingEntity b) =>
    context.push(AppRoutes.providerBooking(b.id), extra: b);

class _Hero extends StatelessWidget {
  final DashboardStats stats;
  const _Hero({required this.stats});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final user = auth is AuthAuthenticated ? auth.user : null;
    final first = user?.fullName.split(' ').first;
    final today = stats.todayBookings;
    final l = AppLocalizations.of(context);
    final egpToday = today
        .where(
          (b) => !const {'CANCELLED', 'REJECTED', 'EXPIRED'}.contains(b.status),
        )
        .fold<double>(0, (sum, b) => sum + b.servicePrice);
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(gradient: AppTheme.heroGradient),
      child: Stack(
        children: [
          // ponytail: intentional deviation (PROV-C6). The kit hard-codes
          // rgba(231,186,182,.3) in both palettes; we keep the gender-aware
          // rose300 token. Add AppColors.heroGlow if exact parity is required.
          // provider-screens.jsx:45 — circle at 80% 20%, transparent 55%.
          Positioned.fill(
            child: AiwaGlow.fill(
              center: const Alignment(.6, -.6),
              color: AppColors.rose300,
              opacity: .3,
              stop: .55,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppTheme.gutter,
              MediaQuery.paddingOf(context).top + 22,
              AppTheme.gutter,
              26,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          EyebrowLabel(
                            first != null
                                ? l.dashHelloName(first)
                                : l.dashHello,
                            color: AppColors.rose300,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l.dashTodaysSchedule,
                            style: AppTextStyles.h2.copyWith(
                              color: AppColors.bone,
                              height: 1.1,
                              letterSpacing: -0.26,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AiwaAvatar(
                      name: user?.fullName ?? '?',
                      size: 44,
                      palette: AvatarPalette.rose,
                      verified: user?.providerProfile?.isApproved ?? false,
                      imageUrl: user?.profileImageUrl,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    _StatTile(
                      value: NumberFormat.decimalPattern(
                        l.localeName,
                      ).format(today.length),
                      label: l.dashStatToday,
                    ),
                    const SizedBox(width: 8),
                    _StatTile(
                      value: NumberFormat.decimalPattern(
                        l.localeName,
                      ).format(egpToday.round()),
                      label: l.dashStatEgpToday,
                    ),
                    const SizedBox(width: 8),
                    _StatTile(
                      value: stats.averageRating > 0
                          ? stats.averageRating.toStringAsFixed(1)
                          : '—',
                      // BACKEND GAP: DashboardDto has no review count, so the
                      // kit's '312 reviews' reads 'Rating'.
                      label: l.dashStatRating,
                      star: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final bool star;

  const _StatTile({
    required this.value,
    required this.label,
    this.star = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.bone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radius14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (star) ...[
                      AiwaStar(size: 14, color: AppColors.gold300),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h2.copyWith(
                          fontSize: 24,
                          color: AppColors.bone,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSm.copyWith(
                    fontSize: 11,
                    letterSpacing: AppTextStyles.trackingWide * 11,
                    color: AppColors.rose300,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingCallout extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _PendingCallout({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          AppTheme.gutter,
          16,
          AppTheme.gutter,
          0,
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warn100,
          borderRadius: BorderRadius.circular(AppTheme.radius16),
          border: Border.all(color: AppColors.warn500.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.warn500,
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.alarmClock,
                size: 18,
                color: AppColors.paper,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).dashNewRequestsCount(count),
                    style: AppTextStyles.label.copyWith(
                      fontSize: 14,
                      color: AppColors.warn700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.of(context).dashReplyWithin,
                    style: AppTextStyles.micro.copyWith(
                      fontSize: 12,
                      color: AppColors.warn700.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRightDir,
              size: 18,
              color: AppColors.warn700,
            ),
          ],
        ),
      ),
    );
  }
}

/// 'New requests' card. Decline / Accept open the detail too, so the
/// provider sees the address and note before answering (PROV-05-V1).
class _RequestCard extends StatelessWidget {
  final BookingEntity booking;
  const _RequestCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final l = AppLocalizations.of(context);
    final customer = b.customerName ?? l.commonCustomer;
    void open() => openProviderBooking(context, b);
    return Material(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: open,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppColors.divider),
            // 0 1px 2px rgba(74,31,56,.04) (provider-screens.jsx:92).
            boxShadow: AppTheme.shadowHairline,
          ),
          child: Column(
            children: [
              Row(
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
                          style: AppTextStyles.label.copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${bidiIsolate(b.serviceName)} · ${l.durationLabel(b.serviceDurationMinutes)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.micro.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  StatusPill(status: b.status),
                ],
              ),
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.calendar, size: 13, color: AppColors.ink3),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        l.relativeWhen(b.scheduledDate, b.scheduledTime),
                        style: AppTextStyles.micro.copyWith(
                          fontSize: 12,
                          color: AppColors.ink2,
                        ),
                      ),
                    ),
                    Text(l.egp(b.servicePrice), style: AppTextStyles.h4),
                  ],
                ),
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
                      onPressed: open,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AiwaButton(
                      label: l.commonAccept,
                      icon: LucideIcons.check,
                      size: AiwaButtonSize.sm,
                      fullWidth: true,
                      onPressed: open,
                    ),
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

/// 'Confirmed today' row: info stripe, name, service, mono time. Not
/// tappable in the kit.
class _TodayRow extends StatelessWidget {
  final BookingEntity booking;
  const _TodayRow({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final l = AppLocalizations.of(context);
    final customer = b.customerName ?? l.commonCustomer;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(color: AppColors.divider),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: AppColors.info500,
                borderRadius: BorderRadius.circular(AppTheme.radiusXs),
              ),
            ),
            const SizedBox(width: 12),
            AiwaAvatar(name: customer, size: 40, palette: AvatarPalette.rose),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    customer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    b.serviceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.micro.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat(
                    'h:mm a',
                    l.localeName,
                  ).format(b.scheduledDateTime),
                  style: AppTextStyles.mono.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.plum900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.durationLabel(b.serviceDurationMinutes),
                  style: AppTextStyles.micro,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
