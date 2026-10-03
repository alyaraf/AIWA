import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/push/push_registrar.dart';
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

  /// Revokes the session server-side on sign-out; null in unit tests.
  final ApiClient? apiClient;

  /// Registers / clears this device's push token with the session (FE-3).
  final PushRegistrar? pushRegistrar;

  AuthBloc({
    required this.loginUseCase,
    required this.registerUseCase,
    required this.sendOtpUseCase,
    required this.verifyOtpUseCase,
    required this.getCurrentUserUseCase,
    required this.updateProfileUseCase,
    required this.secureStorage,
    this.apiClient,
    this.pushRegistrar,
  }) : super(AuthInitial()) {
    on<AuthCheckSessionEvent>(_safe(_onCheckSession, AuthUnauthenticated()));
    on<AuthLoginEvent>(_safe(_onLogin));
    on<AuthRegisterEvent>(_safe(_onRegister));
    on<AuthSendOtpEvent>(_safe(_onSendOtp));
    on<AuthVerifyOtpEvent>(_safe(_onVerifyOtp));
    on<AuthLogoutEvent>(_safe(_onLogout, AuthUnauthenticated()));
    on<AuthGetCurrentUserEvent>(_safe(_onGetCurrentUser));
    on<AuthUpdateProfileEvent>(_safe(_onUpdateProfile));
  }

  /// Tags crash reports with the signed-in user's id (no PII) — every path
  /// in or out (login, register, session restore, logout, expiry) lands
  /// here. No-op without SENTRY_DSN.
  @override
  void onChange(Change<AuthState> change) {
    super.onChange(change);
    final next = change.nextState;
    if (next is AuthAuthenticated) {
      Sentry.configureScope(
        (s) => s.setUser(SentryUser(id: '${next.user.id}')),
      );
      // Only on entering a session, not on every profile refresh.
      if (change.currentState is! AuthAuthenticated) {
        pushRegistrar?.register();
      }
    } else if (next is AuthUnauthenticated) {
      Sentry.configureScope((s) => s.setUser(null));
    }
  }

  /// How long ending a session waits for the server before it goes ahead
  /// on the phone anyway (CR-18).
  static const serverSignOutTimeout = Duration(seconds: 3);

  /// Best effort, bounded by [serverSignOutTimeout], never throws: removes
  /// this phone's push address, then revokes the tokens. Without tokens given
  /// it uses the stored ones (a 401 may then refresh them first).
  Future<void> _endOnServer({String? accessToken, String? refreshToken}) async {
    try {
      await () async {
        await pushRegistrar?.unregister(accessToken: accessToken);
        await apiClient?.logout(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
      }().timeout(serverSignOutTimeout);
    } catch (_) {}
  }

  /// An unexpected throw (bad payload, 2FA response without tokens…) must
  /// not leave the shared bloc stuck in [AuthLoading].
  EventHandler<E, AuthState> _safe<E extends AuthEvent>(
    EventHandler<E, AuthState> handler, [
    AuthState? fallback,
  ]) => (event, emit) async {
    try {
      await handler(event, emit);
    } catch (_) {
      emit(fallback ?? const AuthError('Something went wrong'));
    }
  };

  Future<void> _onCheckSession(
    AuthCheckSessionEvent event,
    Emitter<AuthState> emit,
  ) async {
    if (!await secureStorage.getRemember()) {
      // End it on the server too, or a shared phone keeps getting the last
      // user's notifications and their refresh token stays valid (CR-18).
      await _endOnServer();
      await secureStorage.clearAll();
      emit(AuthUnauthenticated());
      return;
    }
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
    await result.fold((failure) async => emit(AuthError(failure.message)), (
      _,
    ) async {
      await secureStorage.setRemember(event.remember);
      final userResult = await getCurrentUserUseCase();
      userResult.fold(
        (failure) => emit(AuthError(failure.message)),
        (user) => emit(AuthAuthenticated(user)),
      );
    });
  }

  Future<void> _onRegister(
    AuthRegisterEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await registerUseCase(
      fullName: event.fullName,
      password: event.password,
      email: event.email,
      phone: event.phone,
      role: event.role,
      gender: event.gender,
      profileImageUrl: event.profileImageUrl,
      preferredLanguage: event.preferredLanguage,
    );
    await result.fold((failure) async => emit(AuthError(failure.message)), (
      _,
    ) async {
      final userResult = await getCurrentUserUseCase();
      userResult.fold(
        (failure) => emit(AuthError(failure.message)),
        (user) => emit(AuthAuthenticated(user)),
      );
    });
  }

  Future<void> _onSendOtp(
    AuthSendOtpEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await sendOtpUseCase(phone: event.phone);
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (_) => emit(AuthOtpSent(event.phone)),
    );
  }

  Future<void> _onVerifyOtp(
    AuthVerifyOtpEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await verifyOtpUseCase(phone: event.phone, code: event.code);
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (_) => emit(AuthOtpVerified(event.phone)),
    );
  }

  Future<void> _onLogout(AuthLogoutEvent event, Emitter<AuthState> emit) async {
    // Signed out on the phone first, even on a stalled connection; the
    // server then gets the tokens read just before (CR-18).
    final accessToken = await secureStorage.getAccessToken();
    final refreshToken = await secureStorage.getRefreshToken();
    await secureStorage.clearAll();
    emit(AuthUnauthenticated());
    await _endOnServer(accessToken: accessToken, refreshToken: refreshToken);
  }

  Future<void> _onGetCurrentUser(
    AuthGetCurrentUserEvent event,
    Emitter<AuthState> emit,
  ) async {
    final result = await getCurrentUserUseCase();
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (user) => emit(AuthAuthenticated(user)),
    );
  }

  Future<void> _onUpdateProfile(
    AuthUpdateProfileEvent event,
    Emitter<AuthState> emit,
  ) async {
    // No AuthLoading/AuthProfileUpdated: the Profile tab treats any
    // non-authenticated state as a guest and would flash the lock screen.
    final result = await updateProfileUseCase(
      fullName: event.fullName,
      email: event.email,
      profileImageUrl: event.profileImageUrl,
    );
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (user) => emit(AuthAuthenticated(user)),
    );
  }
}
