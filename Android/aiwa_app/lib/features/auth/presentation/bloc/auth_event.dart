import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthCheckSessionEvent extends AuthEvent {}

class AuthLoginEvent extends AuthEvent {
  final String identifier;
  final String password;
  final bool remember;
  const AuthLoginEvent({
    required this.identifier,
    required this.password,
    this.remember = true,
  });
  @override
  List<Object?> get props => [identifier, password, remember];
}

class AuthRegisterEvent extends AuthEvent {
  final String fullName;
  final String password;
  final String? email;
  final String? phone;
  final String role;
  final String? gender;
  final String? profileImageUrl;

  /// 'EN' or 'AR'.
  final String? preferredLanguage;

  const AuthRegisterEvent({
    required this.fullName,
    required this.password,
    this.email,
    this.phone,
    required this.role,
    this.gender,
    this.profileImageUrl,
    this.preferredLanguage,
  });

  @override
  List<Object?> get props => [
    fullName,
    password,
    email,
    phone,
    role,
    gender,
    preferredLanguage,
  ];
}

class AuthSendOtpEvent extends AuthEvent {
  final String phone;
  const AuthSendOtpEvent({required this.phone});
  @override
  List<Object?> get props => [phone];
}

class AuthVerifyOtpEvent extends AuthEvent {
  final String phone;
  final String code;
  const AuthVerifyOtpEvent({required this.phone, required this.code});
  @override
  List<Object?> get props => [phone, code];
}

class AuthLogoutEvent extends AuthEvent {}

class AuthGetCurrentUserEvent extends AuthEvent {}

class AuthUpdateProfileEvent extends AuthEvent {
  final String? fullName;
  final String? email;
  final String? profileImageUrl;

  const AuthUpdateProfileEvent({
    this.fullName,
    this.email,
    this.profileImageUrl,
  });
}
