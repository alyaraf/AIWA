import 'package:cached_network_image/cached_network_image.dart';
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
import '../../../../shared/widgets/aiwa_chip.dart';
import '../../../../shared/widgets/aiwa_icon_button.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../../shared/widgets/star_rating.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../home/presentation/widgets/provider_card.dart';
import '../../domain/entities/provider_detail_entity.dart';
import '../bloc/provider_bloc.dart';
import '../bloc/provider_event.dart';
import '../bloc/provider_state.dart';

class ProviderDetailPage extends StatefulWidget {
  final String providerId;

  const ProviderDetailPage({super.key, required this.providerId});

  @override
  State<ProviderDetailPage> createState() => _ProviderDetailPageState();
}

class _ProviderDetailPageState extends State<ProviderDetailPage> {
  late ProviderBloc _bloc;
  String _tab = 'services';

  static const _categoryLabels = {
    'HAIR': 'Hair',
    'NAILS': 'Nails',
    'SPA': 'Spa',
    'MAKEUP': 'Makeup',
    'LASHES': 'Lashes',
    'SKIN': 'Skin',
    'MASSAGE': 'Massage',
    'OTHER': 'Other',
  };

  @override
  void initState() {
    super.initState();
    _bloc = sl<ProviderBloc>();
    _bloc.add(ProviderLoadEvent(widget.providerId));
  }

  bool get _isSignedIn => context.read<AuthBloc>().state is AuthAuthenticated;

  void _book({ServiceEntity? service}) {
    if (!_isSignedIn) {
      context.push(AppRoutes.authGate);
      return;
    }
    final query = service != null ? '?serviceId=${service.id}' : '';
    context.push('/booking/${widget.providerId}$query');
  }

  void _toggleSave() {
    if (!_isSignedIn) {
      context.push(AppRoutes.authGate);
      return;
    }
    _bloc.add(ProviderToggleSaveEvent(widget.providerId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocBuilder<ProviderBloc, ProviderState>(
        bloc: _bloc,
        builder: (context, state) {
          if (state is ProviderLoaded) return _buildLoaded(state);
          return Scaffold(
            backgroundColor: AppColors.bone,
            body: state is ProviderError
                ? Column(
                    children: [
                      ScreenHeader(title: '', onBack: () => context.pop()),
                      Expanded(
                        child: ErrorState(
                          body: state.message,
                          onRetry: () =>
                              _bloc.add(ProviderLoadEvent(widget.providerId)),
                        ),
                      ),
                    ],
                  )
                : _buildSkeleton(),
          );
        },
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const ShimmerBox(height: 280, radius: 0),
        Padding(
          padding: const EdgeInsets.all(AppTheme.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              ShimmerBox(height: 12),
              SizedBox(height: 8),
              ShimmerBox(width: 220, height: 12),
              SizedBox(height: 22),
              SkeletonList(count: 3),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoaded(ProviderLoaded state) {
    final p = state.provider;
    final prices = p.services.where((s) => s.available).map((s) => s.price);
    final startsAt = prices.isEmpty
        ? null
        : prices.reduce((a, b) => a < b ? a : b);

    return Scaffold(
      backgroundColor: AppColors.bone,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHero(p, state.isSaved)),
          ..._buildTabContent(p),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
      bottomNavigationBar: StickyBar(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EyebrowLabel('Starts at', fontSize: 10),
                  const SizedBox(height: 2),
                  Text(
                    startsAt != null
                        ? 'EGP ${_money(startsAt)}'
                        : 'Ask provider',
                    style: AppTextStyles.price.copyWith(height: 1.1),
                  ),
                ],
              ),
            ),
            AiwaButton(
              label: 'Book now',
              icon: Icons.event_available_rounded,
              size: AiwaButtonSize.lg,
              onPressed: p.services.any((s) => s.available) ? _book : null,
            ),
          ],
        ),
      ),
    );
  }

  double get _coverHeight => 280 + MediaQuery.paddingOf(context).top * 0.5;

