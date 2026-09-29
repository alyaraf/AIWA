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
import '../../../profile/data/account_repository.dart';
import '../../../notifications/presentation/bloc/notification_bloc.dart';
import '../../../notifications/presentation/bloc/notification_event.dart';
import '../../../notifications/presentation/bloc/notification_state.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import '../widgets/category_tile.dart';
import '../widgets/provider_card.dart';
import '../widgets/provider_list_item.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  /// Last position Home resolved (Cairo until then); Discover reuses it.
  // ponytail: static field, move to a LocationCubit if more screens need it.
  static ({double lat, double lng}) position = (lat: 30.0444, lng: 31.2357);

  /// True once [position] is a real GPS fix, not the Cairo default.
  static bool hasFix = false;

  /// The pushed location priming screen is offered once per app run.
  static bool locationPrimed = false;

  /// Greeting clock; goldens pin it so the golden doesn't change by hour.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late HomeBloc _homeBloc;

  /// Default saved address label; null shows 'Near me'.
  String? _area;

  static const _categories = [
    _Cat('HAIR', LucideIcons.scissors, 'plum'),
    _Cat('NAILS', LucideIcons.hand, 'rose'),
    _Cat('SPA', LucideIcons.leaf, 'cream'),
    _Cat('MAKEUP', LucideIcons.brush, 'gold'),
    _Cat('LASHES', LucideIcons.eye, 'rose'),
    _Cat('SKIN', LucideIcons.droplets, 'plum'),
    _Cat('MASSAGE', LucideIcons.handHeart, 'cream'),
    _Cat('ALL', LucideIcons.sparkles, 'gold'),
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
    var (:lat, :lng) = HomePage.position;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        // Asked on the priming screen (/perm-location), never cold here.
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied &&
            !HomePage.locationPrimed &&
            mounted) {
          // Skipped or refused at onboarding: offer it again, pop-back style.
          HomePage.locationPrimed = true;
          await context.push<bool>(
            Uri(
              path: AppRoutes.permission,
              queryParameters: {'kind': 'location'},
            ).toString(),
          );
          perm = await Geolocator.checkPermission();
        }
        if (perm != LocationPermission.denied &&
            perm != LocationPermission.deniedForever) {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 5),
          );
          lat = pos.latitude;
          lng = pos.longitude;
          HomePage.position = (lat: lat, lng: lng);
          HomePage.hasFix = true;
        }
      }
    } catch (_) {}
    if (mounted) {
      final auth = context.read<AuthBloc>().state;
      if (auth is AuthAuthenticated) _loadArea();
      _homeBloc.add(
        HomeLoadEvent(
          lat: lat,
          lng: lng,
          radiusKm: auth is AuthAuthenticated
              ? auth.user.searchRadiusMaxKm ?? 5
              : 5,
        ),
      );
    }
  }

  // Search-pill label: the default saved address, 'Near me' otherwise.
  // ponytail: no reverse geocoding (no geocoding package); add it for guests.
  Future<void> _loadArea() async {
    final res = await sl<AccountRepository>().addresses();
    res.fold((_) {}, (list) {
      final def = list.where((a) => a.isDefault && a.label.isNotEmpty);
      if (def.isNotEmpty && mounted) setState(() => _area = def.first.label);
    });
  }

  String get _greeting {
    final h = HomePage.now().hour;
    final l = AppLocalizations.of(context);
    if (h < 12) return l.homeGoodMorning;
    if (h < 17) return l.homeGoodAfternoon;
    return l.homeGoodEvening;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _homeBloc,
      child: Scaffold(
        backgroundColor: AppColors.bone,
        body: CustomScrollView(
          physics: AiwaRefresh.physics,
          slivers: [
            AiwaRefresh(onRefresh: _loadData),
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
                      body: AppLocalizations.of(context).error(state.message),
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
                      first != null
                          ? AppLocalizations.of(
                              context,
                            ).homeGreetingName(_greeting, first)
                          : _greeting,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context).homeHeadline,
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
                    icon: LucideIcons.bell,
                    dot: count > 0,
                    onTap: () => user != null
                        ? context.push(AppRoutes.notifications)
                        : context.push(AppRoutes.authGate),
                  );
                },
              ),
              const SizedBox(width: 12),
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
                color: AppColors.shadowTint.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(LucideIcons.search, size: 18, color: AppColors.plum700),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).homeSearchHint,
                  style: AppTextStyles.body.copyWith(color: AppColors.ink3),
                ),
              ),
              Container(width: 1, height: 20, color: AppColors.divider),
              const SizedBox(width: 10),
              Icon(LucideIcons.mapPin, size: 14, color: AppColors.plum700),
              const SizedBox(width: 5),
              Text(
                _area != null
                    ? AppLocalizations.of(context).addressLabel(_area!)
                    : AppLocalizations.of(context).homeNearMe,
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
          // screens.jsx:96 is 135deg, unlike the 160deg heroGradient.
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.plum700, AppColors.plum900],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radius22),
        ),
        child: Stack(
          children: [
            PositionedDirectional(
              end: -40,
              top: -40,
              child: AiwaGlow(
                size: 180,
                color: AppColors.glowRose,
                opacity: 0.4,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EyebrowLabel(
                    AppLocalizations.of(context).homePromoEyebrow,
                    color: AppColors.rose300,
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(
                      AppLocalizations.of(context).homePromoTitle,
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
                      AppLocalizations.of(context).homePromoBody,
                      style: AppTextStyles.meta.copyWith(
                        color: AppColors.rose300,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AiwaButton(
                    label: AppLocalizations.of(context).homeExplore,
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
          title: AppLocalizations.of(context).homeCategories,
          action: AppLocalizations.of(context).commonSeeAll,
          onAction: () => context.go(AppRoutes.search),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
          // Fixed row height, not an aspect ratio: tiles are ~72dp wide on a
          // 360dp phone and the 88dp content overflowed at 0.86.
          child: GridView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: MediaQuery.textScalerOf(context).scale(12) + 80,
            ),
            children: _categories
                .map(
                  (c) => CategoryTile(
                    label: c.id == 'ALL'
                        ? AppLocalizations.of(context).homeAll
                        : AppLocalizations.of(context).category(c.id),
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
    final l = AppLocalizations.of(context);
    if (state.trending.isEmpty && state.providers.isEmpty) {
      return SliverToBoxAdapter(
        child: EmptyState(
          icon: LucideIcons.locateFixed,
          title: l.homeNobodyNearby,
          subtitle: l.homeNobodyNearbyBody,
          actionLabel: l.homeBrowseAll,
          onAction: () => context.go(AppRoutes.search),
          compact: true,
        ),
      );
    }
    return SliverList(
      delegate: SliverChildListDelegate([
        if (state.trending.isNotEmpty) ...[
          SectionHeader(
            title: l.homeTrending,
            action: l.homeViewMap,
            onAction: () => context.go(AppRoutes.search),
          ),
          // Content-height row so the cards don't clip at large text scales.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, p) in state.trending.indexed) ...[
                  if (i > 0) const SizedBox(width: 12),
                  ProviderCard(
                    provider: p,
                    onTap: () => context.push('/provider/${p.id}'),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (state.providers.isNotEmpty) ...[
          SectionHeader(title: l.homeAvailableNow),
          // Prototype shows 4; the full list lives in Discover.
          ...state.providers
              .take(4)
              .map(
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
            itemBuilder: (_, __) => const SkeletonTile(width: 200, height: 110),
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
  final String id, palette;
  final IconData icon;
  const _Cat(this.id, this.icon, this.palette);
}
