import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/api_constants.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

enum AvatarPalette { plum, rose, gold, cream }

class AiwaAvatar extends StatelessWidget {
  final String name;
  final double size;
  final AvatarPalette palette;
  final bool verified;
  final String? imageUrl;

  const AiwaAvatar({
    super.key,
    required this.name,
    this.size = 44,
    this.palette = AvatarPalette.plum,
    this.verified = false,
    this.imageUrl,
  });

  /// Stable palette per provider id, so an avatar looks the same everywhere.
  static AvatarPalette paletteFor(String id) =>
      AvatarPalette.values[id.hashCode % AvatarPalette.values.length];

  static AvatarPalette paletteFromString(String? p) {
    switch (p) {
      case 'rose':
        return AvatarPalette.rose;
      case 'gold':
        return AvatarPalette.gold;
      case 'cream':
        return AvatarPalette.cream;
      default:
        return AvatarPalette.plum;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _gradient();
    final textColor =
        (palette == AvatarPalette.rose || palette == AvatarPalette.cream)
        ? AppColors.plum900
        : AppColors.bone;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final badgeSize = (size * 0.32).clamp(14.0, 22.0);

    Widget avatar;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      avatar = CachedNetworkImage(
        imageUrl: ApiConstants.mediaUrl(imageUrl!),
        imageBuilder: (_, imageProvider) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
          ),
        ),
        placeholder: (_, __) => _initials(initial, textColor, gradient),
        errorWidget: (_, __, ___) => _initials(initial, textColor, gradient),
      );
    } else {
      avatar = _initials(initial, textColor, gradient);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        if (verified)
          PositionedDirectional(
            bottom: -1,
            end: -1,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold500,
                border: Border.all(color: AppColors.paper, width: 2),
              ),
              child: Icon(
                LucideIcons.check,
                size: math.max(8, size * 0.18),
                color: AppColors.paper,
              ),
            ),
          ),
      ],
    );
  }

  Widget _initials(String initial, Color textColor, List<Color> gradient) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppTextStyles.h4.copyWith(
          fontSize: size * 0.42,
          color: textColor,
          height: 1,
        ),
      ),
    );
  }

  List<Color> _gradient() {
    switch (palette) {
      case AvatarPalette.plum:
        return [AppColors.plum500, AppColors.plum700];
      case AvatarPalette.rose:
        return [AppColors.rose300, AppColors.rose500];
      case AvatarPalette.gold:
        return [AppColors.gold300, AppColors.gold700];
      case AvatarPalette.cream:
        return [AppColors.cream, AppColors.gold300];
    }
  }
}
