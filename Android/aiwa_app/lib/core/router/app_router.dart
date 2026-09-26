import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/role_choice_page.dart';
import '../../features/auth/presentation/pages/auth_choice_page.dart';
import '../../features/auth/presentation/pages/sign_in_page.dart';
import '../../features/auth/presentation/pages/phone_entry_page.dart';
import '../../features/auth/presentation/pages/otp_page.dart';
import '../../features/auth/presentation/pages/account_setup_page.dart';
import '../../features/auth/presentation/pages/avatar_gender_page.dart';
import '../../features/auth/presentation/pages/provider_business_page.dart';
import '../../features/auth/presentation/pages/provider_verification_page.dart';
import '../../features/auth/presentation/pages/provider_pending_page.dart';
import '../../features/auth/presentation/pages/auth_gate_page.dart';
import '../../features/shell/shell_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/home/presentation/pages/search_page.dart';
import '../../features/providers/presentation/pages/provider_detail_page.dart';
import '../../features/bookings/presentation/pages/booking_page.dart';
import '../../features/bookings/presentation/pages/booking_confirmed_page.dart';
import '../../features/bookings/presentation/pages/my_bookings_page.dart';
import '../../features/saved/presentation/pages/saved_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/reviews/presentation/pages/review_page.dart';
import '../../features/provider_dashboard/presentation/pages/dashboard_page.dart';
import '../../features/bookings/domain/entities/booking_entity.dart';

class AppRoutes {
  static const String splash = '/';
  static const String roleChoice = '/role-choice';
  static const String authChoice = '/auth-choice';
  static const String signIn = '/sign-in';
  static const String phoneEntry = '/phone-entry';
  static const String otp = '/otp';
  static const String accountSetup = '/account-setup';
  static const String avatarGender = '/avatar-gender';
  static const String providerBusiness = '/provider-business';
  static const String providerVerification = '/provider-verification';
  static const String providerPending = '/provider-pending';
  static const String shell = '/app';
  static const String home = '/app/home';
  static const String search = '/app/search';
  static const String bookings = '/app/bookings';
  static const String myBookings = '/app/bookings';
  static const String saved = '/app/saved';
  static const String profile = '/app/profile';
  static const String notifications = '/notifications';
  static const String providerDetail = '/provider/:id';
  static const String booking = '/booking/:providerId';
  static const String bookingConfirmed = '/booking-confirmed/:bookingId';
  static const String review = '/review/:bookingId';
  static const String providerDashboard = '/provider-dashboard';
  static const String authGate = '/auth-gate';
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'shell',
);

final router = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashPage()),
    GoRoute(
      path: AppRoutes.roleChoice,
      builder: (_, __) => const RoleChoicePage(),
    ),
    GoRoute(
      path: AppRoutes.authChoice,
      builder: (context, state) {
        final role = state.uri.queryParameters['role'] ?? 'CUSTOMER';
        return AuthChoicePage(role: role);
      },
    ),
    GoRoute(
      path: AppRoutes.signIn,
      builder: (context, state) {
        final role = state.uri.queryParameters['role'] ?? 'CUSTOMER';
        return SignInPage(role: role);
      },
    ),
    GoRoute(
      path: AppRoutes.phoneEntry,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final role = extra['role'] as String? ?? 'CUSTOMER';
        return PhoneEntryPage(role: role);
      },
    ),
    GoRoute(
      path: AppRoutes.otp,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return OtpPage(
          identifier: extra['identifier'] as String? ?? '',
          role: extra['role'] as String? ?? 'CUSTOMER',
          mode: extra['mode'] as String? ?? 'phone',
        );
      },
    ),
    GoRoute(
      path: AppRoutes.accountSetup,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return AccountSetupPage(
          role: extra['role'] as String? ?? 'CUSTOMER',
          identifier: extra['identifier'] as String? ?? '',
          identifierMode: extra['mode'] as String? ?? 'phone',
        );
      },
    ),
    GoRoute(
      path: AppRoutes.avatarGender,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return AvatarGenderPage(
          role: extra['role'] as String? ?? 'CUSTOMER',
          registrationData: extra,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.providerBusiness,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return ProviderBusinessPage(registrationData: extra);
      },
    ),
    GoRoute(
      path: AppRoutes.providerVerification,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return ProviderVerificationPage(registrationData: extra);
      },
    ),
    GoRoute(
      path: AppRoutes.providerPending,
      builder: (_, __) => const ProviderPendingPage(),
    ),
    ShellRoute(
      navigatorKey: shellNavigatorKey,
      builder: (context, state, child) => ShellPage(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.home,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: HomePage()),
        ),
        GoRoute(
          path: AppRoutes.search,
          pageBuilder: (context, state) {
            final category = state.uri.queryParameters['category'];
            return NoTransitionPage(
              child: SearchPage(initialCategory: category),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.bookings,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: MyBookingsPage()),
        ),
        GoRoute(
          path: AppRoutes.saved,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SavedPage()),
        ),
        GoRoute(
          path: AppRoutes.profile,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ProfilePage()),
        ),
      ],
    ),
    GoRoute(
      path: '/provider/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '0';
        return ProviderDetailPage(providerId: id);
      },
    ),
    GoRoute(
      path: '/booking/:providerId',
      builder: (context, state) {
        final providerId = state.pathParameters['providerId'] ?? '0';
        return BookingPage(
          providerId: providerId,
          initialServiceId: state.uri.queryParameters['serviceId'],
        );
      },
    ),
    GoRoute(
      path: '/booking-confirmed/:bookingId',
      // The confirmation needs the booking passed as `extra`; without it
      // (e.g. a restored deep link) fall back to the bookings list.
      redirect: (context, state) =>
          state.extra is BookingEntity ? null : AppRoutes.myBookings,
      builder: (context, state) =>
          BookingConfirmedPage(booking: state.extra as BookingEntity),
    ),
    GoRoute(path: AppRoutes.authGate, builder: (_, __) => const AuthGatePage()),
    GoRoute(
      path: AppRoutes.notifications,
      builder: (_, __) => const NotificationsPage(),
    ),
    GoRoute(
      path: '/review/:bookingId',
      builder: (context, state) {
        final bookingId = state.pathParameters['bookingId'] ?? '0';
        return ReviewPage(
          bookingId: bookingId,
          booking: state.extra is BookingEntity
              ? state.extra as BookingEntity
              : null,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.providerDashboard,
      builder: (_, __) => const DashboardPage(),
    ),
  ],
);
