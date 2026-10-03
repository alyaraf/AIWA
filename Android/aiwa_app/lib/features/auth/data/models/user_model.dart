import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.fullName,
    super.email,
    super.pendingEmail,
    super.phone,
    required super.role,
    super.gender,
    super.profileImageUrl,
    required super.active,
    required super.preferredLanguage,
    required super.termsAccepted,
    super.acceptedTermsVersion,
    super.termsAcceptedAt,
    super.termsUpToDate,
    super.searchRadiusMinKm,
    super.searchRadiusMaxKm,
    super.providerProfile,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      fullName: json['fullName'] as String,
      email: json['email'] as String?,
      pendingEmail: json['pendingEmail'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String,
      gender: json['gender'] as String?,
      profileImageUrl: json['profileImageUrl'] as String?,
      active: json['active'] as bool? ?? true,
      preferredLanguage: json['preferredLanguage'] as String? ?? 'EN',
      termsAccepted: json['termsAccepted'] as bool? ?? false,
      acceptedTermsVersion: json['acceptedTermsVersion'] as String?,
      termsAcceptedAt: DateTime.tryParse(
        json['termsAcceptedAt'] as String? ?? '',
      ),
      termsUpToDate: json['termsUpToDate'] as bool?,
      searchRadiusMinKm: (json['searchRadiusMinKm'] as num?)?.toDouble(),
      searchRadiusMaxKm: (json['searchRadiusMaxKm'] as num?)?.toDouble(),
      // UserDto sends the flat providerProfileId / providerStatus.
      providerProfile: json['providerProfile'] != null
          ? ProviderProfileSummaryModel.fromJson(
              json['providerProfile'] as Map<String, dynamic>,
            )
          : json['providerStatus'] != null
          ? ProviderProfileSummaryModel(
              id: (json['providerProfileId'] as num?)?.toInt() ?? 0,
              businessName: '',
              verificationStatus: json['providerStatus'] as String,
              note: json['providerNote'] as String?,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'role': role,
      'gender': gender,
      'profileImageUrl': profileImageUrl,
      'active': active,
      'preferredLanguage': preferredLanguage,
      'termsAccepted': termsAccepted,
    };
  }
}

class ProviderProfileSummaryModel extends ProviderProfileSummary {
  const ProviderProfileSummaryModel({
    required super.id,
    required super.businessName,
    required super.verificationStatus,
    super.note,
  });

  factory ProviderProfileSummaryModel.fromJson(Map<String, dynamic> json) {
    return ProviderProfileSummaryModel(
      id: json['id'] as int,
      businessName: json['businessName'] as String,
      verificationStatus:
          json['verificationStatus'] as String? ?? 'PENDING_VERIFICATION',
      note: json['rejectionReason'] as String?,
    );
  }
}
