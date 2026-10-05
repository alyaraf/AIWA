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

  /// Why the last profile refresh failed (offline, server error), or null. The identity stays: a transient failure
  /// must not turn a signed-in user into a guest (audit M-04). Cleared by the next successful refresh.
  final String? refreshError;
  const AuthAuthenticated(this.user, {this.refreshError});
  @override
  List<Object?> get props => [user, refreshError];
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
