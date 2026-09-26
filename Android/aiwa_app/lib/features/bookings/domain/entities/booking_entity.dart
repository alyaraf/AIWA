import 'package:equatable/equatable.dart';

class BookingEntity extends Equatable {
  final String id;
  final String providerId;
  final String providerName;
  final String? providerBusinessName;
  final String? providerImageUrl;
  final String serviceId;
  final String serviceName;
  final double servicePrice;
  final int serviceDurationMinutes;
  final String scheduledDate;
  final String scheduledTime;
  final String status;
  final String? customerNote;
  final DateTime createdAt;
  final String? providerAddress;

  const BookingEntity({
    required this.id,
    required this.providerId,
    required this.providerName,
    this.providerBusinessName,
    this.providerImageUrl,
    required this.serviceId,
    required this.serviceName,
    required this.servicePrice,
    required this.serviceDurationMinutes,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.status,
    this.customerNote,
    required this.createdAt,
    this.providerAddress,
  });

  String get displayProviderName => providerBusinessName ?? providerName;

  bool get canCancel =>
      status == 'PENDING' || status == 'ACCEPTED';

  bool get canReview => status == 'COMPLETED';

  DateTime get scheduledDateTime {
    try {
      return DateTime.parse('$scheduledDate $scheduledTime');
    } catch (_) {
      return DateTime.now();
    }
  }

  @override
  List<Object?> get props =>
      [id, providerId, serviceId, scheduledDate, scheduledTime, status];
}
