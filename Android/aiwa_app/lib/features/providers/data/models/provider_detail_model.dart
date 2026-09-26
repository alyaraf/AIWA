import '../../domain/entities/provider_detail_entity.dart';

class ProviderDetailModel extends ProviderDetailEntity {
  const ProviderDetailModel({
    required super.id,
    required super.providerName,
    super.businessName,
    super.bio,
    super.profileImageUrl,
    super.galleryImages,
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
  });

  factory ProviderDetailModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? json;
    final profile =
        json['providerProfile'] as Map<String, dynamic>? ?? {};

    final rawServices = json['services'] as List<dynamic>? ?? [];
    final services = rawServices
        .map((s) => ServiceModel.fromJson(s as Map<String, dynamic>))
        .toList();

    final rawReviews = json['reviews'] as List<dynamic>? ?? [];
    final reviews = rawReviews
        .map((r) => ReviewSummaryModel.fromJson(r as Map<String, dynamic>))
        .toList();

    final rawGallery = json['galleryImages'] as List<dynamic>? ?? [];
    final gallery = rawGallery.map((e) => e.toString()).toList();

    final rawCats = profile['categories'] as List<dynamic>? ??
        json['categories'] as List<dynamic>? ?? [];
    final categories = rawCats.map((c) => c.toString()).toList();

    return ProviderDetailModel(
      id: (json['id'] ?? user['id']).toString(),
      providerName: user['fullName'] as String? ?? '',
      businessName: profile['businessName'] as String?,
      bio: profile['bio'] as String?,
      profileImageUrl: user['profileImageUrl'] as String?,
      galleryImages: gallery,
      email: user['email'] as String? ?? '',
      phone: user['phone'] as String? ?? '',
      categories: categories,
      address: profile['address'] as String?,
      latitude: (profile['latitude'] as num?)?.toDouble(),
      longitude: (profile['longitude'] as num?)?.toDouble(),
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: (json['totalReviews'] as int?) ?? 0,
      totalBookings: (json['totalBookings'] as int?) ?? 0,
      isVerified: profile['verified'] as bool? ?? false,
      isActive: user['active'] as bool? ?? true,
      services: services,
      reviews: reviews,
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
      available: json['available'] as bool? ?? true,
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
    final customer =
        json['customer'] as Map<String, dynamic>? ?? {};
    return ReviewSummaryModel(
      id: json['id'].toString(),
      customerName:
          customer['fullName'] as String? ?? 'Anonymous',
      customerImageUrl: customer['profileImageUrl'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      comment: json['comment'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