  /// Cover with the bone body card overlapping its bottom 24px.
  Widget _buildHero(ProviderDetailEntity p, bool isSaved) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: _coverHeight,
          child: _buildCover(p, isSaved),
        ),
        Padding(
          padding: EdgeInsets.only(top: _coverHeight - 24),
          child: _buildBody(p),
        ),
      ],
    );
  }

  Widget _buildCover(ProviderDetailEntity p, bool isSaved) {
    final top = MediaQuery.paddingOf(context).top;
    final category = p.categories.isNotEmpty
        ? p.categories.map((c) => _categoryLabels[c] ?? c).join(' · ')
        : null;
    return SizedBox(
      height: _coverHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (p.profileImageUrl != null && p.profileImageUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: p.profileImageUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) =>
                  CoverImage(initial: p.displayName, hero: true),
            )
          else
            CoverImage(initial: p.displayName, hero: true),
          // Legibility scrim over real photos only
          if (p.profileImageUrl != null && p.profileImageUrl!.isNotEmpty)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.plum900.withOpacity(0.55),
                  ],
                  stops: const [0.35, 1],
                ),
              ),
            ),
          Positioned(
            top: top + 12,
            left: 18,
            right: 18,
            child: Row(
              children: [
                AiwaIconButton(
                  icon: Icons.arrow_back_rounded,
                  variant: AiwaIconButtonVariant.glass,
                  onTap: () => context.pop(),
                ),
                const Spacer(),
                AiwaIconButton(
                  icon: isSaved
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  iconColor: isSaved ? AppColors.rose500 : null,
                  variant: AiwaIconButtonVariant.glass,
                  onTap: _toggleSave,
                ),
              ],
            ),
          ),
          Positioned(
            left: AppTheme.gutter,
            right: AppTheme.gutter,
            bottom: 44,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (category != null)
                  EyebrowLabel(category, color: AppColors.rose300),
                const SizedBox(height: 4),
                Text(
                  p.displayName,
                  style: AppTextStyles.h1.copyWith(
                    color: AppColors.bone,
                    fontSize: 32,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 4,
                  children: [
                    _CoverMeta(
                      icon: Icons.star_rounded,
                      iconColor: AppColors.gold300,
                      text: p.totalReviews > 0
                          ? '${p.averageRating.toStringAsFixed(1)} (${p.totalReviews})'
                          : 'New',
                      bold: true,
                    ),
                    if (p.address != null && p.address!.isNotEmpty) ...[
                      MetaDot(color: AppColors.rose300),
                      _CoverMeta(
                        icon: Icons.location_on_outlined,
                        text: p.address!,
                      ),
                    ],
                    if (p.isVerified) ...[
                      MetaDot(color: AppColors.rose300),
                      _CoverMeta(
                        icon: Icons.verified_rounded,
                        iconColor: AppColors.gold300,
                        text: 'Verified',
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ProviderDetailEntity p) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bone,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        20,
        AppTheme.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (p.bio != null && p.bio!.trim().isNotEmpty)
                ? p.bio!
                : 'Top-rated provider in your area. Browse the services, recent reviews and gallery below.',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.ink2),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (p.phone.isNotEmpty)
                AiwaChip(
                  label: 'Call',
                  icon: Icons.phone_outlined,
                  onTap: () => _launch('tel:${p.phone}'),
                ),
              if (p.phone.isNotEmpty)
                AiwaChip(
                  label: 'WhatsApp',
                  icon: Icons.chat_bubble_outline_rounded,
                  onTap: () => _launch(
                    'https://wa.me/${p.phone.replaceAll(RegExp(r'[^0-9]'), '')}',
                  ),
                ),
              if (p.latitude != null && p.longitude != null)
                AiwaChip(
                  label: 'Directions',
                  icon: Icons.map_outlined,
                  onTap: () => _launch(
                    'https://maps.google.com/?q=${p.latitude},${p.longitude}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          _Tabs(active: _tab, onChanged: (t) => setState(() => _tab = t)),
        ],
      ),
    );
  }

  List<Widget> _buildTabContent(ProviderDetailEntity p) {
    // Content sits under the body card, which is shifted up by 24px.
    // Design: 8px above the services list, 16px above reviews and gallery.
    const pad = EdgeInsets.fromLTRB(AppTheme.gutter, 16, AppTheme.gutter, 0);
    const servicesPad = EdgeInsets.fromLTRB(
      AppTheme.gutter,
      8,
      AppTheme.gutter,
      0,
    );
    switch (_tab) {
      case 'reviews':
        if (p.reviews.isEmpty) {
          return [
            const SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.star_outline_rounded,
                title: 'No reviews yet',
                subtitle: 'Be the first to book and leave a review.',
                tone: EmptyStateTone.gold,
                compact: true,
              ),
            ),
          ];
        }
        return [
          SliverPadding(
            padding: pad,
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Text(
                      p.averageRating.toStringAsFixed(1),
                      style: AppTextStyles.display.copyWith(
                        fontSize: 38,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StarRating(value: p.averageRating),
                        const SizedBox(height: 2),
                        Text(
                          'Based on ${p.totalReviews} reviews',
                          style: AppTextStyles.micro.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gutter,
              16,
              AppTheme.gutter,
              0,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _ReviewRow(review: p.reviews[i], index: i),
                ),
                childCount: p.reviews.length,
              ),
            ),
          ),
        ];
      case 'gallery':
        if (p.galleryImages.isEmpty) {
          return [
            const SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.photo_library_outlined,
                title: 'No photos yet',
                subtitle: "This provider hasn't added gallery photos.",
                compact: true,
              ),
            ),
          ];
        }
        return [
          SliverPadding(
            padding: pad,
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: p.galleryImages[i],
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const ShimmerBox(height: 120),
                    errorWidget: (_, __, ___) =>
                        Container(color: AppColors.cream),
                  ),
                ),
                childCount: p.galleryImages.length,
              ),
            ),
          ),
        ];
      default:
        if (p.services.isEmpty) {
          return [
            const SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.content_cut_rounded,
                title: 'No services listed',
                subtitle: 'This provider has not published services yet.',
                compact: true,
              ),
            ),
          ];
        }
        return [
          SliverPadding(
            padding: servicesPad,
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _ServiceRow(
                  service: p.services[i],
                  onBook: () => _book(service: p.services[i]),
                ),
                childCount: p.services.length,
              ),
            ),
          ),
        ];
    }
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

