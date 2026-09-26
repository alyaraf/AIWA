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
  });

  Future<void> sendOtp({required String phone});
  Future<void> verifyOtp({required String phone, required String code});
  Future<UserModel> getCurrentUser();
  Future<UserModel> updateProfile({
    String? fullName,
    String? email,
    String? profileImageUrl,
  });
  Future<void> updateLanguage({required String language});
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient _client;
  AuthRemoteDataSourceImpl(this._client);

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
      throw ServerException(message: data['message'] as String? ?? 'Login failed');
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

    final response = await _client.post(ApiConstants.register, data: body);
    final data = response.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw ServerException(
          message: data['message'] as String? ?? 'Registration failed');
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
      data: {'phone': phone},
    );
    final data = response.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw ServerException(
          message: data['message'] as String? ?? 'Failed to send OTP');
    }
  }

  @override
  Future<void> verifyOtp({required String phone, required String code}) async {
    final response = await _client.post(
      ApiConstants.verifyOtp,
      data: {'phone': phone, 'code': code},
    );
    final data = response.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw ServerException(
          message: data['message'] as String? ?? 'Invalid OTP');
    }
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
    String? profileImageUrl,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['fullName'] = fullName;
    if (email != null) body['email'] = email;
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
      data: {'language': language},
    );
    final data = response.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw ServerException(message: data['message'] as String? ?? 'Failed');
    }
  }
}
