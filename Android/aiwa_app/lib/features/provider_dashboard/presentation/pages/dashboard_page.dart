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
import '../../../../shared/widgets/confirm_sheet.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late DashboardBloc _bloc;

  static const _filters = [
    ('PENDING', 'Pending'),
    ('ACCEPTED', 'Upcoming'),
    ('COMPLETED', 'Done'),
    ('CANCELLED', 'Cancelled'),
  ];

  @override
  void initState() {
    super.initState();
    _bloc = sl<DashboardBloc>();
    _bloc.add(DashboardLoadEvent());
  }

  Future<void> _reject(BookingEntity b) async {
    final reason = TextEditingController();
    final ok = await showConfirmSheet(
      context,
      eyebrow: 'Decline request',
      title: 'Decline ${b.serviceName}?',
      body:
          'The customer is told right away and can pick another time or provider.',
      confirmLabel: 'Decline',
      input: reason,
      inputHint: 'Reason (optional) — e.g. fully booked at this time',
    );
    if (ok) _bloc.add(DashboardRejectBookingEvent(b.id, reason.text.trim()));
    // The sheet's field stays mounted until its exit animation finishes.
    Future.delayed(const Duration(seconds: 1), reason.dispose);
  }

  Future<void> _noShow(BookingEntity b) async {
    final ok = await showConfirmSheet(
      context,
      eyebrow: 'Mark no-show',
      title: 'Customer didn’t show up?',
      body: 'This is recorded on the booking and frees the slot.',
      confirmLabel: 'Mark no-show',
      icon: Icons.person_off_outlined,
    );
    if (ok) _bloc.add(DashboardNoShowEvent(b.id));
  }

  Future<void> _signOut() async {
    final ok = await showConfirmSheet(
      context,
      eyebrow: 'Sign out',
      title: 'Sign out of AIWA?',
      confirmLabel: 'Sign out',
      icon: Icons.logout_rounded,
    );
    if (!ok || !mounted) return;
    context.read<AuthBloc>().add(AuthLogoutEvent());
    context.go(AppRoutes.splash);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: AppColors.bone,
        body: BlocBuilder<DashboardBloc, DashboardState>(
          bloc: _bloc,
          builder: (context, state) {
            if (state is DashboardError) {
              return ErrorState(
                body: state.message,
                onRetry: () => _bloc.add(DashboardLoadEvent()),
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
            return RefreshIndicator(
              color: AppColors.plum700,
              onRefresh: () async => _bloc.add(DashboardLoadEvent()),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(state.stats)),
                  if (state.stats.pendingBookings > 0)
                    SliverToBoxAdapter(
                      child: _PendingCallout(
                        count: state.stats.pendingBookings,
                        onTap: () => _bloc.add(
                          const DashboardFilterStatusEvent('PENDING'),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(child: _buildFilter(state.filterStatus)),
                  if (state.bookings.isEmpty)
                    SliverToBoxAdapter(
                      child: EmptyState(
                        icon: Icons.event_available_outlined,
                        title: state.filterStatus == 'PENDING'
                            ? 'No new requests'
                            : 'Nothing here yet',
                        subtitle: state.filterStatus == 'PENDING'
                            ? 'New booking requests will appear here — reply within 30 minutes to keep your top rating.'
                            : 'Bookings in this status will show up here.',
                        compact: true,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.gutter,
                        14,
                        AppTheme.gutter,
                        0,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _RequestCard(
                              booking: state.bookings[i],
                              index: i,
                              onAccept: (id) =>
                                  _bloc.add(DashboardAcceptBookingEvent(id)),
                              onReject: _reject,
                              onComplete: (id) =>
                                  _bloc.add(DashboardCompleteBookingEvent(id)),
                              onNoShow: _noShow,
                              onOnTheWay: (id) =>
                                  _bloc.add(DashboardOnTheWayEvent(id)),
                              onArrived: (id) =>
                                  _bloc.add(DashboardArrivedEvent(id)),
                              onInProgress: (id) =>
                                  _bloc.add(DashboardInProgressEvent(id)),
                            ),
                          ),
                          childCount: state.bookings.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(DashboardStats stats) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, auth) {
        final user = auth is AuthAuthenticated ? auth.user : null;
        final first = user?.fullName.split(' ').first;
        final verified = user?.providerProfile?.isApproved ?? false;
        return Container(
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(gradient: AppTheme.heroGradient),
          child: Stack(
            children: [
              Positioned(
                right: -40,
                top: -50,
                child: AiwaGlow(
                  size: 260,
                  color: AppColors.rose300,
                  opacity: 0.3,
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
                                first != null ? 'Hello, $first' : 'Hello',
                                color: AppColors.rose300,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Today's schedule.",
                                style: AppTextStyles.h2.copyWith(
                                  color: AppColors.bone,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AiwaIconButton(
                          icon: Icons.logout_rounded,
                          variant: AiwaIconButtonVariant.glass,
                          size: 36,
                          onTap: _signOut,
                        ),
                        const SizedBox(width: 10),
                        AiwaAvatar(
                          name: user?.fullName ?? '?',
                          size: 44,
                          palette: AvatarPalette.rose,
                          verified: verified,
                          imageUrl: user?.profileImageUrl,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        _StatTile(
                          value: '${stats.pendingBookings}',
                          label: 'Pending',
                        ),
                        const SizedBox(width: 8),
                        _StatTile(
                          value: NumberFormat.compact(
                            locale: 'en',
                          ).format(stats.totalRevenue),
                          label: 'EGP earned',
                        ),
                        const SizedBox(width: 8),
                        _StatTile(
                          value: stats.averageRating > 0
                              ? stats.averageRating.toStringAsFixed(1)
                              : '—',
                          label: '${stats.totalReviews} reviews',
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
      },
    );
  }

  Widget _buildFilter(String? activeStatus) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((f) {
            final on = activeStatus == f.$1;
            return GestureDetector(
              onTap: () => _bloc.add(DashboardFilterStatusEvent(f.$1)),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: AppTheme.dur2,
                margin: const EdgeInsets.only(right: 18),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: on ? AppColors.plum700 : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  f.$2,
                  style: AppTextStyles.label.copyWith(
                    fontSize: 14,
                    color: on ? AppColors.plum700 : AppColors.ink3,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bone.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (star) ...[
                  Icon(Icons.star_rounded, size: 15, color: AppColors.gold300),
                  const SizedBox(width: 3),
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
                letterSpacing: 0.8,
                color: AppColors.rose300,
              ),
            ),
          ],
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.warn500.withOpacity(0.2)),
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
                Icons.alarm_rounded,
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
                    count == 1
                        ? '1 new booking request'
                        : '$count new booking requests',
                    style: AppTextStyles.label.copyWith(
                      fontSize: 14,
                      color: AppColors.warn700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Reply within 30 minutes to keep your top rating.',
                    style: AppTextStyles.micro.copyWith(
                      fontSize: 12,
                      color: AppColors.warn700.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.warn700,
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final BookingEntity booking;
  final int index;
  final void Function(String) onAccept;
  final void Function(BookingEntity) onReject;
  final void Function(String) onComplete;
  final void Function(BookingEntity) onNoShow;
  final void Function(String) onOnTheWay;
  final void Function(String) onArrived;
  final void Function(String) onInProgress;

  const _RequestCard({
    required this.booking,
    required this.index,
    required this.onAccept,
    required this.onReject,
    required this.onComplete,
    required this.onNoShow,
    required this.onOnTheWay,
    required this.onArrived,
    required this.onInProgress,
  });

  String get _when {
    final t = booking.scheduledTime.length >= 5
        ? booking.scheduledTime.substring(0, 5)
        : booking.scheduledTime;
    try {
      final d = DateTime.parse(booking.scheduledDate);
      final now = DateTime.now();
      final isToday =
          d.year == now.year && d.month == now.month && d.day == now.day;
      return '${isToday ? 'Today' : DateFormat('EEE, MMM d').format(d)} · $t';
    } catch (_) {
      return '${booking.scheduledDate} · $t';
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final customer = b.providerName.isEmpty ? 'Customer' : b.providerName;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppTheme.shadow1,
      ),
      child: Column(
        children: [
          Row(
            children: [
              AiwaAvatar(
                name: customer,
                size: 42,
                palette:
                    AvatarPalette.values[index % AvatarPalette.values.length],
              ),
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
                      '${b.serviceName} · ${b.serviceDurationMinutes} min',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.micro.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
                Icon(
                  Icons.calendar_today_outlined,
                  size: 13,
                  color: AppColors.ink3,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    _when,
                    style: AppTextStyles.micro.copyWith(
                      fontSize: 12,
                      color: AppColors.ink2,
                    ),
                  ),
                ),
                Text(
                  'EGP ${NumberFormat.decimalPattern('en').format(b.servicePrice.round())}',
                  style: AppTextStyles.h4.copyWith(fontSize: 18),
                ),
              ],
            ),
          ),
          ..._actions(),
        ],
      ),
    );
  }

  List<Widget> _actions() {
    final b = booking;
    Widget pair(Widget a, Widget c) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(child: a),
          const SizedBox(width: 8),
          Expanded(child: c),
        ],
      ),
    );
    Widget single(String label, IconData icon, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AiwaButton(
        label: label,
        icon: icon,
        size: AiwaButtonSize.sm,
        fullWidth: true,
        onPressed: onTap,
      ),
    );

    switch (b.status) {
      case 'PENDING':
        return [
          pair(
            AiwaButton(
              label: 'Decline',
              variant: AiwaButtonVariant.secondary,
              size: AiwaButtonSize.sm,
              fullWidth: true,
              onPressed: () => onReject(b),
            ),
            AiwaButton(
              label: 'Accept',
              icon: Icons.check_rounded,
              size: AiwaButtonSize.sm,
              fullWidth: true,
              onPressed: () => onAccept(b.id),
            ),
          ),
        ];
      case 'ACCEPTED':
        return [
          single(
            'On my way',
            Icons.navigation_outlined,
            () => onOnTheWay(b.id),
          ),
        ];
      case 'ON_THE_WAY':
        return [
          single(
            "I've arrived",
            Icons.location_on_outlined,
            () => onArrived(b.id),
          ),
        ];
      case 'ARRIVED':
        return [
          single(
            'Start service',
            Icons.play_arrow_rounded,
            () => onInProgress(b.id),
          ),
        ];
      case 'IN_PROGRESS':
        return [
          pair(
            AiwaButton(
              label: 'No-show',
              variant: AiwaButtonVariant.secondary,
              size: AiwaButtonSize.sm,
              fullWidth: true,
              onPressed: () => onNoShow(b),
            ),
            AiwaButton(
              label: 'Mark completed',
              icon: Icons.check_rounded,
              size: AiwaButtonSize.sm,
              fullWidth: true,
              onPressed: () => onComplete(b.id),
            ),
          ),
        ];
      default:
        return const [];
    }
  }
}
