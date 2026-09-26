import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../domain/entities/notification_entity.dart';
import '../bloc/notification_bloc.dart';
import '../bloc/notification_event.dart';
import '../bloc/notification_state.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationBloc>().add(NotificationLoadEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bone,
      body: BlocBuilder<NotificationBloc, NotificationState>(
        builder: (context, state) {
          final unread = state is NotificationLoaded ? state.unreadCount : 0;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: ScreenHeader(
                  eyebrow: 'Inbox',
                  titleSuffix: unread > 0 ? '· $unread new' : null,
                  titleSize: 24,
                  title: 'Notifications',
                  onBack: () => context.pop(),
                  trailing: unread > 0
                      ? GestureDetector(
                          onTap: () => context.read<NotificationBloc>().add(
                            NotificationMarkAllReadEvent(),
                          ),
                          child: Text(
                            'Mark all read',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.plum700,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
              ..._buildBody(state),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildBody(NotificationState state) {
    if (state is NotificationError) {
      return [
        SliverToBoxAdapter(
          child: ErrorState(
            body: state.message,
            onRetry: () =>
                context.read<NotificationBloc>().add(NotificationLoadEvent()),
          ),
        ),
      ];
    }
    if (state is! NotificationLoaded) {
      return const [
        SliverPadding(
          padding: EdgeInsets.all(AppTheme.gutter),
          sliver: SliverToBoxAdapter(child: SkeletonList(count: 4)),
        ),
      ];
    }
    if (state.notifications.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.notifications_none_rounded,
            title: "You're all caught up",
            subtitle:
                "Booking updates, reviews and news from AIWA will show up here.",
          ),
        ),
      ];
    }

    final now = DateTime.now();
    bool isToday(DateTime d) {
      final l = d.toLocal();
      return l.year == now.year && l.month == now.month && l.day == now.day;
    }

    final today = state.notifications
        .where((n) => isToday(n.createdAt))
        .toList();
    final earlier = state.notifications
        .where((n) => !isToday(n.createdAt))
        .toList();

    Widget group(String label, List<NotificationEntity> items) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.gutter,
                ),
                child: EyebrowLabel(label),
              ),
              const SizedBox(height: 8),
              ...items.map(
                (n) => _NotificationRow(
                  n: n,
                  onTap: () {
                    if (!n.read) {
                      context.read<NotificationBloc>().add(
                        NotificationMarkReadEvent(n.id),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    return [
      if (today.isNotEmpty) group('Today', today),
      if (earlier.isNotEmpty) group('Earlier', earlier),
      if (state.hasMore)
        SliverToBoxAdapter(
          child: Center(
            child: TextButton(
              onPressed: () => context.read<NotificationBloc>().add(
                NotificationLoadMoreEvent(),
              ),
              child: const Text('Load more'),
            ),
          ),
        ),
    ];
  }
}

class _NotificationRow extends StatelessWidget {
  final NotificationEntity n;
  final VoidCallback onTap;

  const _NotificationRow({required this.n, required this.onTap});

  IconData get _icon {
    final t = n.type.toUpperCase();
    if (t.contains('BOOKING') || t.contains('STATUS')) {
      return Icons.event_available_outlined;
    }
    if (t.contains('PAYMENT') || t.contains('SETTLEMENT')) {
      return Icons.receipt_long_outlined;
    }
    if (t.contains('REVIEW')) return Icons.star_outline_rounded;
    if (t.contains('VERIF')) return Icons.verified_outlined;
    if (t.contains('SUPPORT') || t.contains('CHAT')) {
      return Icons.chat_bubble_outline_rounded;
    }
    if (t.contains('TERMS') || t.contains('POLICY')) {
      return Icons.description_outlined;
    }
    if (t.contains('PROMO')) return Icons.auto_awesome_outlined;
    return Icons.notifications_none_rounded;
  }

  String get _when {
    final d = n.createdAt.toLocal();
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return DateFormat('d MMM').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final unread = !n.read;
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTheme.dur2,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.gutter,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: unread ? AppColors.plum100 : Colors.transparent,
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Icon(_icon, size: 18, color: AppColors.plum700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: AppTextStyles.label.copyWith(
                            fontSize: 14,
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(_when, style: AppTextStyles.micro),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    n.message,
                    style: AppTextStyles.micro.copyWith(
                      fontSize: 12.5,
                      color: AppColors.ink2,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            if (unread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 8, top: 14),
                decoration: BoxDecoration(
                  color: AppColors.rose500,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
