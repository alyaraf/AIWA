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

  /// ProviderSummaryDto.saved — true when the signed-in user hearted it.
  final bool saved;

  /// Derived: not on vacation, offline or settlement-paused.
  final bool openNow;

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
    this.saved = false,
    this.openNow = false,
  });

  bool get isVerified => verificationStatus == 'APPROVED';

  @override
  List<Object?> get props => [id, businessName, primaryCategory];
}
