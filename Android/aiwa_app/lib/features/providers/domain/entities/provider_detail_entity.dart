import 'package:equatable/equatable.dart';

class ProviderDetailEntity extends Equatable {
  final String id;
  final String providerName;
  final String? businessName;
  final String? bio;
  final String? profileImageUrl;
  final List<String> galleryImages;

  /// Photo url → gallery image id (ProviderDetailDto.gallery), for reports.
  final Map<String, String> galleryIds;
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

  /// ProviderDetailDto.providerType: 'INDIVIDUAL' or 'SHOP'.
  final String providerType;
  final List<StaffEntity> staff;

  /// ProviderDetailDto flags that block Book Now (BOOK-03..06).
  final bool offlineMode;
  final bool vacationMode;
  final bool settlementPaused;

  /// An individual provider is with another client right now (BOOK-04).
  final bool busyNow;

  const ProviderDetailEntity({
    required this.id,
    required this.providerName,
    this.businessName,
    this.bio,
    this.profileImageUrl,
    this.galleryImages = const [],
    this.galleryIds = const {},
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
    this.providerType = 'INDIVIDUAL',
    this.staff = const [],
    this.offlineMode = false,
    this.vacationMode = false,
    this.settlementPaused = false,
    this.busyNow = false,
  });

  String get displayName => businessName ?? providerName;
  bool get isShop => providerType == 'SHOP';

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

  /// Free start times.
  final List<String> times;

  /// Taken start times — shown struck through (BOOK-08-F5).
  final List<String> booked;

  const AvailabilitySlot({
    required this.date,
    required this.times,
    this.booked = const [],
  });

  @override
  List<Object?> get props => [date, times, booked];
}

/// ProviderDetailDto.staffMembers (StaffMemberDto).
class StaffEntity extends Equatable {
  final String id;
  final String fullName;
  final String? title;

  const StaffEntity({required this.id, required this.fullName, this.title});

  @override
  List<Object?> get props => [id];
}
