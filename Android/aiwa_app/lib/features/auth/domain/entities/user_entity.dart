import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final int id;
  final String fullName;
  final String? email;
  final String? phone;
  final String role;
  final String? gender;
  final String? profileImageUrl;
  final bool active;
  final String preferredLanguage;
  final bool termsAccepted;
  final String? acceptedTermsVersion;
  final DateTime? termsAcceptedAt;
  final double? searchRadiusMinKm;
  final double? searchRadiusMaxKm;
  final ProviderProfileSummary? providerProfile;

  const UserEntity({
    required this.id,
    required this.fullName,
    this.email,
    this.phone,
    required this.role,
    this.gender,
    this.profileImageUrl,
    required this.active,
    required this.preferredLanguage,
    required this.termsAccepted,
    this.acceptedTermsVersion,
    this.termsAcceptedAt,
    this.searchRadiusMinKm,
    this.searchRadiusMaxKm,
    this.providerProfile,
  });

  bool get isCustomer => role == 'CUSTOMER';
  bool get isProvider => role == 'PROVIDER';
  bool get isAdmin => role == 'ADMIN';

  @override
  List<Object?> get props => [
    id,
    fullName,
    email,
    phone,
    role,
    gender,
    profileImageUrl,
    active,
    preferredLanguage,
    termsAccepted,
    acceptedTermsVersion,
    termsAcceptedAt,
  ];
}

class ProviderProfileSummary extends Equatable {
  final int id;
  final String businessName;
  final String verificationStatus;

  const ProviderProfileSummary({
    required this.id,
    required this.businessName,
    required this.verificationStatus,
  });

  bool get isApproved => verificationStatus == 'APPROVED';

  @override
  List<Object?> get props => [id, businessName, verificationStatus];
}
