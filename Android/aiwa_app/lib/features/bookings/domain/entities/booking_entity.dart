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
  final String? customerName;

  // Live-booking fields (BookingDto).
  final bool homeService;
  final double? travelFee;
  final String? paymentStatus;
  final String? cancelledBy;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final String? rejectionReason;
  final bool penaltyApplied;
  final String? proposedDate;
  final String? proposedStartTime;
  final DateTime? checkedInAt;
  final bool reviewed;
  final String? providerCategory;
  final double? providerLat;
  final double? providerLng;
  final bool providerVerified;

  /// ProviderSummaryDto.distanceKm — null unless the backend computed it.
  final double? providerDistanceKm;

  // Provider-side view.
  final String? customerAddress;
  final int? customerBookingCount;
  final double? commissionAmount;

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
    this.customerName,
    this.homeService = false,
    this.travelFee,
    this.paymentStatus,
    this.cancelledBy,
    this.cancelledAt,
    this.cancellationReason,
    this.rejectionReason,
    this.penaltyApplied = false,
    this.proposedDate,
    this.proposedStartTime,
    this.checkedInAt,
    this.reviewed = false,
    this.providerCategory,
    this.providerLat,
    this.providerLng,
    this.providerVerified = false,
    this.providerDistanceKm,
    this.customerAddress,
    this.customerBookingCount,
    this.commissionAmount,
  });

  String get displayProviderName => providerBusinessName ?? providerName;

  /// Service part of [servicePrice] (which is BookingDto.totalPrice).
  double get basePrice => servicePrice - (travelFee ?? 0);

  bool get canCancel => status == 'PENDING' || status == 'ACCEPTED';

  bool get canReview => status == 'COMPLETED' && !reviewed;

  /// PaymentStatus CASH_CONFIRMED / DISPUTED / PAID: the customer already
  /// answered "Did you pay?".
  bool get paymentSettled =>
      const {'CASH_CONFIRMED', 'DISPUTED', 'PAID'}.contains(paymentStatus);

  bool get hasProposal => proposedDate != null && proposedStartTime != null;

  DateTime get scheduledDateTime {
    try {
      return DateTime.parse('$scheduledDate $scheduledTime');
    } catch (_) {
      return DateTime.now();
    }
  }

  @override
  List<Object?> get props => [
    id,
    providerId,
    serviceId,
    scheduledDate,
    scheduledTime,
    status,
    paymentStatus,
    checkedInAt,
    proposedDate,
    proposedStartTime,
    reviewed,
    travelFee,
  ];
}
