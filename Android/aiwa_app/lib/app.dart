import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/di/injection_container.dart';
import 'l10n/app_localizations.dart';
import 'core/network/api_client.dart';
import 'core/push/push_registrar.dart';
import 'core/push/push_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/notifications/notification_routes.dart';
import 'features/notifications/presentation/bloc/notification_bloc.dart';
import 'features/notifications/presentation/bloc/notification_event.dart';
import 'shared/widgets/offline_banner.dart';

class AiwaApp extends StatelessWidget {
  const AiwaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => sl<AuthBloc>()..add(AuthCheckSessionEvent()),
        ),
        BlocProvider<NotificationBloc>(create: (_) => sl<NotificationBloc>()),
      ],
      child: BlocListener<AuthBloc, AuthState>(
        // M-01: the inbox is account-scoped state held by an app-wide bloc; it must not outlive the account.
        listenWhen: (prev, cur) =>
            cur is AuthUnauthenticated ||
            (prev is AuthAuthenticated &&
                cur is AuthAuthenticated &&
                prev.user.id != cur.user.id),
        listener: (context, _) =>
            context.read<NotificationBloc>().add(NotificationResetEvent()),
        child: BlocListener<AuthBloc, AuthState>(
          // A signed-in user's gender picks the palette (male = default).
          listenWhen: (_, s) => s is AuthAuthenticated,
          listener: (_, s) {
            if (s is AuthAuthenticated && s.user.gender != null) {
              ThemeController.applyGender(s.user.gender);
            }
            // A newer policy went live since this user last accepted
            // (GET /auth/me termsUpToDate): ask once, from anywhere. Users who
            // never accepted are still in sign-up, which accepts on its own.
            if (s is AuthAuthenticated &&
                s.user.termsUpToDate == false &&
                s.user.acceptedTermsVersion != null) {
              final path = router.routerDelegate.currentConfiguration.uri.path;
              if (path != AppRoutes.termsReaccept) {
                router.push(AppRoutes.termsReaccept);
              }
            }
            // A push that cold-started the app is routed once someone is signed in.
            final launch = PushService.pendingLaunchTap;
            if (s is AuthAuthenticated && launch != null) {
              PushService.pendingLaunchTap = null;
              openPushTarget(launch, isProvider: s.user.isProvider);
            }
          },
          child: const _ThemedApp(),
        ),
      ),
    );
  }
}

/// Rebuilds the whole tree when the palette changes.
///
/// Colours are read from [AppColors] getters at build time, so on a palette
/// swap every element (including `const` ones) is marked dirty — navigation
/// and page state are kept.
class _ThemedApp extends StatefulWidget {
  const _ThemedApp();

  @override
  State<_ThemedApp> createState() => _ThemedAppState();
}

class _ThemedAppState extends State<_ThemedApp> {
  late final StreamSubscription<int> _authEvents;
  late final StreamSubscription<Map<String, String>> _pushTaps;
  late final StreamSubscription<String> _tokenRefresh;

  @override
  void initState() {
    super.initState();
    ThemeController.mode.addListener(_onThemeChanged);
    LocaleController.locale.addListener(_onLocaleChanged);
    _authEvents = ApiClient.authEvents.stream.listen(_onAuthEvent);
    // FE-3: a tapped push opens its screen; a rotated FCM token is re-sent.
    _pushTaps = PushService.taps.stream.listen((data) {
      if (!mounted) return;
      final auth = context.read<AuthBloc>().state;
      if (auth is AuthAuthenticated) {
        openPushTarget(data, isProvider: auth.user.isProvider);
      }
    });
    _tokenRefresh = PushService.tokenRefresh.listen((_) {
      if (!mounted) return;
      if (context.read<AuthBloc>().state is AuthAuthenticated) {
        sl<PushRegistrar>().register();
      }
    });
  }

  @override
  void dispose() {
    ThemeController.mode.removeListener(_onThemeChanged);
    LocaleController.locale.removeListener(_onLocaleChanged);
    _authEvents.cancel();
    _pushTaps.cancel();
    _tokenRefresh.cancel();
    super.dispose();
  }

  /// Global HTTP-status routing (ACCT-C07): 401 after a rejected refresh,
  /// 423 locked account, 403 another role's area.
  void _onAuthEvent(int status) {
    final path = router.routerDelegate.currentConfiguration.uri.path;
    switch (status) {
      case 401 when path != AppRoutes.sessionExpired:
        context.read<AuthBloc>().add(AuthLogoutEvent());
        router.go(AppRoutes.sessionExpired);
      case 423 when path != AppRoutes.accountLocked:
        context.read<AuthBloc>().add(AuthLogoutEvent());
        router.go(AppRoutes.accountLocked);
      case 403 when path != AppRoutes.forbidden:
        router.push(AppRoutes.forbidden);
    }
  }

  void _onLocaleChanged() => setState(() {});

  void _onThemeChanged() {
    if (!mounted) return;
    setState(() {});
    void rebuild(Element el) {
      el.markNeedsBuild();
      el.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'AIWA',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      locale: LocaleController.locale.value,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (_, child) => Stack(children: [child!, const OfflineBanner()]),
    );
  }
}

/// Opens the screen for a tapped push ({type, relatedBookingId, ...}).
void openPushTarget(Map<String, String> data, {required bool isProvider}) {
  final to = notificationTarget(
    type: data['type'] ?? '',
    bookingId: data['relatedBookingId'],
    isProvider: isProvider,
  );
  if (to != null) router.push(to);
}