String _money(double v) => NumberFormat.decimalPattern('en').format(v.round());

/// "2 weeks ago" style, as in the design's review list.
String _relative(DateTime date) {
  final days = DateTime.now().difference(date.toLocal()).inDays;
  if (days < 1) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days < 7) return '$days days ago';
  if (days < 30) {
    final w = days ~/ 7;
    return w == 1 ? '1 week ago' : '$w weeks ago';
  }
  if (days < 365) {
    final m = days ~/ 30;
    return m == 1 ? '1 month ago' : '$m months ago';
  }
  return DateFormat('MMM yyyy').format(date.toLocal());
}

String _duration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}min';
}

class _CoverMeta extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String text;
  final bool bold;

  const _CoverMeta({
    required this.icon,
    required this.text,
    this.iconColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: iconColor ?? AppColors.bone),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.meta.copyWith(
              color: AppColors.bone,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

class _Tabs extends StatelessWidget {
  final String active;
  final ValueChanged<String> onChanged;

  const _Tabs({required this.active, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const tabs = [
      ('services', 'Services'),
      ('reviews', 'Reviews'),
      ('gallery', 'Gallery'),
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: tabs.map((t) {
          final on = t.$1 == active;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(t.$1),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: AppTheme.dur2,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: on ? AppColors.plum700 : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  t.$2,
                  style: AppTextStyles.label.copyWith(
                    fontSize: 14,
                    color: on ? AppColors.plum700 : AppColors.ink3,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  final ServiceEntity service;
  final VoidCallback onBook;

  const _ServiceRow({required this.service, required this.onBook});

  @override
  Widget build(BuildContext context) {
    final available = service.available;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: available ? AppColors.ink : AppColors.ink4,
                    height: 1.3,
                  ),
                ),
                if (service.description != null &&
                    service.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      service.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.micro.copyWith(fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      _duration(service.durationMinutes),
                      style: AppTextStyles.micro.copyWith(fontSize: 12),
                    ),
                    if (!available) ...[
                      const MetaDot(),
                      Text(
                        'Unavailable',
                        style: AppTextStyles.micro.copyWith(
                          fontSize: 12,
                          color: AppColors.danger700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'EGP ${_money(service.price)}',
            style: AppTextStyles.h4.copyWith(fontSize: 18, height: 1),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: available ? onBook : null,
            child: Opacity(
              opacity: available ? 1 : 0.35,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.plum700, width: 1.5),
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 16,
                  color: AppColors.plum700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final ReviewSummaryEntity review;
  final int index;

  const _ReviewRow({required this.review, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AiwaAvatar(
          name: review.customerName,
          size: 38,
          imageUrl: review.customerImageUrl,
          palette: AvatarPalette.values[index % AvatarPalette.values.length],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      review.customerName,
                      style: AppTextStyles.label.copyWith(fontSize: 14),
                    ),
                  ),
                  Text(_relative(review.createdAt), style: AppTextStyles.micro),
                ],
              ),
              const SizedBox(height: 3),
              StarRating(value: review.rating, size: 11),
              if (review.comment != null && review.comment!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  review.comment!,
                  style: AppTextStyles.meta.copyWith(
                    color: AppColors.ink2,
                    height: 1.55,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
