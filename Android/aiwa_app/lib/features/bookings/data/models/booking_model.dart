import '../../domain/entities/booking_entity.dart';

class BookingModel extends BookingEntity {
  const BookingModel({
    required super.id,
    required super.providerId,
    required super.providerName,
    super.providerBusinessName,
    super.providerImageUrl,
    required super.serviceId,
    required super.serviceName,
    required super.servicePrice,
    required super.serviceDurationMinutes,
    required super.scheduledDate,
    required super.scheduledTime,
    required super.status,
    super.customerNote,
    required super.createdAt,
    super.providerAddress,
    super.customerName,
    super.homeService,
    super.travelFee,
    super.paymentStatus,
    super.cancelledBy,
    super.cancelledAt,
    super.cancellationReason,
    super.rejectionReason,
    super.penaltyApplied,
    super.proposedDate,
    super.proposedStartTime,
    super.checkedInAt,
    super.reviewed,
    super.providerCategory,
    super.providerLat,
    super.providerLng,
    super.providerVerified,
    super.providerDistanceKm,
    super.customerAddress,
    super.customerBookingCount,
    super.commissionAmount,
  });

  /// Backend BookingDto: provider is a flat ProviderSummaryDto.
  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final provider = json['provider'] as Map<String, dynamic>? ?? const {};
    final service = json['service'] as Map<String, dynamic>? ?? const {};
    final customer = json['customer'] as Map<String, dynamic>? ?? const {};

    return BookingModel(
      id: json['id'].toString(),
      providerId: (provider['id'] ?? '').toString(),
      providerName: provider['ownerName'] as String? ?? '',
      providerBusinessName: provider['businessName'] as String?,
      providerImageUrl: provider['profileImageUrl'] as String?,
      serviceId: (service['id'] ?? '').toString(),
      serviceName: service['name'] as String? ?? '',
      servicePrice:
          ((json['totalPrice'] ?? service['price']) as num?)?.toDouble() ?? 0.0,
      serviceDurationMinutes: (service['durationMinutes'] as int?) ?? 60,
      scheduledDate: json['bookingDate'] as String? ?? '',
      scheduledTime: json['startTime'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      customerNote: json['notes'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      providerAddress: provider['address'] as String?,
      customerName: customer['fullName'] as String?,
      homeService: json['homeService'] as bool? ?? false,
      travelFee: (json['travelFee'] as num?)?.toDouble(),
      paymentStatus: json['paymentStatus'] as String?,
      cancelledBy: json['cancelledBy'] as String?,
      cancelledAt: DateTime.tryParse(json['cancelledAt'] as String? ?? ''),
      cancellationReason: json['cancellationReason'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      penaltyApplied: json['penaltyApplied'] as bool? ?? false,
      proposedDate: json['proposedDate'] as String?,
      proposedStartTime: json['proposedStartTime'] as String?,
      checkedInAt: DateTime.tryParse(json['checkedInAt'] as String? ?? ''),
      reviewed: json['reviewed'] as bool? ?? false,
      providerCategory: provider['primaryCategory'] as String?,
      providerLat: (provider['latitude'] as num?)?.toDouble(),
      providerLng: (provider['longitude'] as num?)?.toDouble(),
      providerVerified: provider['verificationStatus'] == 'APPROVED',
      providerDistanceKm: (provider['distanceKm'] as num?)?.toDouble(),
      customerAddress:
          (json['savedAddress'] as Map<String, dynamic>?)?['addressLine']
              as String?,
      customerBookingCount: (customer['bookingCount'] as num?)?.toInt(),
      commissionAmount: (json['commissionAmount'] as num?)?.toDouble(),
    );
  }
}
