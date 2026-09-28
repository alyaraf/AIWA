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
import 'package:aiwa_app/l10n/l10n.dart';

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
            body: Padding(
              padding: const EdgeInsets.only(bottom: 90),
              child: GuestLockedView(
                title: AppLocalizations.of(context).bookingsGuestTitle,
                body: AppLocalizations.of(context).bookingsGuestBody,
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

  static const _pastStatuses = 'COMPLETED,CANCELLED,REJECTED,NO_SHOW,EXPIRED';
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

  /// Live -> Tracking, expired -> Expired booking (prototype.jsx:700-704).
  /// Reloads on return: the booking may have moved on meanwhile.
  Future<void> _open(BookingEntity b, String screen) async {
    await context.push('/booking/${b.id}/$screen', extra: b);
    if (mounted) _load();
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
      child: Scaffold(
        backgroundColor: AppColors.bone,
        body: CustomScrollView(
          physics: AiwaRefresh.physics,
          slivers: [
            AiwaRefresh(onRefresh: () async => _load()),
            SliverToBoxAdapter(
              child: PageTitle(
                eyebrow: AppLocalizations.of(context).bookingsEyebrow,
                title: AppLocalizations.of(context).bookingsTitle,
                letterSpacing: 0,
              ),
            ),
            SliverToBoxAdapter(
              child: _UnderlineTabs(
                tabs: [
                  ('upcoming', AppLocalizations.of(context).bookingsUpcoming),
                  ('past', AppLocalizations.of(context).bookingsPast),
                ],
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
    );
  }

  Widget _buildBody(BookingState state) {
    final l = AppLocalizations.of(context);
    const pad = EdgeInsets.fromLTRB(AppTheme.gutter, 14, AppTheme.gutter, 0);
    if (state is BookingError) {
      return SliverToBoxAdapter(
        child: ErrorState(body: l.error(state.message), onRetry: _load),
      );
    }
    if (state is! BookingListLoaded) {
      return const SliverPadding(
        padding: pad,
        sliver: SliverToBoxAdapter(child: SkeletonList(count: 3)),
      );
    }
    // /bookings/my ignores `status`, so both tabs filter client-side.
    final bookings = state.bookings
        .where(
          (b) => _tab == 'upcoming'
              ? _liveStatuses.contains(b.status)
              : _pastStatuses.split(',').contains(b.status),
        )
        .toList();
    if (bookings.isEmpty) {
      final upcoming = _tab == 'upcoming';
      return SliverPadding(
        padding: pad,
        sliver: SliverToBoxAdapter(
          child: EmptyState(
            icon: upcoming
                ? Icons.edit_calendar_outlined
                : Icons.history_rounded,
            title: upcoming
                ? l.bookingsEmptyUpcomingTitle
                : l.bookingsEmptyPastTitle,
            subtitle: upcoming
                ? l.bookingsEmptyUpcomingBody
                : l.bookingsEmptyPastBody,
            actionLabel: upcoming ? l.bookingsFindProvider : null,
            onAction: upcoming ? () => context.go(AppRoutes.search) : null,
          ),
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
                      label: l.commonLoadMore,
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
              onTap: _liveStatuses.contains(b.status)
                  ? () => _open(b, 'track')
                  : b.status == 'EXPIRED'
                  ? () => _open(b, 'expired')
                  : null,
              onTrack: () => _open(b, 'track'),
              onAlternatives: () => _open(b, 'rejected'),
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
              margin: const EdgeInsetsDirectional.only(end: 24),
              // Underline sits over the row's 1px divider (marginBottom -1).
              transform: Matrix4.translationValues(0, 1, 0),
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
  final VoidCallback? onTap;
  final VoidCallback onTrack;
  final VoidCallback onAlternatives;
  final VoidCallback onDirections;
  final VoidCallback onReview;
  final VoidCallback onRebook;

  const _BookingCard({
    required this.booking,
    required this.onTap,
    required this.onTrack,
    required this.onAlternatives,
    required this.onDirections,
    required this.onReview,
    required this.onRebook,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final b = booking;
    final hasAddress =
        b.providerAddress != null && b.providerAddress!.isNotEmpty;
    final metaStyle = AppTextStyles.micro.copyWith(
      fontSize: 12,
      color: AppColors.ink2,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppColors.divider),
          // 0 1px 2px rgba(74,31,56,.04) (screens.jsx:537).
          boxShadow: [
            BoxShadow(
              color: AppColors.plum700.withValues(alpha: .04),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      AiwaAvatar(
                        name: b.displayProviderName,
                        size: 42,
                        imageUrl: b.providerImageUrl,
                        verified: b.providerVerified,
                        palette: AiwaAvatar.paletteFor(b.providerId),
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
                  text: l.formatWhen(b.scheduledDate, b.scheduledTime),
                  style: metaStyle,
                ),
                // Kit shows distance; fall back to the address without it.
                if (b.providerDistanceKm != null || hasAddress)
                  _Meta(
                    icon: Icons.location_on_outlined,
                    text: b.providerDistanceKm != null
                        ? l.distanceKm(b.providerDistanceKm!.toStringAsFixed(1))
                        : b.providerAddress!,
                    style: metaStyle,
                  ),
              ],
            ),
            // Only with a reason to show (screens.jsx:552, 565).
            if ((b.status == 'CANCELLED' || b.status == 'NO_SHOW') &&
                    b.cancellationReason != null ||
                b.status == 'REJECTED' && b.rejectionReason != null) ...[
              const SizedBox(height: 12),
              _ReasonBox(
                icon: b.status == 'NO_SHOW'
                    ? Icons.person_off_outlined
                    : Icons.cancel_outlined,
                title: switch (b.status) {
                  'NO_SHOW' => l.bookingsNoShow,
                  'REJECTED' => l.bookingsRejectedByProvider,
                  _ => switch (b.cancelledBy) {
                    null || 'CUSTOMER' => l.bookingsCancelledByYou,
                    'PROVIDER' => l.bookingsCancelledByProvider,
                    final who => l.bookingsCancelledBy(who),
                  },
                },
                meta: b.status != 'REJECTED' && b.cancelledAt != null
                    ? ' · ${DateFormat('MMM d · h:mm a', l.localeName).format(b.cancelledAt!)}'
                    : null,
                body: switch (b.status == 'REJECTED'
                    ? b.rejectionReason
                    : b.cancellationReason) {
                  final r? => l.commonQuoted(r),
                  null => null,
                },
                footnote: b.status == 'CANCELLED' && b.penaltyApplied
                    ? l.bookingsPenaltyApplied
                    : null,
              ),
            ],
            if (_isLive(b.status)) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: AiwaButton(
                      label: l.bookingsTrack,
                      variant: AiwaButtonVariant.secondary,
                      size: AiwaButtonSize.sm,
                      fullWidth: true,
                      onPressed: onTrack,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AiwaButton(
                      label: l.bookingsDirections,
                      icon: Icons.map_outlined,
                      size: AiwaButtonSize.sm,
                      fullWidth: true,
                      onPressed: hasAddress ? onDirections : null,
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
                      label: l.bookingsRebook,
                      variant: AiwaButtonVariant.ghost,
                      size: AiwaButtonSize.sm,
                      fullWidth: true,
                      onPressed: onRebook,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AiwaButton(
                      label: l.bookingsLeaveReview,
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
                label: l.bookingsSeeAlternatives,
                variant: AiwaButtonVariant.secondary,
                size: AiwaButtonSize.sm,
                fullWidth: true,
                onPressed: onAlternatives,
              ),
            ],
          ],
        ),
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
  final String? meta;
  final String? body;
  final String? footnote;

  const _ReasonBox({
    required this.icon,
    required this.title,
    this.meta,
    this.body,
    this.footnote,
  });

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
                Text.rich(
                  TextSpan(
                    text: title,
                    style: style.copyWith(fontWeight: FontWeight.w600),
                    children: [
                      if (meta != null)
                        TextSpan(
                          text: meta,
                          style: style.copyWith(
                            fontWeight: FontWeight.w400,
                            color: AppColors.ink3,
                          ),
                        ),
                    ],
                  ),
                ),
                if (body != null) ...[
                  const SizedBox(height: 2),
                  Text(body!, style: style.copyWith(color: AppColors.ink2)),
                ],
                if (footnote != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    footnote!,
                    style: style.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
