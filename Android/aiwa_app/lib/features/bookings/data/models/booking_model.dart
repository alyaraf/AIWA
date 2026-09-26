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
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final provider =
        json['provider'] as Map<String, dynamic>? ?? {};
    final providerProfile =
        provider['providerProfile'] as Map<String, dynamic>? ?? {};
    final service =
        json['service'] as Map<String, dynamic>? ?? {};

    return BookingModel(
      id: json['id'].toString(),
      providerId: (provider['id'] ?? json['providerId'] ?? '').toString(),
      providerName: provider['fullName'] as String? ?? '',
      providerBusinessName: providerProfile['businessName'] as String?,
      providerImageUrl: provider['profileImageUrl'] as String?,
      serviceId: (service['id'] ?? json['serviceId'] ?? '').toString(),
      serviceName: service['name'] as String? ?? '',
      servicePrice: (service['price'] as num?)?.toDouble() ?? 0.0,
      serviceDurationMinutes:
          (service['durationMinutes'] as int?) ?? 60,
      scheduledDate: json['scheduledDate'] as String? ?? '',
      scheduledTime: json['scheduledTime'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      customerNote: json['customerNote'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      providerAddress: providerProfile['address'] as String?,
    );
  }
}
