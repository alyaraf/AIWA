import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/api_constants.dart';
import 'package:flutter/material.dart';
import '../../../home/presentation/pages/home_page.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
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
import '../../../../shared/widgets/press_scale.dart';
import '../../../../shared/widgets/reason_sheet.dart';
import '../../../../shared/widgets/aiwa_toast.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../../shared/widgets/star_rating.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../home/presentation/widgets/provider_card.dart';
import '../../domain/entities/provider_detail_entity.dart';
import '../../domain/repositories/provider_repository.dart';
import '../bloc/provider_bloc.dart';
import '../bloc/provider_event.dart';
import '../bloc/provider_state.dart';
import '../widgets/flag_provider_sheet.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ProviderDetailPage extends StatefulWidget {
  final String providerId;

  const ProviderDetailPage({super.key, required this.providerId});

  @override
  State<ProviderDetailPage> createState() => _ProviderDetailPageState();
}

class _ProviderDetailPageState extends State<ProviderDetailPage> {
  late ProviderBloc _bloc;
  String _tab = 'services';

  @override
  void initState() {
    super.initState();
    _bloc = sl<ProviderBloc>();
    _bloc.add(ProviderLoadEvent(widget.providerId));
  }

  bool get _isSignedIn => context.read<AuthBloc>().state is AuthAuthenticated;

  /// prototype.jsx:661-667 — shop -> staff picker, guest -> auth gate,
  /// otherwise the booking-type step.
  void _book(ProviderDetailEntity p, {ServiceEntity? service}) {
    if (p.isShop) {
      final q = service != null ? '?serviceId=${service.id}' : '';
      context.push('/provider/${p.id}/staff$q', extra: p);
      return;
    }
    final target = AppRoutes.bookingTypeFor(p.id, serviceId: service?.id);
    if (_isSignedIn) {
      context.push(target);
    } else {
      context.push(AppRoutes.authGate, extra: target);
    }
  }

  /// Link base for shared profiles. The aiwa:// scheme opens the installed app
  /// (AndroidManifest / Info.plist). Pass --dart-define=APP_LINK_BASE=https://…
  /// once a verified App Links / Universal Links host exists.
  static const _linkBase = String.fromEnvironment(
    'APP_LINK_BASE',
    defaultValue: 'aiwa://app',
  );

  Future<void> _share(ProviderDetailEntity p) => SharePlus.instance.share(
    ShareParams(
      text: [
        AppLocalizations.of(context).providerShareText(p.displayName),
        if (p.address != null && p.address!.isNotEmpty) p.address!,
        '$_linkBase/provider/${p.id}',
      ].join(' · '),
    ),
  );

