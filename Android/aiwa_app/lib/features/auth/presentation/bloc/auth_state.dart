import 'package:equatable/equatable.dart';
import '../../domain/entities/user_entity.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final UserEntity user;
  const AuthAuthenticated(this.user);
  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {}

class AuthOtpSent extends AuthState {
  final String phone;
  const AuthOtpSent(this.phone);
  @override
  List<Object?> get props => [phone];
}

class AuthOtpVerified extends AuthState {
  final String phone;
  const AuthOtpVerified(this.phone);
  @override
  List<Object?> get props => [phone];
}

class AuthRegistered extends AuthState {
  final UserEntity user;
  const AuthRegistered(this.user);
  @override
  List<Object?> get props => [user];
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

class AuthProfileUpdated extends AuthState {
  final UserEntity user;
  const AuthProfileUpdated(this.user);
  @override
  List<Object?> get props => [user];
}
