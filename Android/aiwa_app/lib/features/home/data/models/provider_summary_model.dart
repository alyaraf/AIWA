import '../../domain/entities/provider_summary_entity.dart';

class ProviderSummaryModel extends ProviderSummaryEntity {
  const ProviderSummaryModel({
    required super.id,
    required super.businessName,
    super.bio,
    required super.primaryCategory,
    super.averageRating,
    required super.totalReviews,
    required super.verificationStatus,
    super.latitude,
    super.longitude,
    super.address,
    super.distanceKm,
    super.startingPrice,
    required super.ownerName,
    super.profileImageUrl,
    super.galleryImages,
    super.saved,
    super.openNow,
  });

  factory ProviderSummaryModel.fromJson(Map<String, dynamic> json) {
    // Handle the nested user object for provider name
    final user = json['user'] as Map<String, dynamic>?;

    // Find starting price from services if provided
    final services = json['services'] as List<dynamic>?;
    double? startingPrice;
    if (services != null && services.isNotEmpty) {
      startingPrice = services
          .map((s) => (s['price'] as num?)?.toDouble() ?? double.infinity)
          .reduce((a, b) => a < b ? a : b);
      if (startingPrice == double.infinity) startingPrice = null;
    } else if (json['startingPrice'] != null) {
      startingPrice = (json['startingPrice'] as num).toDouble();
    }

    return ProviderSummaryModel(
      id: json['id'] as int,
      businessName: json['businessName'] as String,
      bio: json['bio'] as String?,
      primaryCategory: json['primaryCategory'] as String? ?? 'OTHER',
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      totalReviews: json['totalReviews'] as int? ?? 0,
      verificationStatus:
          json['verificationStatus'] as String? ?? 'PENDING_VERIFICATION',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      address: json['address'] as String?,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      startingPrice: startingPrice,
      ownerName:
          user?['fullName'] as String? ?? json['ownerName'] as String? ?? '',
      profileImageUrl:
          user?['profileImageUrl'] as String? ??
          json['profileImageUrl'] as String?,
      galleryImages:
          (json['galleryImages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      saved: json['saved'] as bool? ?? false,
      // ProviderSummaryDto.openNow = accepting bookings AND inside today's
      // working hours (Cairo time). Older payloads without it fall back to the
      // mode flags alone.
      openNow:
          json['openNow'] as bool? ??
          (json['vacationMode'] != true &&
              json['offlineMode'] != true &&
              json['settlementPaused'] != true),
    );
  }
}
