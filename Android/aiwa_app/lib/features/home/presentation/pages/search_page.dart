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
import '../../domain/entities/provider_summary_entity.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import '../widgets/provider_list_item.dart';

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
  String _sort = 'Nearest';
  double _minRating = 0;
  double _maxPrice = _priceCap;

  static const double _priceCap = 2500;

  static const _cats = [
    ('ALL', 'All', Icons.auto_awesome_outlined),
    ('HAIR', 'Hair', Icons.content_cut_rounded),
    ('NAILS', 'Nails', Icons.back_hand_outlined),
    ('SPA', 'Spa', Icons.spa_outlined),
    ('MAKEUP', 'Makeup', Icons.brush_outlined),
    ('LASHES', 'Lashes', Icons.visibility_outlined),
    ('SKIN', 'Skin', Icons.water_drop_outlined),
    ('MASSAGE', 'Massage', Icons.volunteer_activism_outlined),
  ];

  static const _sorts = ['Nearest', 'Top rated', 'Price'];

  bool get _filtersActive => _minRating > 0 || _maxPrice < _priceCap;

  @override
  void initState() {
    super.initState();
    _homeBloc = sl<HomeBloc>();
    _activeCategory = widget.initialCategory;
    _homeBloc.add(
      HomeLoadEvent(
        lat: 30.0444,
        lng: 31.2357,
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
        HomeLoadEvent(lat: 30.0444, lng: 31.2357, category: _activeCategory),
      );
    } else {
      _homeBloc.add(HomeSearchEvent(q.trim()));
    }
  }

  void _clearAll() {
    _controller.clear();
    setState(() {
      _activeCategory = null;
      _minRating = 0;
      _maxPrice = _priceCap;
    });
    _homeBloc.add(const HomeLoadEvent(lat: 30.0444, lng: 31.2357));
  }

  List<ProviderSummaryEntity> _apply(List<ProviderSummaryEntity> input) {
    final list = input.where((p) {
      if (_minRating > 0 && (p.averageRating ?? 0) < _minRating) return false;
      if (_maxPrice < _priceCap &&
          p.startingPrice != null &&
          p.startingPrice! > _maxPrice) {
        return false;
      }
      return true;
    }).toList();
    switch (_sort) {
      case 'Top rated':
        list.sort(
          (a, b) => (b.averageRating ?? 0).compareTo(a.averageRating ?? 0),
        );
        break;
      case 'Price':
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
                const SliverToBoxAdapter(
                  child: PageTitle(
                    eyebrow: 'Find someone new',
                    title: 'Discover',
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
        padding: const EdgeInsets.only(left: 18, right: 8),
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
              child: TextField(
                controller: _controller,
                onChanged: _onSearch,
                onSubmitted: _onSearch,
                textInputAction: TextInputAction.search,
                cursorColor: AppColors.plum700,
                style: AppTextStyles.body.copyWith(color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'Search providers, services, locations',
                  hintStyle: AppTextStyles.body.copyWith(color: AppColors.ink3),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.ink3,
                  ),
                ),
              ),
            GestureDetector(
              onTap: () => _openFilters(count),
              child: AnimatedContainer(
                duration: AppTheme.dur2,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _filtersActive
                      ? AppColors.plum700
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.tune_rounded,
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
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppTheme.gutter,
          14,
          AppTheme.gutter,
          4,
        ),
        itemCount: _cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (id, label, icon) = _cats[i];
          final selected =
              _activeCategory == id || (id == 'ALL' && _activeCategory == null);
          return AiwaChip(
            label: label,
            icon: id == 'ALL' ? null : icon,
            active: selected,
            onTap: () {
              setState(() => _activeCategory = id == 'ALL' ? null : id);
              _homeBloc.add(HomeCategoryFilterEvent(_activeCategory));
            },
          );
        },
      ),
    );
  }

  Widget _buildActiveFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        8,
        AppTheme.gutter,
        0,
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          if (_minRating > 0)
            AiwaChip(
              label: '★ ${_minRating.toStringAsFixed(1)}+  ×',
              tonal: true,
              onTap: () => setState(() => _minRating = 0),
            ),
          if (_maxPrice < _priceCap)
            AiwaChip(
              label: 'Under EGP ${_maxPrice.toStringAsFixed(0)}  ×',
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
          Text('Sort', style: AppTextStyles.micro.copyWith(fontSize: 11.5)),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _sorts
                    .map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: AiwaChip(
                          label: s,
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
              '$count found',
              style: AppTextStyles.micro.copyWith(
                fontSize: 11.5,
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
    if (state is HomeError) {
      return [
        SliverToBoxAdapter(
          child: ErrorState(
            body: state.message,
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
      final narrowed =
          q.isNotEmpty || _filtersActive || _activeCategory != null;
      return [
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.search_off_rounded,
            title: q.isNotEmpty
                ? 'No match for “$q”'
                : 'Nothing in this category nearby',
            subtitle: q.isNotEmpty
                ? 'Try a different spelling, or browse by category instead.'
                : 'No providers within your radius match these filters yet.',
            actionLabel: narrowed ? 'Clear search & filters' : null,
            onAction: narrowed ? _clearAll : null,
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
                    label: 'Load more',
                    variant: AiwaButtonVariant.ghost,
                    size: AiwaButtonSize.sm,
                    onPressed: () => _homeBloc.add(HomeLoadMoreEvent()),
                  ),
                )
              : EndOfList(label: '${results.length} providers in range'),
        ),
      ),
    ];
  }

  void _openFilters(int count) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.plum900.withOpacity(0.45),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void update(VoidCallback fn) {
            setSheet(fn);
            setState(() {});
          }

          final state = _homeBloc.state;
          final liveCount = state is HomeLoaded
              ? _apply(state.providers).length
              : count;

          return Container(
            decoration: AppTheme.sheetDecoration,
            padding: EdgeInsets.fromLTRB(
              AppTheme.gutter,
              18,
              AppTheme.gutter,
              24 + MediaQuery.paddingOf(ctx).bottom,
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
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(child: Text('Filters', style: AppTextStyles.h3)),
                    GestureDetector(
                      onTap: () => update(() {
                        _minRating = 0;
                        _maxPrice = _priceCap;
                      }),
                      child: Text(
                        'Reset',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.plum700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SliderHeader(
                  label: 'Minimum rating',
                  value: _minRating == 0
                      ? 'Any'
                      : '${_minRating.toStringAsFixed(1)}★',
                ),
                Slider(
                  value: _minRating,
                  min: 0,
                  max: 5,
                  divisions: 10,
                  onChanged: (v) => update(() => _minRating = v),
                ),
                const _SliderRange(left: 'Any', right: '5.0'),
                const SizedBox(height: 22),
                _SliderHeader(
                  label: 'Max price',
                  value: 'EGP ${_maxPrice.toStringAsFixed(0)}',
                ),
                Slider(
                  value: _maxPrice,
                  min: 100,
                  max: _priceCap,
                  divisions: 48,
                  onChanged: (v) => update(() => _maxPrice = v),
                ),
                const _SliderRange(left: 'EGP 100', right: 'EGP 2,500+'),
                const SizedBox(height: 22),
                AiwaButton(
                  label: 'Show $liveCount provider${liveCount == 1 ? '' : 's'}',
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
