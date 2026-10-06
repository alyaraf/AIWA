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

/// Handler signature used by [AuthBloc._safe]: the third argument is the number of the credential attempt the event
/// runs under (see [SecureStorage.beginAuthAttempt]).
typedef _AuthHandler<E extends AuthEvent> =
    Future<void> Function(E event, Emitter<AuthState> emit, int attempt);

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
    on<AuthCheckSessionEvent>(
      _safe(_onCheckSession, fallback: AuthUnauthenticated()),
    );
    on<AuthLoginEvent>(_safe(_onLogin, beginsAttempt: true));
    on<AuthRegisterEvent>(_safe(_onRegister, beginsAttempt: true));
    on<AuthSendOtpEvent>(_safe(_onSendOtp));
    on<AuthVerifyOtpEvent>(_safe(_onVerifyOtp));
    on<AuthLogoutEvent>(
      _safe(_onLogout, fallback: AuthUnauthenticated(), beginsAttempt: true),
    );
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
  /// may hold the next user's tokens. R4-05: even then the stored tokens are
  /// only used while [storedSessionIsStillTheSame] says so.
  Future<void> _endOnServer({
    String? accessToken,
    String? refreshToken,
    bool preferStored = false,
    bool Function()? storedSessionIsStillTheSame,
  }) async {
    try {
      await pushRegistrar
          ?.unregister(accessToken: accessToken)
          .timeout(serverSignOutTimeout);
    } catch (_) {}
    try {
      if (preferStored) {
        final storedAccess = await secureStorage.getAccessToken();
        final storedRefresh = await secureStorage.getRefreshToken();
        if (storedSessionIsStillTheSame?.call() ?? true) {
          accessToken = storedAccess ?? accessToken;
          refreshToken = storedRefresh ?? refreshToken;
        }
      }
      await apiClient
          ?.logout(accessToken: accessToken, refreshToken: refreshToken)
          .timeout(serverSignOutTimeout);
    } catch (_) {}
  }

  /// An unexpected throw (bad payload, 2FA response without tokens…) must
  /// not leave the shared bloc stuck in [AuthLoading].
  ///
  /// R4-05: [beginsAttempt] marks the credential-changing events (sign-in, registration, sign-out). Each handler
  /// gets the number of its own attempt (the current one, for the other events). Once a newer attempt has started the
  /// handler is obsolete, and so is this generic catch: an old operation's failure must not replace the state the
  /// newer one published.
  EventHandler<E, AuthState> _safe<E extends AuthEvent>(
    _AuthHandler<E> handler, {
    AuthState? fallback,
    bool beginsAttempt = false,
  }) => (event, emit) async {
    final attempt = beginsAttempt
        ? SecureStorage.beginAuthAttempt()
        : SecureStorage.authAttempt;
    try {
      await handler(event, emit, attempt);
    } catch (_) {
      if (!SecureStorage.isCurrentAttempt(attempt)) return;
      emit(fallback ?? const AuthError('Something went wrong'));
    }
  };

  /// M-01: true when the session this handler started under has ended (sign-out, expiry, another account signed in).
  /// Nothing may be cached or emitted for it: the answer is the previous account's, and emitting it would show that
  /// account's identity (or sign the new one out).
  bool _ended(int session) => SecureStorage.generation != session;

  /// R4-05: true when the work must be dropped: its session ended, or a newer sign-in / registration / sign-out
  /// started after it ([attempt] is no longer the current one). Checked after every await that precedes an emit or a
  /// storage change.
  bool _obsolete(int session, int attempt) =>
      _ended(session) || !SecureStorage.isCurrentAttempt(attempt);

  Future<void> _onCheckSession(
    AuthCheckSessionEvent event,
    Emitter<AuthState> emit,
    int attempt,
  ) async {
    final session = SecureStorage.generation;
    final remember = await secureStorage.getRemember();
    // R4-05: a sign-in that completed (or began) while storage was being read owns the credentials now.
    if (_obsolete(session, attempt)) return;
    if (!remember) {
      // End it on the server too, or a shared phone keeps getting the last
      // user's notifications and their refresh token stays valid (CR-18).
      // The refresh token is read now, before anything can clear it; the
      // access token is left to unregister, which may refresh it on a 401.
      final refreshToken = await secureStorage.getRefreshToken();
      if (_obsolete(session, attempt)) return; // the token read may already be the next sign-in's
      await _endOnServer(
        refreshToken: refreshToken,
        preferStored: true,
        storedSessionIsStillTheSame: () => !_obsolete(session, attempt),
      );
      // The cold-start session is only wiped while it is still the one in storage: never a newer sign-in's tokens.
      if (_obsolete(session, attempt)) return;
      await secureStorage.clearAll();
      emit(AuthUnauthenticated());
      return;
    }
    final hasSession = await secureStorage.hasValidSession();
    if (_obsolete(session, attempt)) return;
    if (hasSession) {
      final result = await authRepository.getCurrentUser();
      if (_obsolete(session, attempt)) return;
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
        if (_obsolete(session, attempt)) return;
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

  Future<void> _onLogin(
    AuthLoginEvent event,
    Emitter<AuthState> emit,
    int attempt,
  ) async {
    emit(AuthLoading());
    final result = await authRepository.login(
      identifier: event.identifier,
      password: event.password,
    );
    // R4-05: an overtaken sign-in publishes nothing and touches no credentials, whatever it ended with. A
    // SessionChangedFailure keeps its meaning (an answer for a session that is gone), it is not an error to show.
    if (!SecureStorage.isCurrentAttempt(attempt)) return;
    final failure = result.fold((f) => f, (_) => null);
    if (failure != null) {
      if (failure is! SessionChangedFailure) emit(AuthError(failure.message));
      return;
    }
    // The generation of the session this sign-in just started, taken before anything is awaited.
    final session = SecureStorage.generation;
    await secureStorage.setRemember(event.remember);
    if (_obsolete(session, attempt)) return;
    final userResult = await authRepository.getCurrentUser();
    if (_obsolete(session, attempt)) return;
    userResult.fold(
      (failure) => failure is SessionChangedFailure
          ? null
          : emit(AuthError(failure.message)),
      (user) => emit(AuthAuthenticated(user)),
    );
  }

  Future<void> _onRegister(
    AuthRegisterEvent event,
    Emitter<AuthState> emit,
    int attempt,
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
    if (!SecureStorage.isCurrentAttempt(attempt)) return;
    final failure = result.fold((f) => f, (_) => null);
    if (failure != null) {
      if (failure is! SessionChangedFailure) emit(AuthError(failure.message));
      return;
    }
    final session = SecureStorage.generation;
    final userResult = await authRepository.getCurrentUser();
    if (_obsolete(session, attempt)) return;
    userResult.fold(
      (failure) => failure is SessionChangedFailure
          ? null
          : emit(AuthError(failure.message)),
      (user) => emit(AuthAuthenticated(user)),
    );
  }

  Future<void> _onSendOtp(
    AuthSendOtpEvent event,
    Emitter<AuthState> emit,
    int attempt,
  ) async {
    emit(AuthLoading());
    final result = await authRepository.sendOtp(phone: event.phone);
    // R4-05: the answer of an OTP request that a sign-in / sign-out overtook must not replace the new state.
    if (!SecureStorage.isCurrentAttempt(attempt)) return;
    result.fold(
      (failure) =>
          failure is SessionChangedFailure ? null : emit(AuthError(failure.message)),
      (_) => emit(AuthOtpSent(event.phone)),
    );
  }

  Future<void> _onVerifyOtp(
    AuthVerifyOtpEvent event,
    Emitter<AuthState> emit,
    int attempt,
  ) async {
    emit(AuthLoading());
    final result = await authRepository.verifyOtp(phone: event.phone, code: event.code);
    if (!SecureStorage.isCurrentAttempt(attempt)) return;
    result.fold(
      (failure) =>
          failure is SessionChangedFailure ? null : emit(AuthError(failure.message)),
      (_) => emit(AuthOtpVerified(event.phone)),
    );
  }

  Future<void> _onLogout(
    AuthLogoutEvent event,
    Emitter<AuthState> emit,
    int attempt,
  ) async {
    // Signed out on the phone first, even on a stalled connection; the
    // server then gets the tokens read just before (CR-18).
    final session = SecureStorage.generation;
    final accessToken = await secureStorage.getAccessToken();
    final refreshToken = await secureStorage.getRefreshToken();
    if (!SecureStorage.isCurrentAttempt(attempt)) {
      // R4-05: a newer sign-in / sign-out started while this was reading. It owns the credentials: do not wipe them
      // or publish a state. The session this sign-out was asked to end is still ended on the server, provided the
      // tokens read are really its own (no sign-in stored its tokens in between).
      if (!_ended(session)) {
        await _endOnServer(accessToken: accessToken, refreshToken: refreshToken);
      }
      return;
    }
    await secureStorage.clearAll();
    emit(AuthUnauthenticated());
    await _endOnServer(accessToken: accessToken, refreshToken: refreshToken);
  }

  Future<void> _onGetCurrentUser(
    AuthGetCurrentUserEvent event,
    Emitter<AuthState> emit,
    int attempt,
  ) async {
    final session = SecureStorage.generation;
    final result = await authRepository.getCurrentUser();
    if (_obsolete(session, attempt)) return;
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
    int attempt,
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
    if (_obsolete(session, attempt)) return;
    result.fold(_onProfileFailure(emit), (user) => emit(AuthAuthenticated(user)));
  }
}
