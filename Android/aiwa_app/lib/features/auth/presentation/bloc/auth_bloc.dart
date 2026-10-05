import '../../domain/repositories/auth_repository.dart';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/push/push_registrar.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/models/user_model.dart';
import '../../domain/entities/user_entity.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  final SecureStorage secureStorage;

  /// Revokes the session server-side on sign-out; null in unit tests.
  final ApiClient? apiClient;

  /// Registers / clears this device's push token with the session (FE-3).
  final PushRegistrar? pushRegistrar;

  AuthBloc({
    required this.authRepository,
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

  /// Best effort, never throws: removes this phone's push address, then
  /// revokes the tokens, each step bounded by [serverSignOutTimeout] on its
  /// own so a slow unregister cannot drop the revoke. [refreshToken] /
  /// [accessToken] are the ones read before anything could clear them and are
  /// what gets revoked. [preferStored] (cold start only, storage still holds
  /// the same session) revokes what is stored after unregister instead, as a
  /// 401 there may have rotated them; sign-out must not, as by then storage
  /// may hold the next user's tokens.
  Future<void> _endOnServer({
    String? accessToken,
    String? refreshToken,
    bool preferStored = false,
  }) async {
    try {
      await pushRegistrar
          ?.unregister(accessToken: accessToken)
          .timeout(serverSignOutTimeout);
    } catch (_) {}
    try {
      if (preferStored) {
        accessToken = await secureStorage.getAccessToken() ?? accessToken;
        refreshToken = await secureStorage.getRefreshToken() ?? refreshToken;
      }
      await apiClient
          ?.logout(accessToken: accessToken, refreshToken: refreshToken)
          .timeout(serverSignOutTimeout);
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

  /// M-01: true when the session this handler started under has ended (sign-out, expiry, another account signed in).
  /// Nothing may be cached or emitted for it: the answer is the previous account's, and emitting it would show that
  /// account's identity (or sign the new one out).
  bool _ended(int session) => SecureStorage.generation != session;

  Future<void> _onCheckSession(
    AuthCheckSessionEvent event,
    Emitter<AuthState> emit,
  ) async {
    final session = SecureStorage.generation;
    if (!await secureStorage.getRemember()) {
      // End it on the server too, or a shared phone keeps getting the last
      // user's notifications and their refresh token stays valid (CR-18).
      // The refresh token is read now, before anything can clear it; the
      // access token is left to unregister, which may refresh it on a 401.
      final refreshToken = await secureStorage.getRefreshToken();
      await _endOnServer(refreshToken: refreshToken, preferStored: true);
      await secureStorage.clearAll();
      emit(AuthUnauthenticated());
      return;
    }
    final hasSession = await secureStorage.hasValidSession();
    if (hasSession) {
      final result = await authRepository.getCurrentUser();
      if (_ended(session)) return;
      final failure = result.fold((f) => f, (_) => null);
      if (failure == null) {
        result.fold((_) {}, (user) => emit(AuthAuthenticated(user)));
        return;
      }
      if (failure is SessionChangedFailure) return;
      // L-14: no network at cold start (or a server error) is not a signed-out session. The tokens are kept either
      // way; show the last known account until the API answers. Only a rejected session signs out (M-04).
      if (failure is! UnauthorizedFailure) {
        final cached = await _cachedUser();
        if (_ended(session)) return;
        if (cached != null) {
          emit(AuthAuthenticated(cached, refreshError: failure.message));
          return;
        }
      }
      emit(AuthUnauthenticated());
    } else {
      emit(AuthUnauthenticated());
    }
  }

  /// The account cached by the last successful profile fetch, or null.
  Future<UserEntity?> _cachedUser() async {
    try {
      final raw = await secureStorage.getCachedUser();
      if (raw == null || raw.isEmpty) return null;
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _onLogin(AuthLoginEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final result = await authRepository.login(
      identifier: event.identifier,
      password: event.password,
    );
    await result.fold((failure) async => emit(AuthError(failure.message)), (
      _,
    ) async {
      await secureStorage.setRemember(event.remember);
      final session = SecureStorage.generation; // the session this sign-in just started
      final userResult = await authRepository.getCurrentUser();
      if (_ended(session)) return;
      userResult.fold(
        (failure) => failure is SessionChangedFailure
            ? null
            : emit(AuthError(failure.message)),
        (user) => emit(AuthAuthenticated(user)),
      );
    });
  }

  Future<void> _onRegister(
    AuthRegisterEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await authRepository.register(
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
      final session = SecureStorage.generation;
      final userResult = await authRepository.getCurrentUser();
      if (_ended(session)) return;
      userResult.fold(
        (failure) => failure is SessionChangedFailure
            ? null
            : emit(AuthError(failure.message)),
        (user) => emit(AuthAuthenticated(user)),
      );
    });
  }

  Future<void> _onSendOtp(
    AuthSendOtpEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await authRepository.sendOtp(phone: event.phone);
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
    final result = await authRepository.verifyOtp(phone: event.phone, code: event.code);
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
    final session = SecureStorage.generation;
    final result = await authRepository.getCurrentUser();
    if (_ended(session)) return;
    result.fold(_onProfileFailure(emit), (user) => emit(AuthAuthenticated(user)));
  }

  /// A failed profile refresh / save (M-04): the identity stays while the session is still valid, with the reason
  /// beside it; only a rejected session signs out. Outside a signed-in session (sign-up in progress) it is the
  /// plain error it always was.
  void Function(Failure) _onProfileFailure(Emitter<AuthState> emit) =>
      (failure) {
        if (failure is SessionChangedFailure) return;
        final current = state;
        if (failure is UnauthorizedFailure) {
          emit(AuthUnauthenticated());
        } else if (current is AuthAuthenticated) {
          emit(AuthAuthenticated(current.user, refreshError: failure.message));
        } else {
          emit(AuthError(failure.message));
        }
      };

  Future<void> _onUpdateProfile(
    AuthUpdateProfileEvent event,
    Emitter<AuthState> emit,
  ) async {
    // No AuthLoading/AuthProfileUpdated: the Profile tab treats any
    // non-authenticated state as a guest and would flash the lock screen.
    final session = SecureStorage.generation;
    final result = await authRepository.updateProfile(
      fullName: event.fullName,
      email: event.email,
      currentPassword: event.currentPassword,
      profileImageUrl: event.profileImageUrl,
    );
    if (_ended(session)) return;
    result.fold(_onProfileFailure(emit), (user) => emit(AuthAuthenticated(user)));
  }
}
