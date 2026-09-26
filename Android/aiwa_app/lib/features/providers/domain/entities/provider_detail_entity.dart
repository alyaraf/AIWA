import 'package:equatable/equatable.dart';

class ProviderDetailEntity extends Equatable {
  final String id;
  final String providerName;
  final String? businessName;
  final String? bio;
  final String? profileImageUrl;
  final List<String> galleryImages;
  final String email;
  final String phone;
  final List<String> categories;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double averageRating;
  final int totalReviews;
  final int totalBookings;
  final bool isVerified;
  final bool isActive;
  final List<ServiceEntity> services;
  final List<ReviewSummaryEntity> reviews;
  final List<AvailabilitySlot> availableSlots;

  const ProviderDetailEntity({
    required this.id,
    required this.providerName,
    this.businessName,
    this.bio,
    this.profileImageUrl,
    this.galleryImages = const [],
    required this.email,
    required this.phone,
    required this.categories,
    this.address,
    this.latitude,
    this.longitude,
    required this.averageRating,
    required this.totalReviews,
    required this.totalBookings,
    required this.isVerified,
    required this.isActive,
    this.services = const [],
    this.reviews = const [],
    this.availableSlots = const [],
  });

  String get displayName => businessName ?? providerName;

  @override
  List<Object?> get props => [id, providerName, businessName];
}

class ServiceEntity extends Equatable {
  final String id;
  final String name;
  final String? description;
  final double price;
  final int durationMinutes;
  final bool available;
  final String? category;

  const ServiceEntity({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.durationMinutes,
    required this.available,
    this.category,
  });

  @override
  List<Object?> get props => [id, name, price, durationMinutes];
}

class ReviewSummaryEntity extends Equatable {
  final String id;
  final String customerName;
  final String? customerImageUrl;
  final double rating;
  final String? comment;
  final DateTime createdAt;

  const ReviewSummaryEntity({
    required this.id,
    required this.customerName,
    this.customerImageUrl,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id];
}

class AvailabilitySlot extends Equatable {
  final DateTime date;
  final List<String> times;

  const AvailabilitySlot({required this.date, required this.times});

  @override
  List<Object?> get props => [date, times];
}
