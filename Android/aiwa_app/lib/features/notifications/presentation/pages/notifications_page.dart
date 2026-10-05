import 'package:flutter/material.dart';
import '../../notification_routes.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
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
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
          final l = AppLocalizations.of(context);
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: ScreenHeader(
                  eyebrow: l.notifInbox,
                  titleSuffix: unread > 0 ? l.notifNewSuffix(unread) : null,
                  titleSize: 24,
                  titleHeight: 1.05,
                  title: l.ppNotifications,
                  onBack: () => context.pop(),
                  trailing: unread > 0
                      ? GestureDetector(
                          onTap: () => context.read<NotificationBloc>().add(
                            NotificationMarkAllReadEvent(),
                          ),
                          child: Text(
                            l.notifMarkAllRead,
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
    final l = AppLocalizations.of(context);
    if (state is NotificationError) {
      return [
        SliverToBoxAdapter(
          child: ErrorState(
            body: l.error(state.message),
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
      return [
        SliverToBoxAdapter(
          child: EmptyState(
            icon: LucideIcons.bell,
            title: l.notifCaughtUp,
            subtitle: l.notifCaughtUpBody,
          ),
        ),
      ];
    }

    final now = DateTime.now();
    bool isToday(DateTime d) {
      final t = d.toLocal();
      return t.year == now.year && t.month == now.month && t.day == now.day;
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
                    final auth = context.read<AuthBloc>().state;
                    final to = notificationTarget(
                      type: n.type,
                      bookingId: n.referenceId,
                      isProvider:
                          auth is AuthAuthenticated && auth.user.isProvider,
                    );
                    if (to != null) context.push(to);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    return [
      if (today.isNotEmpty) group(l.commonToday, today),
      if (earlier.isNotEmpty) group(l.notifEarlier, earlier),
      if (state.hasMore)
        SliverToBoxAdapter(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.loadMoreError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      l.error(state.loadMoreError!),
                      textAlign: TextAlign.center,
                    ),
                  ),
                TextButton(
                  // Disabled while a page is on its way: two taps no longer race.
                  onPressed: state.loadingMore
                      ? null
                      : () => context.read<NotificationBloc>().add(
                          NotificationLoadMoreEvent(),
                        ),
                  child: Text(l.commonLoadMore),
                ),
              ],
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
    if (t.contains('CONFIRMED') || t.contains('COMPLETED')) {
      return LucideIcons.circleCheck;
    }
    if (t.contains('BOOKING') || t.contains('STATUS')) {
      return LucideIcons.calendarCheck;
    }
    if (t.contains('DISPUTED')) return LucideIcons.triangleAlert;
    if (t.startsWith('SETTLEMENT') || t == 'COMMISSION_DUE') {
      return LucideIcons.banknote;
    }
    if (t.startsWith('MODERATION')) return LucideIcons.imageOff;
    if (t.contains('PAYMENT') || t.contains('SETTLEMENT')) {
      return LucideIcons.scrollText;
    }
    if (t.contains('REVIEW')) return LucideIcons.star;
    if (t.contains('VERIF')) return LucideIcons.badgeCheck;
    if (t.contains('SUPPORT') || t.contains('CHAT')) {
      return LucideIcons.messageCircle;
    }
    if (t.contains('TERMS') || t.contains('POLICY')) {
      return LucideIcons.fileText;
    }
    if (t.contains('PROMO')) return LucideIcons.sparkles;
    return LucideIcons.bell;
  }

  String _when(AppLocalizations l) {
    final d = n.createdAt.toLocal();
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return l.notifJustNow;
    if (diff.inMinutes < 60) return l.notifMinAgo(diff.inMinutes);
    if (diff.inHours < 24) return l.notifHrAgo(diff.inHours);
    if (diff.inDays == 1) return l.agoYesterday;
    if (diff.inDays < 7) return l.agoDays(diff.inDays);
    return DateFormat('d MMM', l.localeName).format(d);
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
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
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
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: AppTextStyles.label.copyWith(
                            fontSize: 14,
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _when(AppLocalizations.of(context)),
                        style: AppTextStyles.micro,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    n.message,
                    style: AppTextStyles.micro.copyWith(
                      fontSize: AppTextStyles.fsLabelSmPlus,
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
                margin: const EdgeInsetsDirectional.only(start: 12, top: 14),
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
