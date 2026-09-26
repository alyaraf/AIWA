import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/di/injection_container.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/notifications/presentation/bloc/notification_bloc.dart';

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
        // A signed-in user's gender picks the palette (male = default).
        listenWhen: (_, s) => s is AuthAuthenticated,
        listener: (_, s) {
          if (s is AuthAuthenticated && s.user.gender != null) {
            ThemeController.applyGender(s.user.gender);
          }
        },
        child: const _ThemedApp(),
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
  @override
  void initState() {
    super.initState();
    ThemeController.mode.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeController.mode.removeListener(_onThemeChanged);
    super.dispose();
  }

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
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('ar')],
    );
  }
}
