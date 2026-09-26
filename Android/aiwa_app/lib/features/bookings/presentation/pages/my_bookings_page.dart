import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_avatar.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/confirm_sheet.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/guest_locked_view.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/booking_entity.dart';
import '../bloc/booking_bloc.dart';
import '../bloc/booking_event.dart';
import '../bloc/booking_state.dart';

class MyBookingsPage extends StatelessWidget {
  const MyBookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (a, b) => (a is AuthAuthenticated) != (b is AuthAuthenticated),
      builder: (context, state) {
        if (state is! AuthAuthenticated) {
          return Scaffold(
            backgroundColor: AppColors.bone,
            body: const Padding(
              padding: EdgeInsets.only(bottom: 90),
              child: GuestLockedView(
                title: 'Your bookings live here',
                body:
                    'Sign in to book providers, track them on the way, and see your history.',
                icon: Icons.event_available_outlined,
              ),
            ),
          );
        }
        return const _MyBookingsView();
      },
    );
  }
}

class _MyBookingsView extends StatefulWidget {
  const _MyBookingsView();

  @override
  State<_MyBookingsView> createState() => _MyBookingsViewState();
}

class _MyBookingsViewState extends State<_MyBookingsView> {
  late BookingBloc _bloc;
  String _tab = 'upcoming';

  static const _pastStatuses = 'COMPLETED,CANCELLED,REJECTED,NO_SHOW';
  static const _liveStatuses = {
    'PENDING',
    'ACCEPTED',
    'ON_THE_WAY',
    'ARRIVED',
    'IN_PROGRESS',
  };

  @override
  void initState() {
    super.initState();
    _bloc = sl<BookingBloc>();
    _load();
  }

  void _load() {
    _bloc.add(
      _tab == 'upcoming'
          ? const BookingLoadMyEvent()
          : const BookingLoadMyEvent(status: _pastStatuses),
    );
  }

  void _switchTab(String tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    _load();
  }

  Future<void> _confirmCancel(BookingEntity b) async {
    final ok = await showConfirmSheet(
      context,
      eyebrow: 'Cancel booking',
      title: 'Cancel ${b.serviceName}?',
      body:
          '${b.displayProviderName} will be notified right away. This can’t be undone.',
      confirmLabel: 'Cancel booking',
      cancelLabel: 'Keep it',
    );
    if (ok) _bloc.add(BookingCancelEvent(b.id));
  }

