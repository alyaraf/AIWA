import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_avatar.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_icon_button.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../notifications/presentation/bloc/notification_bloc.dart';
import '../../../notifications/presentation/bloc/notification_event.dart';
import '../../../notifications/presentation/bloc/notification_state.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import '../widgets/category_tile.dart';
import '../widgets/provider_card.dart';
import '../widgets/provider_list_item.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late HomeBloc _homeBloc;

  static const _categories = [
    _Cat('HAIR', 'Hair', Icons.content_cut_rounded, 'plum'),
    _Cat('NAILS', 'Nails', Icons.back_hand_outlined, 'rose'),
    _Cat('SPA', 'Spa', Icons.spa_outlined, 'cream'),
    _Cat('MAKEUP', 'Makeup', Icons.brush_outlined, 'gold'),
    _Cat('LASHES', 'Lashes', Icons.visibility_outlined, 'rose'),
    _Cat('SKIN', 'Skin', Icons.water_drop_outlined, 'plum'),
    _Cat('MASSAGE', 'Massage', Icons.volunteer_activism_outlined, 'cream'),
    _Cat('ALL', 'All', Icons.auto_awesome_outlined, 'gold'),
  ];

  @override
  void initState() {
    super.initState();
    _homeBloc = sl<HomeBloc>();
    _loadData();
    if (context.read<AuthBloc>().state is AuthAuthenticated) {
      context.read<NotificationBloc>().add(NotificationGetUnreadCountEvent());
    }
  }

  Future<void> _loadData() async {
    double lat = 30.0444, lng = 31.2357;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm != LocationPermission.denied &&
            perm != LocationPermission.deniedForever) {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 5),
          );
          lat = pos.latitude;
          lng = pos.longitude;
        }
      }
    } catch (_) {}
    if (mounted) {
      _homeBloc.add(HomeLoadEvent(lat: lat, lng: lng));
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _homeBloc,
      child: Scaffold(
        backgroundColor: AppColors.bone,
        body: RefreshIndicator(
          color: AppColors.plum700,
          onRefresh: _loadData,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildSearchBar()),
              SliverToBoxAdapter(child: _buildHeroPromo()),
              SliverToBoxAdapter(child: _buildCategories()),
              BlocBuilder<HomeBloc, HomeState>(
                bloc: _homeBloc,
                builder: (context, state) {
                  if (state is HomeError) {
                    return SliverToBoxAdapter(
                      child: ErrorState(
                        body: state.message,
                        onRetry: _loadData,
                        compact: true,
                      ),
                    );
                  }
                  if (state is HomeLoaded) return _buildContent(state);
                  return _buildSkeletons();
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state is AuthAuthenticated ? state.user : null;
        final first = user?.fullName.split(' ').first;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppTheme.gutter,
            MediaQuery.paddingOf(context).top + 22,
            AppTheme.gutter,
            16,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EyebrowLabel(
                      first != null ? '$_greeting, $first' : _greeting,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Who's making you\nfeel new tonight?",
                      style: AppTextStyles.h2.copyWith(height: 1.1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              BlocBuilder<NotificationBloc, NotificationState>(
                builder: (context, nState) {
                  final count = nState is NotificationLoaded
                      ? nState.unreadCount
                      : 0;
                  return AiwaIconButton(
                    icon: Icons.notifications_none_rounded,
                    dot: count > 0,
                    onTap: () => user != null
                        ? context.push(AppRoutes.notifications)
                        : context.push(AppRoutes.authGate),
                  );
                },
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => context.go(AppRoutes.profile),
                child: AiwaAvatar(
                  name: user?.fullName ?? '?',
                  size: 42,
                  palette: AvatarPalette.rose,
                  imageUrl: user?.profileImageUrl,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        4,
        AppTheme.gutter,
        6,
      ),
      child: GestureDetector(
        onTap: () => context.go(AppRoutes.search),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: AppColors.plum700.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 18, color: AppColors.plum700),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Service or provider',
                  style: AppTextStyles.body.copyWith(color: AppColors.ink3),
                ),
              ),
              Container(width: 1, height: 20, color: AppColors.divider),
              const SizedBox(width: 10),
              Icon(Icons.location_on_outlined, size: 14, color: AppColors.plum700),
              const SizedBox(width: 5),
              Text(
                'Near me',
                style: AppTextStyles.label.copyWith(color: AppColors.plum700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroPromo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        20,
        AppTheme.gutter,
        6,
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: AppTheme.heroGradient,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -40,
              child: AiwaGlow(
                size: 180,
                color: AppColors.rose300,
                opacity: 0.4,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EyebrowLabel('This week · 20% off', color: AppColors.rose300),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(
                      'Bridal lookbook season',
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.bone,
                        fontSize: 24,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: Text(
                      'Top-rated makeup & lash artists, with package pricing.',
                      style: AppTextStyles.meta.copyWith(
                        color: AppColors.rose300,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AiwaButton(
                    label: 'Explore →',
                    variant: AiwaButtonVariant.accent,
                    size: AiwaButtonSize.sm,
                    onPressed: () =>
                        context.go('${AppRoutes.search}?category=MAKEUP'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Categories',
          action: 'See all',
          onAction: () => context.go(AppRoutes.search),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
          child: GridView.count(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.86,
            children: _categories
                .map(
                  (c) => CategoryTile(
                    label: c.label,
                    icon: c.icon,
                    palette: c.palette,
                    onTap: c.id == 'ALL'
                        ? () => context.go(AppRoutes.search)
                        : () => context.go(
                            '${AppRoutes.search}?category=${c.id}',
                          ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(HomeLoaded state) {
    if (state.trending.isEmpty && state.providers.isEmpty) {
      return SliverToBoxAdapter(
        child: EmptyState(
          icon: Icons.location_searching_rounded,
          title: 'Nobody nearby yet',
          subtitle:
              'No providers within your radius right now. Try browsing all categories.',
          actionLabel: 'Browse all',
          onAction: () => context.go(AppRoutes.search),
          compact: true,
        ),
      );
    }
    return SliverList(
      delegate: SliverChildListDelegate([
        if (state.trending.isNotEmpty) ...[
          SectionHeader(
            title: 'Trending near you',
            action: 'View all',
            onAction: () => context.go(AppRoutes.search),
          ),
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
              itemCount: state.trending.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (ctx, i) => ProviderCard(
                provider: state.trending[i],
                onTap: () => context.push('/provider/${state.trending[i].id}'),
              ),
            ),
          ),
        ],
        if (state.providers.isNotEmpty) ...[
          const SectionHeader(title: 'Available now'),
          ...state.providers.map(
            (p) => Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                0,
                AppTheme.gutter,
                10,
              ),
              child: ProviderListItem(
                provider: p,
                onTap: () => context.push('/provider/${p.id}'),
              ),
            ),
          ),
        ],
        if (state is HomeLoadingMore)
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppTheme.gutter,
              0,
              AppTheme.gutter,
              10,
            ),
            child: ProviderCardShimmer(),
          )
        else if (state.hasMore)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: AiwaButton(
                label: 'Load more',
                variant: AiwaButtonVariant.ghost,
                size: AiwaButtonSize.sm,
                onPressed: () => _homeBloc.add(HomeLoadMoreEvent()),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildSkeletons() {
    return SliverList(
      delegate: SliverChildListDelegate([
        const SizedBox(height: 22),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => const SkeletonTile(),
          ),
        ),
        const SizedBox(height: 22),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppTheme.gutter),
          child: SkeletonList(count: 3),
        ),
      ]),
    );
  }
}

class _Cat {
  final String id, label, palette;
  final IconData icon;
  const _Cat(this.id, this.label, this.icon, this.palette);
}