  /// POST /providers/{id}/gallery/{imageId}/report → admin photo moderation.
  Future<void> _reportPhoto(ProviderDetailEntity p, String imageId) async {
    if (!_isSignedIn) {
      context.push(AppRoutes.authGate);
      return;
    }
    final l = AppLocalizations.of(context);
    final r = await showReasonSheet(
      context,
      eyebrow: l.providerReportPhoto,
      title: l.flagTitle,
      reasons: [
        l.flagReasonMisleading,
        l.flagReasonSpam,
        l.flagReasonBehavior,
        l.flagReasonOther,
      ],
      otherLabel: l.flagReasonOther,
      cancelLabel: l.commonCancel,
      confirmLabel: l.flagSubmit,
    );
    if (r == null || !mounted) return;
    final reason = r.note.trim().isEmpty ? r.reason : '${r.reason}: ${r.note}';
    final res = await sl<ProviderRepository>().reportPhoto(
      p.id,
      imageId,
      reason,
    );
    if (!mounted) return;
    showAiwaToast(
      context,
      res.fold((f) => l.error(f.message), (_) => l.flagThanks),
    );
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
                          body: AppLocalizations.of(
                            context,
                          ).error(state.message),
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
    final l = AppLocalizations.of(context);

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
                  EyebrowLabel(l.providerStartsAt, fontSize: 10),
                  const SizedBox(height: 2),
                  Text(
                    startsAt != null ? l.egp(startsAt) : l.providerAskProvider,
                    // screens.jsx:318 renders 22 / lh 1, no tracking.
                    style: AppTextStyles.price.copyWith(
                      fontSize: 22,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            AiwaButton(
              label: l.providerBookNow,
              icon: LucideIcons.calendarCheck,
              size: AiwaButtonSize.lg,
              // Preselects the first bookable service (screens.jsx:320).
              onPressed: p.services.any((s) => s.available)
                  ? () => _book(
                      p,
                      service: p.services.firstWhere((s) => s.available),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  double get _coverHeight => 280;

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
    final l = AppLocalizations.of(context);
    final category = p.categories.isNotEmpty
        ? p.categories.map(l.category).join(' · ')
        : null;
    return SizedBox(
      height: _coverHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (p.profileImageUrl != null && p.profileImageUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: ApiConstants.mediaUrl(p.profileImageUrl!),
              fit: BoxFit.cover,
              memCacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round(),
              errorWidget: (_, _, _) =>
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
                    AppColors.plum900.withValues(alpha: 0.55),
                  ],
                  stops: const [0.35, 1],
                ),
              ),
            ),
          PositionedDirectional(
            top: top + 12,
            start: 18,
            end: 18,
            child: Row(
              children: [
                AiwaIconButton(
                  icon: LucideIcons.arrowLeftDir,
                  variant: AiwaIconButtonVariant.glass,
                  onTap: () => context.pop(),
                ),
                const Spacer(),
                AiwaIconButton(
                  icon: LucideIcons.share2,
                  variant: AiwaIconButtonVariant.glass,
                  onTap: () => _share(p),
                ),
                const SizedBox(width: 8),
                AiwaIconButton(
                  icon: isSaved ? Icons.favorite_rounded : LucideIcons.heart,
                  iconColor: isSaved ? AppColors.rose500 : null,
                  variant: AiwaIconButtonVariant.glass,
                  onTap: _toggleSave,
                ),
              ],
            ),
          ),
          PositionedDirectional(
            start: AppTheme.gutter,
            end: AppTheme.gutter,
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
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    _CoverMeta(
                      icon: LucideIcons.star,
                      iconColor: AppColors.gold300,
                      text: p.totalReviews > 0
                          ? '${p.averageRating.toStringAsFixed(1)} (${p.totalReviews})'
                          : l.providerNew,
                      bold: true,
                    ),
                    if (p.address != null && p.address!.isNotEmpty) ...[
                      MetaDot(color: AppColors.rose300, gap: 0),
                      _CoverMeta(
                        icon: LucideIcons.mapPin,
                        // DISC-08-F5: 'distance · area' once we know where
                        // the user is; the address alone otherwise.
                        text: HomePage.hasFix && p.latitude != null && p.longitude != null
                            ? '${l.distanceKm((Geolocator.distanceBetween(HomePage.position.lat, HomePage.position.lng, p.latitude!, p.longitude!) / 1000).toStringAsFixed(1))} · ${p.address}'
                            : p.address!,
                      ),
                    ],
                    if (p.isVerified) ...[
                      MetaDot(color: AppColors.rose300, gap: 0),
                      _CoverMeta(
                        icon: LucideIcons.badgeCheck,
                        iconColor: AppColors.gold300,
                        text: l.providerVerified,
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
    final l = AppLocalizations.of(context);
    final bio = (p.bio != null && p.bio!.trim().isNotEmpty)
        ? p.bio!
        : l.providerBioFallback;
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
            bio,
            textDirection: textDirectionOf(bio),
            style: AppTextStyles.bodySm.copyWith(color: AppColors.ink2),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (p.phone.isNotEmpty)
                AiwaChip(
                  label: l.providerCall,
                  icon: LucideIcons.phone,
                  onTap: () => _launch('tel:${p.phone}'),
                ),
              if (p.phone.isNotEmpty)
                AiwaChip(
                  label: l.providerWhatsApp,
                  icon: LucideIcons.messageSquare,
                  onTap: () => _launch(
                    'https://wa.me/${p.phone.replaceAll(RegExp(r'[^0-9]'), '')}',
                  ),
                ),
              if (p.latitude != null && p.longitude != null)
                AiwaChip(
                  label: l.bookingsDirections,
                  icon: LucideIcons.map,
                  onTap: () => _launch(
                    'https://maps.google.com/?q=${p.latitude},${p.longitude}',
                  ),
                ),
              AiwaChip(
                label: l.providerReport,
                icon: LucideIcons.flag,
                onTap: _isSignedIn
                    ? () => showFlagProviderSheet(
                        context,
                        providerId: p.id,
                        providerName: p.displayName,
                      )
                    // POST /complaints needs a reporter account.
                    : () => context.push(AppRoutes.authGate),
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
    final l = AppLocalizations.of(context);
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
            SliverToBoxAdapter(
              child: EmptyState(
                icon: LucideIcons.star,
                title: l.providerNoReviews,
                subtitle: l.providerNoReviewsBody,
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
                  borderRadius: BorderRadius.circular(AppTheme.radius14),
                ),
                child: Row(
                  children: [
                    Text(
                      p.averageRating.toStringAsFixed(1),
                      style: AppTextStyles.display.copyWith(
                        fontSize: 38,
                        height: 1,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StarRating(value: p.averageRating),
                        const SizedBox(height: 2),
                        Text(
                          l.providerBasedOn(p.totalReviews),
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
            SliverToBoxAdapter(
              child: EmptyState(
                icon: LucideIcons.images,
                title: l.providerNoPhotos,
                subtitle: l.providerNoPhotosBody,
                compact: true,
              ),
            ),
          ];
        }
        return [
          if (p.galleryIds.isNotEmpty)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad.left, 0, pad.right, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  l.providerReportPhotoHint,
                  style: AppTextStyles.micro.copyWith(color: AppColors.ink4),
                ),
              ),
            ),
          SliverPadding(
            padding: pad,
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              delegate: SliverChildBuilderDelegate((_, i) {
                final url = p.galleryImages[i];
                final imageId = p.galleryIds[url];
                return GestureDetector(
                  // Press and hold to report (feeds admin photo moderation).
                  onLongPress: imageId == null
                      ? null
                      : () => _reportPhoto(p, imageId),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    child: CachedNetworkImage(
                      imageUrl: ApiConstants.mediaUrl(url),
                      fit: BoxFit.cover,
                      memCacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context) / 3).round(),
                      placeholder: (_, _) => const ShimmerBox(height: 120),
                      errorWidget: (_, _, _) =>
                          Container(color: AppColors.cream),
                    ),
                  ),
                );
              }, childCount: p.galleryImages.length),
            ),
          ),
        ];
      default:
        if (p.services.isEmpty) {
          return [
            SliverToBoxAdapter(
              child: EmptyState(
                icon: LucideIcons.scissors,
                title: l.providerNoServices,
                subtitle: l.providerNoServicesBody,
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
                  onBook: () => _book(p, service: p.services[i]),
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
        icon == LucideIcons.star
            ? AiwaStar(size: 13, color: iconColor ?? AppColors.bone)
            : Icon(icon, size: 13, color: iconColor ?? AppColors.bone),
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
    final l = AppLocalizations.of(context);
    final tabs = [
      ('services', l.providerTabServices),
      ('reviews', l.providerTabReviews),
      ('gallery', l.providerTabGallery),
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: tabs.indexed.expand((e) {
          final (i, t) = e;
          final on = t.$1 == active;
          return [
            if (i > 0) const SizedBox(width: 6),
            Expanded(
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
                      height: 1.3,
                      color: on ? AppColors.plum700 : AppColors.ink3,
                    ),
                  ),
                ),
              ),
            ),
          ];
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
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      AppLocalizations.of(
                        context,
                      ).durationLabel(service.durationMinutes),
                      style: AppTextStyles.micro.copyWith(fontSize: 12),
                    ),
                    if (!available) ...[
                      const MetaDot(),
                      Text(
                        AppLocalizations.of(context).providerUnavailable,
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
            AppLocalizations.of(context).egp(service.price),
            style: AppTextStyles.h4.copyWith(fontSize: 18, height: 1),
          ),
          const SizedBox(width: 12),
          PressScale(
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
                  LucideIcons.plus,
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
                  Text(
                    AppLocalizations.of(context).relativeDay(review.createdAt),
                    style: AppTextStyles.micro,
                  ),
                ],
              ),
              StarRating(value: review.rating, size: 11),
              if (review.comment != null && review.comment!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  review.comment!,
                  textDirection: textDirectionOf(review.comment!),
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
