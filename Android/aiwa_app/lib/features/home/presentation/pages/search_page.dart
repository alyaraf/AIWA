import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_chip.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../../shared/widgets/aiwa_toast.dart';
import '../../domain/entities/provider_summary_entity.dart';
import '../../domain/repositories/home_repository.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import '../widgets/provider_list_item.dart';
import 'home_page.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Discover — search, category chips, sort, and a rating/price filter sheet.
class SearchPage extends StatefulWidget {
  final String? initialCategory;

  const SearchPage({super.key, this.initialCategory});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late HomeBloc _homeBloc;
  final _controller = TextEditingController();
  String? _activeCategory;
  String _sort = 'nearest';
  double _minRating = 0;
  double _maxPrice = _priceCap;
  String? _notifyError;

  static const double _priceCap = 2500;

  static const _cats = [
    ('ALL', LucideIcons.sparkles),
    ('HAIR', LucideIcons.scissors),
    ('NAILS', LucideIcons.hand),
    ('SPA', LucideIcons.leaf),
    ('MAKEUP', LucideIcons.brush),
    ('LASHES', LucideIcons.eye),
    ('SKIN', LucideIcons.droplets),
    ('MASSAGE', LucideIcons.handHeart),
  ];

  static const _sorts = ['nearest', 'rated', 'price'];

  String _sortLabel(String s) => switch (s) {
    'rated' => AppLocalizations.of(context).searchSortTopRated,
    'price' => AppLocalizations.of(context).searchSortPrice,
    _ => AppLocalizations.of(context).searchSortNearest,
  };

  bool get _filtersActive => _minRating > 0 || _maxPrice < _priceCap;

  /// ProviderSummaryDto has no startingPrice yet, so the Price sort and the
  /// Max price filter stay hidden until some provider carries one.
  bool get _pricesKnown {
    final s = _homeBloc.state;
    return s is HomeLoaded && s.providers.any((p) => p.startingPrice != null);
  }

  @override
  void initState() {
    super.initState();
    _homeBloc = sl<HomeBloc>();
    _activeCategory = widget.initialCategory;
    _homeBloc.add(
      HomeLoadEvent(
        lat: HomePage.position.lat,
        lng: HomePage.position.lng,
        category: widget.initialCategory,
      ),
    );
  }

  @override
  void didUpdateWidget(SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCategory != widget.initialCategory) {
      setState(() => _activeCategory = widget.initialCategory);
      _homeBloc.add(HomeCategoryFilterEvent(_activeCategory));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    setState(() {});
    if (q.trim().isEmpty) {
      _homeBloc.add(
        HomeLoadEvent(
          lat: HomePage.position.lat,
          lng: HomePage.position.lng,
          category: _activeCategory,
        ),
      );
    } else {
      _homeBloc.add(HomeSearchEvent(q.trim()));
    }
  }

  void _widenRadius() => _homeBloc.add(
    HomeLoadEvent(
      lat: HomePage.position.lat,
      lng: HomePage.position.lng,
      category: _activeCategory,
      // ponytail: one fixed step out from the 5 km default.
      radiusKm: 25,
    ),
  );

  Future<void> _notifyMe() async {
    setState(() => _notifyError = null);
    final result = await sl<HomeRepository>().notifyWhenProviderJoins(
      category: _activeCategory,
    );
    if (!mounted) return;
    result.fold(
      (f) => setState(
        () => _notifyError = AppLocalizations.of(context).error(f.message),
      ),
      (_) => showAiwaToast(
        context,
        AppLocalizations.of(context).searchNotifyToast,
      ),
    );
  }

  void _clearAll() {
    _controller.clear();
    setState(() {
      _notifyError = null;
      _activeCategory = null;
      _minRating = 0;
      _maxPrice = _priceCap;
    });
    _homeBloc.add(
      HomeLoadEvent(lat: HomePage.position.lat, lng: HomePage.position.lng),
    );
  }

