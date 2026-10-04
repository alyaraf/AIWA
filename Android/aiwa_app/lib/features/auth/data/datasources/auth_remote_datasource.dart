import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<Map<String, String>> login({
    required String identifier,
    required String password,
  });

  Future<Map<String, String>> register({
    required String fullName,
    required String password,
    String? email,
    String? phone,
    required String role,
    String? gender,
    String? profileImageUrl,
    String? preferredLanguage,
  });

  Future<void> sendOtp({required String phone});
  Future<void> verifyOtp({required String phone, required String code});

  /// PATCH /auth/me/phone — the code was sent to the NEW number and the
  /// current password is required (CR-05). Every other session is signed
  /// out, so the returned token pair must replace ours.
  Future<Map<String, String>> changePhone({
    required String phone,
    required String code,
    required String currentPassword,
  });

  /// POST /auth/me/email/verify — confirms the email waiting in pendingEmail
  /// with the code sent to it; same fresh token pair as [changePhone].
  Future<Map<String, String>> verifyEmail({required String code});
  Future<UserModel> getCurrentUser();

  /// A changed [email] needs [currentPassword] and only becomes pendingEmail.
  Future<UserModel> updateProfile({
    String? fullName,
    String? email,
    String? currentPassword,
    String? profileImageUrl,
  });
  Future<void> updateLanguage({required String language});
  Future<void> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  });
  Future<void> uploadAvatar(String path);
  Future<void> createProviderProfile(Map<String, dynamic> profile);
  Future<void> addStaff(String fullName);
  Future<void> uploadVerificationDocuments({
    required String idFront,
    required String idBack,
    required String selfie,
  });
  Future<Map<String, dynamic>> latestTerms(String type);
  Future<void> acceptTerms(String version);
  Future<void> updatePreferences({
    required double minKm,
    required double maxKm,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient _client;
  AuthRemoteDataSourceImpl(this._client);

  /// OTP destination: the backend takes {phone} (SMS) or {email} (email code).
  /// SA-03: the receipt /auth/verify-otp hands out, kept per phone or email until
  /// register presents it. Static because the datasource is rebuilt per resolve.
  static final Map<String, String> _otpReceipts = {};

  static Map<String, String> _destination(String identifier) =>
      identifier.contains('@') ? {'email': identifier} : {'phone': identifier};

  @override
  Future<Map<String, String>> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _client.post(
      ApiConstants.login,
      data: {'identifier': identifier, 'password': password},
    );
    final data = response.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw ServerException(
        message: data['message'] as String? ?? 'Login failed',
      );
    }
    final authData = data['data'] as Map<String, dynamic>;
    return {
      'accessToken': authData['accessToken'] as String,
      'refreshToken': authData['refreshToken'] as String,
      'role': (authData['user'] as Map<String, dynamic>)['role'] as String,
      'userId': (authData['user'] as Map<String, dynamic>)['id'].toString(),
    };
  }

  @override
  Future<Map<String, String>> register({
    required String fullName,
    required String password,
    String? email,
    String? phone,
    required String role,
    String? gender,
    String? profileImageUrl,
    String? preferredLanguage,
  }) async {
    final body = <String, dynamic>{
      'fullName': fullName,
      'password': password,
      'role': role,
    };
    if (email != null) body['email'] = email;
    if (phone != null) body['phone'] = phone;
    if (gender != null) body['gender'] = gender;
    if (profileImageUrl != null) body['profileImageUrl'] = profileImageUrl;
    if (preferredLanguage != null) {
      body['preferredLanguage'] = preferredLanguage;
    }
    final receipt = _otpReceipts[phone ?? email];
    if (receipt != null) body['verificationReceipt'] = receipt;

    final response = await _client.post(ApiConstants.register, data: body);
    final data = response.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw ServerException(
        message: data['message'] as String? ?? 'Registration failed',
      );
    }
    final authData = data['data'] as Map<String, dynamic>;
    return {
      'accessToken': authData['accessToken'] as String,
      'refreshToken': authData['refreshToken'] as String,
      'role': (authData['user'] as Map<String, dynamic>)['role'] as String,
      'userId': (authData['user'] as Map<String, dynamic>)['id'].toString(),
    };
  }

  @override
  Future<void> sendOtp({required String phone}) async {
    final response = await _client.post(
      ApiConstants.sendOtp,
      data: _destination(phone),
    );
    final data = response.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw ServerException(
        message: data['message'] as String? ?? 'Failed to send OTP',
      );
    }
  }

  @override
  Future<void> verifyOtp({required String phone, required String code}) async {
    final response = await _client.post(
      ApiConstants.verifyOtp,
      data: {..._destination(phone), 'code': code},
    );
    final data = response.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw ServerException(
        message: data['message'] as String? ?? 'Invalid OTP',
      );
    }
    final receipt = (data['data'] as Map<String, dynamic>?)?['receipt'];
    if (receipt is String) _otpReceipts[phone] = receipt;
  }

  @override
  Future<Map<String, String>> changePhone({
    required String phone,
    required String code,
    required String currentPassword,
  }) async => _tokenPair(
    await _client.patch(
      ApiConstants.mePhone,
      data: {'phone': phone, 'code': code, 'currentPassword': currentPassword},
    ),
  );

  @override
  Future<Map<String, String>> verifyEmail({required String code}) async =>
      _tokenPair(await _client.post(_meEmailVerify, data: {'code': code}));

  // Not in ApiConstants: that file is outside this change's scope.
  static const _meEmailVerify = '/auth/me/email/verify';

  Map<String, String> _tokenPair(Response response) {
    final data = response.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw ServerException(message: data['message'] as String? ?? 'Failed');
    }
    final authData = data['data'] as Map<String, dynamic>;
    return {
      'accessToken': authData['accessToken'] as String,
      'refreshToken': authData['refreshToken'] as String,
    };
  }

  @override
  Future<UserModel> getCurrentUser() async {
    final response = await _client.get(ApiConstants.me);
    final data = response.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw ServerException(message: data['message'] as String? ?? 'Failed');
    }
    return UserModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  @override
  Future<UserModel> updateProfile({
    String? fullName,
    String? email,
    String? currentPassword,
    String? profileImageUrl,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['fullName'] = fullName;
    if (email != null) body['email'] = email;
    if (currentPassword != null) body['currentPassword'] = currentPassword;
    if (profileImageUrl != null) body['profileImageUrl'] = profileImageUrl;

    final response = await _client.patch(ApiConstants.me, data: body);
    final data = response.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw ServerException(message: data['message'] as String? ?? 'Failed');
    }
    return UserModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> updateLanguage({required String language}) async {
    final response = await _client.patch(
      ApiConstants.meLanguage,
      // AuthRequest.UpdateLanguage: preferredLanguage, enum EN / AR.
      data: {'preferredLanguage': language.toUpperCase()},
    );
    final data = response.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw ServerException(message: data['message'] as String? ?? 'Failed');
    }
  }

  /// AuthRequest.ResetPassword — the backend verifies the OTP here, so the
  /// code must not be spent on /auth/verify-otp first.
  @override
  Future<void> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) => _client.post(
    ApiConstants.resetPassword,
    data: {
      ..._destination(phone),
      'code': code,
      'newPassword': newPassword,
    },
  );

  /// Multipart `image`.
  @override
  Future<void> uploadAvatar(String path) async {
    await _client.postForm(
      ApiConstants.meAvatar,
      formData: FormData.fromMap({'image': await MultipartFile.fromFile(path)}),
    );
  }

  /// POST /provider/profile — ProviderProfileRequest.
  @override
  Future<void> createProviderProfile(Map<String, dynamic> profile) =>
      _client.post(ApiConstants.myProviderProfile, data: profile);

  /// POST /provider/staff — StaffMemberRequest.
  @override
  Future<void> addStaff(String fullName) =>
      _client.post(ApiConstants.providerStaff, data: {'fullName': fullName});

  /// Multipart nationalIdFront / nationalIdBack / selfie.
  @override
  Future<void> uploadVerificationDocuments({
    required String idFront,
    required String idBack,
    required String selfie,
  }) async {
    await _client.postForm(
      ApiConstants.providerVerification,
      formData: FormData.fromMap({
        'nationalIdFront': await MultipartFile.fromFile(idFront),
        'nationalIdBack': await MultipartFile.fromFile(idBack),
        'selfie': await MultipartFile.fromFile(selfie),
      }),
    );
  }

  /// GET /terms/latest?type= — TermsPolicyDto.
  @override
  Future<Map<String, dynamic>> latestTerms(String type) async {
    final response = await _client.get(
      ApiConstants.termsLatest,
      queryParameters: {'type': type},
    );
    return (response.data as Map<String, dynamic>)['data']
        as Map<String, dynamic>;
  }

  /// POST /terms/accept?version= — stores acceptedTermsVersion + timestamp.
  @override
  Future<void> acceptTerms(String version) => _client.post(
    ApiConstants.termsAccept,
    queryParameters: {'version': version},
  );

  /// PATCH /auth/me/preferences — UpdatePreferencesRequest.
  @override
  Future<void> updatePreferences({
    required double minKm,
    required double maxKm,
  }) => _client.patch(
    ApiConstants.mePreferences,
    data: {'searchRadiusMinKm': minKm, 'searchRadiusMaxKm': maxKm},
  );
}
