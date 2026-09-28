import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/aiwa_avatar.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../domain/entities/provider_summary_entity.dart';
import 'provider_card.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Row card for a provider.
///
/// Home "Available now" (default): 16px radius, 52px avatar, rating with
/// review count and a "From EGP" price on the right.
/// Discover ([showPrice] = false): 18px radius, 56px avatar, larger name and
/// a chevron instead of the price — as in the design kit.
class ProviderListItem extends StatelessWidget {
  final ProviderSummaryEntity provider;
  final VoidCallback onTap;
  final bool showPrice;

  const ProviderListItem({
    super.key,
    required this.provider,
    required this.onTap,
    this.showPrice = true,
  });

  @override
  Widget build(BuildContext context) {
    final discover = !showPrice;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(discover ? 14 : 12),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(discover ? 18 : 16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            AiwaAvatar(
              name: provider.businessName,
              size: discover ? 56 : 52,
              verified: provider.isVerified,
              imageUrl: provider.profileImageUrl,
              palette: _paletteFor(provider.id),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.businessName,
                    style: AppTextStyles.h4.copyWith(
                      fontSize: discover ? 18 : 17,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.of(
                      context,
                    ).category(provider.primaryCategory),
                    style: AppTextStyles.micro.copyWith(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: RatingMeta(
                      rating: provider.averageRating,
                      reviews: discover ? null : provider.totalReviews,
                      distance: AppLocalizations.of(
                        context,
                      ).distance(provider.distanceKm),
                      openNow: provider.openNow,
                      openLabel: discover
                          ? AppLocalizations.of(context).homeOpen
                          : null,
                      gap: 8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (!discover)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  EyebrowLabel(
                    AppLocalizations.of(context).homeFrom,
                    fontSize: 9,
                  ),
                  Text(
                    // ponytail: '—' until ProviderSummaryDto sends startingPrice.
                    provider.startingPrice != null
                        ? AppLocalizations.of(
                            context,
                          ).egp(provider.startingPrice!)
                        : '—',
                    style: AppTextStyles.h4.copyWith(fontSize: 17, height: 1),
                  ),
                ],
              )
            else
              Icon(
                LucideIcons.chevronRightDir,
                size: 18,
                color: AppColors.ink3,
              ),
          ],
        ),
      ),
    );
  }

  static AvatarPalette _paletteFor(int id) {
    const palettes = AvatarPalette.values;
    return palettes[id.abs() % palettes.length];
  }
}