  List<ProviderSummaryEntity> _apply(List<ProviderSummaryEntity> input) {
    final list = input.where((p) {
      // Search results come back unfiltered by category.
      if (_activeCategory != null && p.primaryCategory != _activeCategory) {
        return false;
      }
      if (_minRating > 0 && (p.averageRating ?? 0) < _minRating) return false;
      if (_maxPrice < _priceCap &&
          p.startingPrice != null &&
          p.startingPrice! > _maxPrice) {
        return false;
      }
      return true;
    }).toList();
    switch (_sort) {
      case 'rated':
        list.sort(
          (a, b) => (b.averageRating ?? 0).compareTo(a.averageRating ?? 0),
        );
        break;
      case 'price':
        list.sort(
          (a, b) => (a.startingPrice ?? double.infinity).compareTo(
            b.startingPrice ?? double.infinity,
          ),
        );
        break;
      default:
        list.sort(
          (a, b) => (a.distanceKm ?? double.infinity).compareTo(
            b.distanceKm ?? double.infinity,
          ),
        );
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _homeBloc,
      child: Scaffold(
        backgroundColor: AppColors.bone,
        body: BlocBuilder<HomeBloc, HomeState>(
          bloc: _homeBloc,
          builder: (context, state) {
            final loaded = state is HomeLoaded;
            final results = state is HomeLoaded
                ? _apply(state.providers)
                : <ProviderSummaryEntity>[];
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: PageTitle(
                    eyebrow: AppLocalizations.of(context).searchEyebrow,
                    title: AppLocalizations.of(context).searchTitle,
                    letterSpacing: 0,
                    bottom: 12,
                  ),
                ),
                SliverToBoxAdapter(child: _buildSearchField(results.length)),
                SliverToBoxAdapter(child: _buildCategoryChips()),
                if (_filtersActive)
                  SliverToBoxAdapter(child: _buildActiveFilters()),
                SliverToBoxAdapter(
                  child: _buildSortRow(loaded ? results.length : null),
                ),
                ..._buildResults(state, results),
                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchField(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        6,
        AppTheme.gutter,
        6,
      ),
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
            Icon(LucideIcons.search, size: 18, color: AppColors.plum700),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: _onSearch,
                onSubmitted: _onSearch,
                textInputAction: TextInputAction.search,
                cursorColor: AppColors.plum700,
                style: AppTextStyles.body.copyWith(color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).searchHint,
                  hintStyle: AppTextStyles.body.copyWith(color: AppColors.ink3),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_controller.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _controller.clear();
                  _onSearch('');
                },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(LucideIcons.x, size: 16, color: AppColors.ink3),
                ),
              ),
            GestureDetector(
              onTap: () => _openFilters(count),
              child: AnimatedContainer(
                duration: AppTheme.dur2,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _filtersActive
                      ? AppColors.plum700
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.slidersHorizontal,
                  size: 18,
                  color: _filtersActive ? AppColors.paper : AppColors.plum700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    // Content-height row: a fixed SizedBox clipped chips at larger text.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        14,
        AppTheme.gutter,
        6,
      ),
      child: Row(
        children: [
          for (final (i, (id, icon)) in _cats.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            _categoryChip(
              id,
              id == 'ALL'
                  ? AppLocalizations.of(context).homeAll
                  : AppLocalizations.of(context).category(id),
              icon,
            ),
          ],
        ],
      ),
    );
  }

  Widget _categoryChip(String id, String label, IconData icon) {
    final selected =
        _activeCategory == id || (id == 'ALL' && _activeCategory == null);
    return AiwaChip(
      label: label,
      icon: id == 'ALL' ? null : icon,
      active: selected,
      onTap: () {
        setState(() => _activeCategory = id == 'ALL' ? null : id);
        // Keep the typed query: re-run the search, the category is
        // applied client-side in _apply.
        if (_controller.text.trim().isNotEmpty) {
          _onSearch(_controller.text);
        } else {
          _homeBloc.add(HomeCategoryFilterEvent(_activeCategory));
        }
      },
    );
  }

