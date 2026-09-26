import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_icon_button.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../providers/domain/usecases/save_provider_usecase.dart';
import '../../domain/entities/provider_summary_entity.dart';

/// 200px carousel card — home "Trending near you".
class ProviderCard extends StatelessWidget {
  final ProviderSummaryEntity provider;
  final VoidCallback onTap;

  const ProviderCard({super.key, required this.provider, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 110,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CoverImage(
                    url: provider.profileImageUrl,
                    initial: provider.businessName,
                  ),
                  if (provider.isVerified)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.paper,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              size: 11,
                              color: AppColors.gold500,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Verified',
                              style: AppTextStyles.labelSm.copyWith(
                                fontSize: 10,
                                color: AppColors.gold700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: SaveHeartButton(providerId: provider.id.toString()),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EyebrowLabel(provider.categoryLabel, fontSize: 10),
                  const SizedBox(height: 2),
                  Text(
                    provider.businessName,
                    style: AppTextStyles.h4.copyWith(fontSize: 17, height: 1.1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  RatingMeta(
                    rating: provider.averageRating,
                    distance: provider.distanceText,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 32px glass heart on a card cover — saves / unsaves the provider.
/// Guests are sent to the sign-in gate instead.
class SaveHeartButton extends StatefulWidget {
  final String providerId;
  final bool initiallySaved;

  const SaveHeartButton({
    super.key,
    required this.providerId,
    this.initiallySaved = false,
  });

  @override
  State<SaveHeartButton> createState() => _SaveHeartButtonState();
}

class _SaveHeartButtonState extends State<SaveHeartButton> {
  late bool _saved = widget.initiallySaved;
  bool _busy = false;

  Future<void> _toggle() async {
    if (context.read<AuthBloc>().state is! AuthAuthenticated) {
      context.push(AppRoutes.authGate);
      return;
    }
    if (_busy) return;
    final next = !_saved;
    setState(() {
      _saved = next;
      _busy = true;
    });
    final useCase = sl<SaveProviderUseCase>();
    final result = next
        ? await useCase.save(widget.providerId)
        : await useCase.unsave(widget.providerId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      // Roll back the optimistic toggle if the request failed.
      result.fold((_) => _saved = !next, (_) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return AiwaIconButton(
      icon: _saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      iconColor: _saved ? AppColors.rose500 : null,
      variant: AiwaIconButtonVariant.glass,
      size: 32,
      onTap: _toggle,
    );
  }
}

/// Gradient placeholder cover (or the real photo when there is one).
class CoverImage extends StatelessWidget {
  final String? url;
  final String initial;
  final bool showInitial;

  /// Large profile cover: steeper gradient plus a second, gold glow.
  final bool hero;

  const CoverImage({
    super.key,
    this.url,
    required this.initial,
    this.showInitial = false,
    this.hero = false,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: hero ? const Alignment(-0.35, -1) : Alignment.topLeft,
          end: hero ? const Alignment(0.35, 1) : Alignment.bottomRight,
          colors: [AppColors.plum500, AppColors.plum700, AppColors.plum900],
          stops: hero ? const [0, 0.5, 1] : const [0, 0.6, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hero) ...[
            Positioned(
              left: -60,
              top: -20,
              child: AiwaGlow(
                size: 280,
                color: AppColors.rose300,
                opacity: 0.4,
              ),
            ),
            Positioned(
              right: -80,
              bottom: -60,
              child: AiwaGlow(
                size: 280,
                color: AppColors.gold300,
                opacity: 0.25,
              ),
            ),
          ] else
            Positioned(
              left: -30,
              top: -40,
              child: AiwaGlow(size: 160, color: AppColors.rose300),
            ),
          if (showInitial && initial.isNotEmpty)
            Center(
              child: Text(
                initial[0].toUpperCase(),
                style: AppTextStyles.display.copyWith(
                  fontSize: 48,
                  color: AppColors.bone.withOpacity(0.9),
                  height: 1,
                ),
              ),
            ),
        ],
      ),
    );
    if (url == null || url!.isEmpty) return placeholder;
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) => placeholder,
    );
  }
}

/// ★ 4.9 (312) · 1.2 km · Open now
class RatingMeta extends StatelessWidget {
  final double? rating;
  final int? reviews;
  final String distance;
  final bool openNow;

  const RatingMeta({
    super.key,
    this.rating,
    this.reviews,
    this.distance = '',
    this.openNow = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.micro.copyWith(
      fontSize: 12,
      color: AppColors.ink2,
      height: 1.2,
    );
    final parts = <Widget>[];
    if (rating != null && rating! > 0) {
      parts.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: 12, color: AppColors.gold500),
            const SizedBox(width: 2),
            Text(
              reviews != null
                  ? '${rating!.toStringAsFixed(1)} ($reviews)'
                  : rating!.toStringAsFixed(1),
              style: style.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    } else {
      parts.add(
        Text('New', style: style.copyWith(fontWeight: FontWeight.w600)),
      );
    }
    if (distance.isNotEmpty) {
      parts.add(const MetaDot());
      parts.add(Text(distance, style: style));
    }
    if (openNow) {
      parts.add(const MetaDot());
      parts.add(
        Text(
          'Open now',
          style: style.copyWith(
            color: AppColors.success700,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: parts);
  }
}
