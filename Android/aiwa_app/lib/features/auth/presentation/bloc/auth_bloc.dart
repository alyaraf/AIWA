import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../domain/usecases/get_current_user_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import '../../domain/usecases/send_otp_usecase.dart';
import '../../domain/usecases/update_profile_usecase.dart';
import '../../domain/usecases/verify_otp_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase loginUseCase;
  final RegisterUseCase registerUseCase;
  final SendOtpUseCase sendOtpUseCase;
  final VerifyOtpUseCase verifyOtpUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final UpdateProfileUseCase updateProfileUseCase;
  final SecureStorage secureStorage;

  AuthBloc({
    required this.loginUseCase,
    required this.registerUseCase,
    required this.sendOtpUseCase,
    required this.verifyOtpUseCase,
    required this.getCurrentUserUseCase,
    required this.updateProfileUseCase,
    required this.secureStorage,
  }) : super(AuthInitial()) {
    on<AuthCheckSessionEvent>(_onCheckSession);
    on<AuthLoginEvent>(_onLogin);
    on<AuthRegisterEvent>(_onRegister);
    on<AuthSendOtpEvent>(_onSendOtp);
    on<AuthVerifyOtpEvent>(_onVerifyOtp);
    on<AuthLogoutEvent>(_onLogout);
    on<AuthGetCurrentUserEvent>(_onGetCurrentUser);
    on<AuthUpdateProfileEvent>(_onUpdateProfile);
  }

  Future<void> _onCheckSession(
      AuthCheckSessionEvent event, Emitter<AuthState> emit) async {
    final hasSession = await secureStorage.hasValidSession();
    if (hasSession) {
      final result = await getCurrentUserUseCase();
      result.fold(
        (_) => emit(AuthUnauthenticated()),
        (user) => emit(AuthAuthenticated(user)),
      );
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLogin(AuthLoginEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final result = await loginUseCase(
      identifier: event.identifier,
      password: event.password,
    );
    await result.fold(
      (failure) async => emit(AuthError(failure.message)),
      (_) async {
        final userResult = await getCurrentUserUseCase();
        userResult.fold(
          (failure) => emit(AuthError(failure.message)),
          (user) => emit(AuthAuthenticated(user)),
        );
      },
    );
  }

  Future<void> _onRegister(
      AuthRegisterEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final result = await registerUseCase(
      fullName: event.fullName,
      password: event.password,
      email: event.email,
      phone: event.phone,
      role: event.role,
      gender: event.gender,
      profileImageUrl: event.profileImageUrl,
    );
    await result.fold(
      (failure) async => emit(AuthError(failure.message)),
      (_) async {
        final userResult = await getCurrentUserUseCase();
        userResult.fold(
          (failure) => emit(AuthError(failure.message)),
          (user) => emit(AuthAuthenticated(user)),
        );
      },
    );
  }

  Future<void> _onSendOtp(
      AuthSendOtpEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final result = await sendOtpUseCase(phone: event.phone);
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (_) => emit(AuthOtpSent(event.phone)),
    );
  }

  Future<void> _onVerifyOtp(
      AuthVerifyOtpEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final result =
        await verifyOtpUseCase(phone: event.phone, code: event.code);
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (_) => emit(AuthOtpVerified(event.phone)),
    );
  }

  Future<void> _onLogout(
      AuthLogoutEvent event, Emitter<AuthState> emit) async {
    await secureStorage.clearAll();
    emit(AuthUnauthenticated());
  }

  Future<void> _onGetCurrentUser(
      AuthGetCurrentUserEvent event, Emitter<AuthState> emit) async {
    final result = await getCurrentUserUseCase();
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (user) => emit(AuthAuthenticated(user)),
    );
  }

  Future<void> _onUpdateProfile(
      AuthUpdateProfileEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final result = await updateProfileUseCase(
      fullName: event.fullName,
      email: event.email,
      profileImageUrl: event.profileImageUrl,
    );
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (user) => emit(AuthProfileUpdated(user)),
    );
  }
}