  Widget _buildActiveFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        0,
        AppTheme.gutter,
        4,
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          if (_minRating > 0)
            AiwaChip(
              label: AppLocalizations.of(
                context,
              ).searchMinRatingChip(_minRating.toStringAsFixed(1)),
              tonal: true,
              onTap: () => setState(() => _minRating = 0),
            ),
          if (_maxPrice < _priceCap)
            AiwaChip(
              label: AppLocalizations.of(context).searchUnderPriceChip(
                AppLocalizations.of(context).egp(_maxPrice),
              ),
              tonal: true,
              onTap: () => setState(() => _maxPrice = _priceCap),
            ),
        ],
      ),
    );
  }

  Widget _buildSortRow(int? count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        10,
        AppTheme.gutter,
        0,
      ),
      child: Row(
        children: [
          Text(
            AppLocalizations.of(context).searchSort,
            style: AppTextStyles.micro.copyWith(
              fontSize: AppTextStyles.fsMicroPlus,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _sorts
                    .where((s) => s != 'price' || _pricesKnown)
                    .map(
                      (s) => Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: AiwaChip(
                          label: _sortLabel(s),
                          active: _sort == s,
                          onTap: () => setState(() => _sort = s),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          if (count != null)
            Text(
              AppLocalizations.of(context).searchFound(count),
              style: AppTextStyles.micro.copyWith(
                fontSize: AppTextStyles.fsMicroPlus,
                color: AppColors.ink4,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildResults(
    HomeState state,
    List<ProviderSummaryEntity> results,
  ) {
    const pad = EdgeInsets.fromLTRB(AppTheme.gutter, 14, AppTheme.gutter, 0);
    final l = AppLocalizations.of(context);
    if (state is HomeError) {
      return [
        SliverToBoxAdapter(
          child: ErrorState(
            body: l.error(state.message),
            onRetry: () => _onSearch(_controller.text),
            compact: true,
          ),
        ),
      ];
    }
    if (state is! HomeLoaded) {
      return const [
        SliverPadding(
          padding: pad,
          sliver: SliverToBoxAdapter(child: SkeletonList(count: 4)),
        ),
      ];
    }
    if (results.isEmpty) {
      final q = _controller.text.trim();
      final cleared = q.isNotEmpty || _filtersActive;
      return [
        SliverToBoxAdapter(
          child: EmptyState(
            icon: LucideIcons.searchX,
            title: q.isNotEmpty
                ? l.searchNoMatch(q)
                : l.searchNothingInCategory,
            subtitle: q.isNotEmpty
                ? l.searchNoMatchBody
                : l.searchNoFilterMatchBody,
            actionLabel: cleared ? l.searchClearAll : l.searchWiden,
            onAction: cleared ? _clearAll : _widenRadius,
            secondaryLabel: l.searchNotifyMe,
            onSecondary: _notifyMe,
          ),
        ),
        if (_notifyError != null)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
            sliver: SliverToBoxAdapter(
              child: InlineBanner(
                tone: BannerTone.danger,
                icon: LucideIcons.circleAlert,
                body: _notifyError,
                compact: true,
              ),
            ),
          ),
      ];
    }
    return [
      SliverPadding(
        padding: pad,
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((ctx, i) {
            final p = results[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ProviderListItem(
                provider: p,
                showPrice: false,
                onTap: () => context.push('/provider/${p.id}'),
              ),
            );
          }, childCount: results.length),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
        sliver: SliverToBoxAdapter(
          child: state is HomeLoadingMore
              ? const ProviderCardShimmer()
              : state.hasMore
              ? Center(
                  child: AiwaButton(
                    label: l.commonLoadMore,
                    variant: AiwaButtonVariant.ghost,
                    size: AiwaButtonSize.sm,
                    onPressed: () => _homeBloc.add(HomeLoadMoreEvent()),
                  ),
                )
              : EndOfList(label: l.searchInRange(results.length)),
        ),
      ),
    ];
  }

  void _openFilters(int count) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.plum900.withOpacity(0.45),
      isScrollControlled: true,
      sheetAnimationStyle: AnimationStyle(
        duration: AppTheme.dur3,
        curve: AppTheme.easeSoft,
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void update(VoidCallback fn) {
            setSheet(fn);
            setState(() {});
          }

          final state = _homeBloc.state;
          final l = AppLocalizations.of(context);
          final liveCount = state is HomeLoaded
              ? _apply(state.providers).length
              : count;

          return Container(
            // prototype.jsx:244 filters sheet: 0 -12px 32px rgba(0,0,0,.18).
            decoration: AppTheme.sheetDecoration.copyWith(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .18),
                  blurRadius: 32,
                  offset: const Offset(0, -12),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(
              AppTheme.gutter,
              18,
              AppTheme.gutter,
              36 + MediaQuery.paddingOf(ctx).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(AppTheme.radius2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(l.searchFilters, style: AppTextStyles.h3),
                    ),
                    GestureDetector(
                      onTap: () => update(() {
                        _minRating = 0;
                        _maxPrice = _priceCap;
                      }),
                      child: Text(
                        l.searchReset,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.plum700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SliderHeader(
                  label: l.searchMinRating,
                  value: _minRating == 0
                      ? l.searchAny
                      : '${_minRating.toStringAsFixed(1)}★',
                ),
                const SizedBox(height: 8),
                Slider(
                  padding: EdgeInsets.zero,
                  value: _minRating,
                  min: 0,
                  max: 5,
                  divisions: 10,
                  onChanged: (v) => update(() => _minRating = v),
                ),
                const SizedBox(height: 4),
                _SliderRange(left: l.searchAny, right: '5.0'),
                if (_pricesKnown) ...[
                  const SizedBox(height: 22),
                  _SliderHeader(
                    label: l.searchMaxPrice,
                    value: l.egp(_maxPrice),
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    padding: EdgeInsets.zero,
                    value: _maxPrice,
                    min: 100,
                    max: _priceCap,
                    divisions: 48,
                    onChanged: (v) => update(() => _maxPrice = v),
                  ),
                  const SizedBox(height: 4),
                  _SliderRange(left: l.egp(100), right: '${l.egp(2500)}+'),
                ],
                const SizedBox(height: 22),
                AiwaButton(
                  label: l.searchShowProviders(liveCount),
                  fullWidth: true,
                  size: AiwaButtonSize.lg,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SliderHeader extends StatelessWidget {
  final String label;
  final String value;
  const _SliderHeader({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: EyebrowLabel(label)),
        Text(value, style: AppTextStyles.h4),
      ],
    );
  }
}

class _SliderRange extends StatelessWidget {
  final String left, right;
  const _SliderRange({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.micro;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(left, style: style),
          Text(right, style: style),
        ],
      ),
    );
  }
}
