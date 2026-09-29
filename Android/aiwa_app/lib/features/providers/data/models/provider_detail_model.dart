import '../../domain/entities/provider_detail_entity.dart';

class ProviderDetailModel extends ProviderDetailEntity {
  const ProviderDetailModel({
    required super.id,
    required super.providerName,
    super.businessName,
    super.bio,
    super.profileImageUrl,
    super.galleryImages,
    super.galleryIds,
    required super.email,
    required super.phone,
    required super.categories,
    super.address,
    super.latitude,
    super.longitude,
    required super.averageRating,
    required super.totalReviews,
    required super.totalBookings,
    required super.isVerified,
    required super.isActive,
    super.services,
    super.reviews,
    super.availableSlots,
    super.providerType,
    super.staff,
    super.offlineMode,
    super.vacationMode,
    super.settlementPaused,
  });

  /// Backend ProviderDetailDto is flat; the account sits under `owner`.
  /// Reviews come from GET /providers/{id}/reviews, passed in separately.
  factory ProviderDetailModel.fromJson(
    Map<String, dynamic> json, {
    List<ReviewSummaryModel> reviews = const [],
  }) {
    final owner = json['owner'] as Map<String, dynamic>? ?? const {};
    return ProviderDetailModel(
      id: json['id'].toString(),
      providerName: owner['fullName'] as String? ?? '',
      businessName: json['businessName'] as String?,
      bio: json['bio'] as String?,
      profileImageUrl: owner['profileImageUrl'] as String?,
      galleryImages: (json['galleryImages'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      galleryIds: {
        for (final g in json['gallery'] as List<dynamic>? ?? const [])
          if (g is Map && g['url'] != null && g['id'] != null)
            '${g['url']}': '${g['id']}',
      },
      email: owner['email'] as String? ?? '',
      phone: owner['phone'] as String? ?? '',
      categories: [
        if (json['primaryCategory'] != null) json['primaryCategory'] as String,
      ],
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: (json['totalReviews'] as num?)?.toInt() ?? 0,
      // ponytail: ProviderDetailDto has no booking count; nothing shows it.
      totalBookings: 0,
      isVerified: json['verificationStatus'] == 'APPROVED',
      isActive: owner['active'] as bool? ?? true,
      services: (json['services'] as List<dynamic>? ?? const [])
          .map((s) => ServiceModel.fromJson(s as Map<String, dynamic>))
          .toList(),
      reviews: reviews,
      providerType: json['providerType'] as String? ?? 'INDIVIDUAL',
      offlineMode: json['offlineMode'] as bool? ?? false,
      vacationMode: json['vacationMode'] as bool? ?? false,
      settlementPaused: json['settlementPaused'] as bool? ?? false,
      staff: [
        for (final m in json['staffMembers'] as List<dynamic>? ?? const [])
          if ((m as Map<String, dynamic>)['active'] != false)
            StaffEntity(
              id: m['id'].toString(),
              fullName: m['fullName'] as String? ?? '',
              title: m['title'] as String?,
            ),
      ],
    );
  }
}

class ServiceModel extends ServiceEntity {
  const ServiceModel({
    required super.id,
    required super.name,
    super.description,
    required super.price,
    required super.durationMinutes,
    required super.available,
    super.category,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      durationMinutes: (json['durationMinutes'] as int?) ?? 60,
      available: json['active'] as bool? ?? true,
      category: json['category'] as String?,
    );
  }
}

class ReviewSummaryModel extends ReviewSummaryEntity {
  const ReviewSummaryModel({
    required super.id,
    required super.customerName,
    super.customerImageUrl,
    required super.rating,
    super.comment,
    required super.createdAt,
  });

  factory ReviewSummaryModel.fromJson(Map<String, dynamic> json) {
    // ReviewDto sends the author as `user`.
    final customer =
        (json['user'] ?? json['customer'] ?? const {}) as Map<String, dynamic>;
    return ReviewSummaryModel(
      id: json['id'].toString(),
      customerName: customer['fullName'] as String? ?? 'Anonymous',
      customerImageUrl: customer['profileImageUrl'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      comment: json['comment'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
