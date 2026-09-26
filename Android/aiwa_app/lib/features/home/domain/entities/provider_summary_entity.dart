import 'package:equatable/equatable.dart';

class ProviderSummaryEntity extends Equatable {
  final int id;
  final String businessName;
  final String? bio;
  final String primaryCategory;
  final double? averageRating;
  final int totalReviews;
  final String verificationStatus;
  final double? latitude;
  final double? longitude;
  final String? address;
  final double? distanceKm;
  final double? startingPrice;
  final String ownerName;
  final String? profileImageUrl;
  final List<String> galleryImages;

  const ProviderSummaryEntity({
    required this.id,
    required this.businessName,
    this.bio,
    required this.primaryCategory,
    this.averageRating,
    required this.totalReviews,
    required this.verificationStatus,
    this.latitude,
    this.longitude,
    this.address,
    this.distanceKm,
    this.startingPrice,
    required this.ownerName,
    this.profileImageUrl,
    this.galleryImages = const [],
  });

  bool get isVerified => verificationStatus == 'APPROVED';

  String get distanceText {
    if (distanceKm == null) return '';
    if (distanceKm! < 1) {
      return '${(distanceKm! * 1000).round()} m';
    }
    return '${distanceKm!.toStringAsFixed(1)} km';
  }

  String get categoryLabel {
    final map = {
      'HAIR': 'Hair',
      'NAILS': 'Nails',
      'SPA': 'Spa',
      'MAKEUP': 'Makeup',
      'LASHES': 'Lashes',
      'SKIN': 'Skin',
      'MASSAGE': 'Massage',
      'OTHER': 'Other',
    };
    return map[primaryCategory] ?? primaryCategory;
  }

  @override
  List<Object?> get props => [id, businessName, primaryCategory];
}
