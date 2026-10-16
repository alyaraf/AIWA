import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final int id;
  final String fullName;
  final String? email;

  /// GET /auth/me: an email waiting for its code (CR-05); not yet the sign-in.
  final String? pendingEmail;
  final String? phone;
  final String role;
  final String? gender;
  final String? profileImageUrl;
  final bool active;
  final String preferredLanguage;
  final bool termsAccepted;
  final String? acceptedTermsVersion;
  final DateTime? termsAcceptedAt;

  /// GET /auth/me: false when a newer policy for this role is live.
  final bool? termsUpToDate;
  final double? searchRadiusMinKm;
  final double? searchRadiusMaxKm;
  final ProviderProfileSummary? providerProfile;

  /// How far a provider got through sign-up, from the server's own records (M-05): NO_PROFILE, NEEDS_DOCUMENTS or
  /// SUBMITTED; null for everyone else (and for an older backend).
  final String? providerOnboarding;

  const UserEntity({
    required this.id,
    required this.fullName,
    this.email,
    this.pendingEmail,
    this.phone,
    required this.role,
    this.gender,
    this.profileImageUrl,
    required this.active,
    required this.preferredLanguage,
    required this.termsAccepted,
    this.acceptedTermsVersion,
    this.termsAcceptedAt,
    this.termsUpToDate,
    this.searchRadiusMinKm,
    this.searchRadiusMaxKm,
    this.providerProfile,
    this.providerOnboarding,
  });

  bool get isCustomer => role == 'CUSTOMER';
  bool get isProvider => role == 'PROVIDER';
  bool get isAdmin => role == 'ADMIN';

  /// A newer policy went live since this user last accepted (GET /auth/me
  /// termsUpToDate). Users who never accepted are still in sign-up, which
  /// accepts on its own.
  bool get needsTermsReaccept =>
      termsUpToDate == false && acceptedTermsVersion != null;

  @override
  List<Object?> get props => [
    id,
    fullName,
    email,
    pendingEmail,
    phone,
    role,
    gender,
    profileImageUrl,
    active,
    preferredLanguage,
    termsAccepted,
    acceptedTermsVersion,
    termsAcceptedAt,
    termsUpToDate,
    providerOnboarding,
  ];
}

class ProviderProfileSummary extends Equatable {
  final int id;
  final String businessName;
  final String verificationStatus;

  /// Admin's rejection reason or "more info" request (UserDto.providerNote).
  final String? note;

  const ProviderProfileSummary({
    required this.id,
    required this.businessName,
    required this.verificationStatus,
    this.note,
  });

  bool get isApproved => verificationStatus == 'APPROVED';
  bool get isRejected => verificationStatus == 'REJECTED';
  bool get isSuspended => verificationStatus == 'SUSPENDED';

  @override
  List<Object?> get props => [id, businessName, verificationStatus, note];
}