  Future<void> _directions(BookingEntity b) async {
    final address = b.providerAddress;
    if (address == null || address.isEmpty) return;
    final uri = Uri.parse(
      'https://maps.google.com/?q=${Uri.encodeComponent(address)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocListener<BookingBloc, BookingState>(
        bloc: _bloc,
        listener: (context, state) {
          if (state is BookingCancelled) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Booking cancelled')));
            _load();
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.bone,
          body: RefreshIndicator(
            color: AppColors.plum700,
            onRefresh: () async => _load(),
            child: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(
                  child: PageTitle(
                    eyebrow: 'Your appointments',
                    title: 'Bookings',
                  ),
                ),
                SliverToBoxAdapter(
                  child: _UnderlineTabs(
                    tabs: const [('upcoming', 'Upcoming'), ('past', 'Past')],
                    active: _tab,
                    onChanged: _switchTab,
                  ),
                ),
                BlocBuilder<BookingBloc, BookingState>(
                  bloc: _bloc,
                  builder: (context, state) => _buildBody(state),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BookingState state) {
    const pad = EdgeInsets.fromLTRB(AppTheme.gutter, 14, AppTheme.gutter, 0);
    if (state is BookingError) {
      return SliverToBoxAdapter(
        child: ErrorState(body: state.message, onRetry: _load),
      );
    }
    if (state is! BookingListLoaded) {
      return const SliverPadding(
        padding: pad,
        sliver: SliverToBoxAdapter(child: SkeletonList(count: 3)),
      );
    }
    final bookings = _tab == 'upcoming'
        ? state.bookings.where((b) => _liveStatuses.contains(b.status)).toList()
        : state.bookings;
    if (bookings.isEmpty) {
      final upcoming = _tab == 'upcoming';
      return SliverToBoxAdapter(
        child: EmptyState(
          icon: upcoming
              ? Icons.calendar_month_outlined
              : Icons.history_rounded,
          title: upcoming ? 'Nothing booked yet' : 'No past appointments',
          subtitle: upcoming
              ? 'When you book a provider, it shows up here so you can track them on the way.'
              : 'Once an appointment is finished it moves here, ready to re-book in a tap.',
          actionLabel: upcoming ? 'Find a provider' : null,
          onAction: upcoming ? () => context.go(AppRoutes.search) : null,
        ),
      );
    }
    return SliverPadding(
      padding: pad,
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((ctx, i) {
          if (i == bookings.length) {
            return state.hasMore
                ? Center(
                    child: AiwaButton(
                      label: 'Load more',
                      variant: AiwaButtonVariant.ghost,
                      size: AiwaButtonSize.sm,
                      onPressed: () => _bloc.add(BookingLoadMoreEvent()),
                    ),
                  )
                : const EndOfList();
          }
          final b = bookings[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _BookingCard(
              booking: b,
              index: i,
              onCancel: () => _confirmCancel(b),
              onDirections: () => _directions(b),
              onReview: () => context.push('/review/${b.id}', extra: b),
              onRebook: () => context.push('/provider/${b.providerId}'),
            ),
          );
        }, childCount: bookings.length + 1),
      ),
    );
  }
}

class _UnderlineTabs extends StatelessWidget {
  final List<(String, String)> tabs;
  final String active;
  final ValueChanged<String> onChanged;

  const _UnderlineTabs({
    required this.tabs,
    required this.active,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        8,
        AppTheme.gutter,
        0,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: tabs.map((t) {
          final on = t.$1 == active;
          return GestureDetector(
            onTap: () => onChanged(t.$1),
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
                t.$2,
                style: AppTextStyles.label.copyWith(
                  fontSize: 14,
                  color: on ? AppColors.plum700 : AppColors.ink3,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingEntity booking;
  final int index;
  final VoidCallback onCancel;
  final VoidCallback onDirections;
  final VoidCallback onReview;
  final VoidCallback onRebook;

  const _BookingCard({
    required this.booking,
    required this.index,
    required this.onCancel,
    required this.onDirections,
    required this.onReview,
    required this.onRebook,
  });

  String get _when {
    final t = booking.scheduledTime.length >= 5
        ? booking.scheduledTime.substring(0, 5)
        : booking.scheduledTime;
    try {
      final d = DateTime.parse(booking.scheduledDate);
      return '${DateFormat('EEE, MMM d').format(d)} · $t';
    } catch (_) {
      return '${booking.scheduledDate} · $t';
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final hasAddress =
        b.providerAddress != null && b.providerAddress!.isNotEmpty;
    final metaStyle = AppTextStyles.micro.copyWith(
      fontSize: 12,
      color: AppColors.ink2,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppTheme.shadow1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AiwaAvatar(
                name: b.displayProviderName,
                size: 42,
                imageUrl: b.providerImageUrl,
                palette:
                    AvatarPalette.values[index % AvatarPalette.values.length],
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
                      style: AppTextStyles.h4.copyWith(
                        fontSize: 18,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      b.serviceName,
                      style: AppTextStyles.micro.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(status: b.status),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _Meta(
                icon: Icons.calendar_today_outlined,
                text: _when,
                style: metaStyle,
              ),
              if (hasAddress)
                _Meta(
                  icon: Icons.location_on_outlined,
                  text: b.providerAddress!,
                  style: metaStyle,
                ),
            ],
          ),
          if (b.status == 'CANCELLED' ||
              b.status == 'NO_SHOW' ||
              b.status == 'REJECTED') ...[
            const SizedBox(height: 12),
            _ReasonBox(
              icon: b.status == 'NO_SHOW'
                  ? Icons.person_off_outlined
                  : Icons.cancel_outlined,
              title: b.status == 'NO_SHOW'
                  ? 'Marked no-show'
                  : b.status == 'REJECTED'
                  ? 'Rejected by provider'
                  : 'Booking cancelled',
              body: b.status == 'REJECTED'
                  ? 'The provider couldn’t take this slot. Try another time or provider.'
                  : null,
            ),
          ],
          if (b.canCancel || hasAddress && _isLive(b.status)) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (b.canCancel)
                  Expanded(
                    child: AiwaButton(
                      label: 'Cancel',
                      variant: AiwaButtonVariant.secondary,
                      size: AiwaButtonSize.sm,
                      fullWidth: true,
                      onPressed: onCancel,
                    ),
                  ),
                if (b.canCancel && hasAddress) const SizedBox(width: 8),
                if (hasAddress)
                  Expanded(
                    child: AiwaButton(
                      label: 'Directions',
                      icon: Icons.map_outlined,
                      size: AiwaButtonSize.sm,
                      fullWidth: true,
                      onPressed: onDirections,
                    ),
                  ),
              ],
            ),
          ],
          if (b.status == 'COMPLETED') ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AiwaButton(
                    label: 'Re-book',
                    variant: AiwaButtonVariant.ghost,
                    size: AiwaButtonSize.sm,
                    fullWidth: true,
                    onPressed: onRebook,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AiwaButton(
                    label: 'Leave a review',
                    icon: Icons.star_rounded,
                    size: AiwaButtonSize.sm,
                    fullWidth: true,
                    onPressed: onReview,
                  ),
                ),
              ],
            ),
          ],
          if (b.status == 'REJECTED') ...[
            const SizedBox(height: 14),
            AiwaButton(
              label: 'See alternatives',
              variant: AiwaButtonVariant.secondary,
              size: AiwaButtonSize.sm,
              fullWidth: true,
              onPressed: () => context.go(AppRoutes.search),
            ),
          ],
        ],
      ),
    );
  }

  static bool _isLive(String status) => const {
    'PENDING',
    'ACCEPTED',
    'ON_THE_WAY',
    'ARRIVED',
    'IN_PROGRESS',
  }.contains(status);
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  final TextStyle style;

  const _Meta({required this.icon, required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.ink2),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(
            text,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Cancellation / rejection note inside a booking card (danger tint).
class _ReasonBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;

  const _ReasonBox({required this.icon, required this.title, this.body});

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.micro.copyWith(
      fontSize: 12,
      color: AppColors.danger700,
      height: 1.45,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.danger100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 14, color: AppColors.danger700),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: style.copyWith(fontWeight: FontWeight.w600)),
                if (body != null) ...[
                  const SizedBox(height: 2),
                  Text(body!, style: style.copyWith(color: AppColors.ink2)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
