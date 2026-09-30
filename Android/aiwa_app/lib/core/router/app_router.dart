import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
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
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/terms_page.dart';
import '../../features/auth/presentation/pages/terms_reaccept_page.dart';
import '../../features/auth/presentation/pages/preferences_page.dart';
import '../../features/onboarding/presentation/pages/permission_priming_page.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/shell/shell_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/home/presentation/pages/search_page.dart';
import '../../features/providers/domain/entities/provider_detail_entity.dart';
import '../../features/providers/presentation/pages/provider_detail_page.dart';
import '../../features/providers/presentation/pages/staff_picker_page.dart';
import '../../features/bookings/presentation/pages/booking_page.dart';
import '../../features/bookings/presentation/pages/booking_type_page.dart';
import '../../features/bookings/presentation/pages/booking_confirmed_page.dart';
import '../../features/bookings/presentation/pages/my_bookings_page.dart';
import '../../features/bookings/presentation/pages/tracking_page.dart';
import '../../features/bookings/presentation/pages/chat_page.dart';
import '../../features/bookings/presentation/pages/booking_action_pages.dart';
import '../../features/bookings/presentation/pages/booking_outcome_pages.dart';
import '../../features/saved/presentation/pages/saved_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/edit_profile_page.dart';
import '../../features/profile/presentation/pages/addresses_page.dart';
import '../../features/profile/presentation/pages/safety_policies_page.dart';
import '../../features/profile/presentation/pages/trusted_contacts_page.dart';
import '../../features/profile/presentation/pages/support_page.dart';
import '../../features/profile/presentation/pages/my_reports_page.dart';
import '../../features/bookings/domain/entities/saved_address_entity.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/notifications/presentation/pages/notification_preferences_page.dart';
import '../../features/reviews/presentation/pages/review_page.dart';
import '../../features/provider_dashboard/presentation/pages/dashboard_page.dart';
import '../../features/provider_dashboard/presentation/pages/provider_booking_detail_page.dart';
import '../../features/provider_dashboard/presentation/pages/provider_bookings_page.dart';
import '../../features/provider_dashboard/presentation/pages/provider_closeout_pages.dart';
import '../../features/provider_dashboard/presentation/pages/provider_shell_page.dart';
import '../../features/provider_dashboard/presentation/pages/business_info_page.dart';
import '../../features/provider_dashboard/presentation/pages/gallery_manager_page.dart';
import '../../features/provider_dashboard/presentation/pages/provider_profile_page.dart';
import '../../features/provider_dashboard/presentation/pages/provider_reviews_page.dart';
import '../../features/provider_dashboard/presentation/pages/provider_schedule_page.dart';
import '../../features/provider_dashboard/presentation/pages/provider_services_page.dart';
import '../../features/provider_dashboard/presentation/pages/provider_staff_page.dart';
import '../../features/provider_dashboard/presentation/pages/provider_wallet_page.dart';
import '../../features/bookings/domain/entities/booking_entity.dart';
import '../../shared/widgets/system_screen.dart';
import '../di/injection_container.dart';
import '../storage/secure_storage.dart';
import '../theme/app_theme.dart';

class AppRoutes {
  static const String splash = '/';
  static const String roleChoice = '/role-choice';
  static const String authChoice = '/auth-choice';
  static const String signIn = '/sign-in';
  static const String forgotPassword = '/forgot-password';
  static const String terms = '/terms';
  static const String termsReaccept = '/terms-reaccept';
  static const String preferences = '/preferences';
  static const String permLocation = '/perm-location';
  static const String permNotifications = '/perm-notifications';

  /// Pushed priming, pops a bool: `/permission?kind=camera`.
  static const String permission = '/permission';
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
  // Provider app. '/pro' because '/provider/:id' is the customer-facing
  // provider profile.
  static const String providerDashboard = '/pro/today';
  static const String providerBookings = '/pro/bookings';
  static const String providerServices = '/pro/services';
  static const String providerSchedule = '/pro/schedule';
  static const String providerProfile = '/pro/profile';
  static const String providerBusinessInfo = '/pro/business-info';
  static const String providerGallery = '/pro/gallery';
  static const String providerStaff = '/pro/staff';
  static const String providerWallet = '/pro/wallet';
  static const String providerReviews = '/pro/reviews';
  static String providerBooking(String id) => '/pro/bookings/$id';
  static String providerBookingPayment(String id) =>
      '/pro/bookings/$id/payment';
  static String providerRateCustomer(String id) => '/pro/bookings/$id/rate';
  static const String authGate = '/auth-gate';
  static const String sessionExpired = '/session-expired';
  static const String accountLocked = '/account-locked';
  static const String forbidden = '/forbidden';
  static const String support = '/support';
  static const String myReports = '/support/reports';

  // Profile tab destinations (phase 6).
  static const String editProfile = '/profile/edit';
  static const String addresses = '/addresses';
  static const String addressNew = '/addresses/new';
  static const String trustedContacts = '/trusted-contacts';
  static const String notificationPreferences = '/notification-preferences';
  static const String safetyPolicies = '/profile/policies';

  /// `/permission-denied?kind=location|camera|notifications`, pops a bool.
  static const String permissionDenied = '/permission-denied';

  /// Booking-type step: Book now vs Schedule.
  static String bookingTypeFor(
    String providerId, {
    String? serviceId,
    String? staffId,
  }) => Uri(
    path: '/booking-type/$providerId',
    queryParameters: {'serviceId': ?serviceId, 'staffId': ?staffId},
  ).toString();

  /// Where a guest was headed when the auth gate sent them to sign up.
  /// Sign-in resumes via the gate itself (it awaits the pushed page); the
  /// sign-up flow resets the stack, so it reads this at its last step.
  // ponytail: one global slot; lingers if the guest abandons sign-up and
  // later signs up from elsewhere.
  static String? resumeAfterSignUp;

  /// Where a signed-in user lands: providers wait on the pending gate until
  /// their verification is approved.
  static String landingFor(UserEntity u) => !u.isProvider
      ? home
      : (u.providerProfile?.isApproved ?? false)
      ? providerDashboard
      : providerPending;
}

/// Tab switch: fade + scale .98 -> 1 over 320ms soft (aiwa-fade-in).
CustomTransitionPage<void> _tab(GoRouterState state, Widget child) =>
    CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: AppTheme.dur3,
      reverseTransitionDuration: Duration.zero,
      transitionsBuilder: (_, animation, _, child) {
        final a = CurvedAnimation(parent: animation, curve: AppTheme.easeSoft);
        return FadeTransition(
          opacity: a,
          child: ScaleTransition(
            scale: Tween(begin: .98, end: 1.0).animate(a),
            child: child,
          ),
        );
      },
    );

/// Pushed screen: aiwa-slide-in, translateX(8%) -> 0 over 320ms soft.
CustomTransitionPage<void> _slide(GoRouterState state, Widget child) =>
    CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: AppTheme.dur3,
      transitionsBuilder: (_, animation, _, child) {
        final a = CurvedAnimation(parent: animation, curve: AppTheme.easeSoft);
        return FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(.08, 0),
              end: Offset.zero,
            ).animate(a),
            child: child,
          ),
        );
      },
    );

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'shell',
);

/// Provider routes need a PROVIDER whose verification is approved; the
/// rest wait on the pending screen (PROV-02-F1).
Future<String?> _providerGate(BuildContext context, GoRouterState state) async {
  if (!state.matchedLocation.startsWith('/pro/')) return null;
  final auth = context.read<AuthBloc>().state;
  if (auth is AuthAuthenticated) {
    final u = auth.user;
    if (!u.isProvider) return AppRoutes.forbidden;
    return (u.providerProfile?.isApproved ?? false)
        ? null
        : AppRoutes.providerPending;
  }
  // Session not restored yet (cold deep link): role from storage.
  return await sl<SecureStorage>().getUserRole() == 'PROVIDER'
      ? null
      : AppRoutes.forbidden;
}

final router = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.splash,
  redirect: _providerGate,
  errorBuilder: (_, _) => const NotFoundPage(),
  routes: [
    GoRoute(
      path: AppRoutes.sessionExpired,
      builder: (_, _) => const SessionExpiredPage(),
    ),
    GoRoute(
      path: AppRoutes.accountLocked,
      builder: (_, _) => const AccountLockedPage(),
    ),
    GoRoute(
      path: AppRoutes.forbidden,
      builder: (_, _) => const ForbiddenPage(),
    ),
    GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashPage()),
    GoRoute(
      path: AppRoutes.roleChoice,
      builder: (_, _) => const RoleChoicePage(),
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
        return SignInPage(
          role: role,
          resume: state.uri.queryParameters['resume'] == '1',
        );
      },
    ),
    GoRoute(
      path: AppRoutes.forgotPassword,
      builder: (_, _) => const ForgotPasswordPage(),
    ),
    GoRoute(
      path: AppRoutes.terms,
      builder: (_, state) => TermsPage(
        registrationData: state.extra as Map<String, dynamic>? ?? {},
      ),
    ),
    GoRoute(
      path: AppRoutes.preferences,
      builder: (_, state) => PreferencesPage(
        registrationData: state.extra as Map<String, dynamic>? ?? {},
      ),
    ),
    GoRoute(
      path: AppRoutes.permLocation,
      builder: (_, _) => const PermissionPrimingPage(
        kind: PermissionKind.location,
        next: AppRoutes.permNotifications,
      ),
    ),
    GoRoute(
      path: AppRoutes.permNotifications,
      builder: (_, _) => const PermissionPrimingPage(
        kind: PermissionKind.notifications,
        next: AppRoutes.home,
      ),
    ),
    GoRoute(
      path: AppRoutes.permission,
      builder: (_, state) => PermissionPrimingPage(
        kind:
            PermissionKind.values
                .asNameMap()[state.uri.queryParameters['kind']] ??
            PermissionKind.location,
      ),
    ),
    GoRoute(
      path: AppRoutes.termsReaccept,
      builder: (_, _) => const TermsReacceptPage(),
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
          display: extra['display'] as String?,
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
      builder: (_, _) => const ProviderPendingPage(),
    ),
    ShellRoute(
      navigatorKey: shellNavigatorKey,
      builder: (context, state, child) => ShellPage(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.home,
          pageBuilder: (_, state) => _tab(state, const HomePage()),
        ),
        GoRoute(
          path: AppRoutes.search,
          pageBuilder: (context, state) {
            final category = state.uri.queryParameters['category'];
            return _tab(state, SearchPage(initialCategory: category));
          },
        ),
        GoRoute(
          path: AppRoutes.bookings,
          pageBuilder: (_, state) => _tab(state, const MyBookingsPage()),
        ),
        GoRoute(
          path: AppRoutes.saved,
          pageBuilder: (_, state) => _tab(state, const SavedPage()),
        ),
        GoRoute(
          path: AppRoutes.profile,
          pageBuilder: (_, state) => _tab(state, const ProfilePage()),
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
      path: '/provider/:id/staff',
      // Needs the loaded provider as `extra`; a cold deep link goes to the
      // profile instead.
      redirect: (_, state) => state.extra is ProviderDetailEntity
          ? null
          : '/provider/${state.pathParameters['id']}',
      builder: (_, state) => StaffPickerPage(
        provider: state.extra as ProviderDetailEntity,
        serviceId: state.uri.queryParameters['serviceId'],
      ),
    ),
    GoRoute(
      path: '/booking-type/:providerId',
      builder: (_, state) => BookingTypePage(
        providerId: state.pathParameters['providerId'] ?? '0',
        serviceId: state.uri.queryParameters['serviceId'],
        staffId: state.uri.queryParameters['staffId'],
      ),
    ),
    GoRoute(
      path: '/booking/:providerId',
      builder: (context, state) {
        final providerId = state.pathParameters['providerId'] ?? '0';
        return BookingPage(
          providerId: providerId,
          initialServiceId: state.uri.queryParameters['serviceId'],
          staffId: state.uri.queryParameters['staffId'],
          mode: state.uri.queryParameters['mode'] ?? 'scheduled',
        );
      },
    ),
    // Live booking. Each page takes the booking as `extra` when it has one
    // and refreshes it from GET /bookings/{id}.
    for (final (path, page)
        in <(String, Widget Function(String, BookingEntity?))>[
          ('track', (id, b) => TrackingPage(bookingId: id, booking: b)),
          ('chat', (id, b) => ChatPage(bookingId: id, booking: b)),
          ('payment', (id, b) => PaymentConfirmPage(bookingId: id, booking: b)),
          (
            'proposed-time',
            (id, b) => ProposedTimePage(bookingId: id, booking: b),
          ),
          ('rejected', (id, b) => RejectedPage(bookingId: id, booking: b)),
          ('expired', (id, b) => ExpiredBookingPage(bookingId: id, booking: b)),
          ('complaint', (id, b) => ComplaintPage(bookingId: id, booking: b)),
        ])
      GoRoute(
        path: '/booking/:bookingId/$path',
        builder: (_, state) => page(
          state.pathParameters['bookingId']!,
          state.extra is BookingEntity ? state.extra as BookingEntity : null,
        ),
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
    GoRoute(
      path: AppRoutes.authGate,
      builder: (_, state) => AuthGatePage(returnTo: state.extra as String?),
    ),
    GoRoute(
      path: AppRoutes.permissionDenied,
      builder: (_, state) => PermissionDeniedPage(
        kind:
            PermissionKind.values
                .asNameMap()[state.uri.queryParameters['kind']] ??
            PermissionKind.location,
      ),
    ),
    for (final (path, page) in <(String, Widget)>[
      (AppRoutes.notifications, const NotificationsPage()),
      (AppRoutes.editProfile, const EditProfilePage()),
      (AppRoutes.addresses, const AddressesPage()),
      (AppRoutes.addressNew, const AddressFormPage()),
      (AppRoutes.trustedContacts, const TrustedContactsPage()),
      (AppRoutes.notificationPreferences, const NotificationPreferencesPage()),
      (AppRoutes.safetyPolicies, const SafetyPoliciesPage()),
      (AppRoutes.support, const SupportPage()),
      (AppRoutes.myReports, const MyReportsPage()),
    ])
      GoRoute(path: path, pageBuilder: (_, state) => _slide(state, page)),
    GoRoute(
      path: '/addresses/:id/edit',
      // Needs the address as `extra`; a cold deep link goes to the list.
      redirect: (_, state) =>
          state.extra is SavedAddressEntity ? null : AppRoutes.addresses,
      pageBuilder: (_, state) => _slide(
        state,
        AddressFormPage(existing: state.extra as SavedAddressEntity),
      ),
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
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => ProviderShellPage(shell: shell),
      branches: [
        for (final (path, page) in <(String, Widget)>[
          (AppRoutes.providerDashboard, const DashboardPage()),
          (AppRoutes.providerBookings, const ProviderBookingsPage()),
          (AppRoutes.providerServices, const ProviderServicesPage()),
          (AppRoutes.providerSchedule, const ProviderSchedulePage()),
          (AppRoutes.providerProfile, const ProviderProfilePage()),
        ])
          StatefulShellBranch(
            routes: [GoRoute(path: path, builder: (_, _) => page)],
          ),
      ],
    ),
    // Profile tab sub-screens.
    for (final (path, page) in <(String, Widget)>[
      (AppRoutes.providerBusinessInfo, const BusinessInfoPage()),
      (AppRoutes.providerGallery, const GalleryManagerPage()),
      (AppRoutes.providerStaff, const ProviderStaffPage()),
      (AppRoutes.providerWallet, const ProviderWalletPage()),
      (AppRoutes.providerReviews, const ProviderReviewsPage()),
    ])
      GoRoute(path: path, pageBuilder: (_, state) => _slide(state, page)),
    GoRoute(
      path: '/pro/bookings/:id',
      pageBuilder: (_, state) => _slide(
        state,
        ProviderBookingDetailPage(
          bookingId: state.pathParameters['id']!,
          booking: state.extra is BookingEntity
              ? state.extra as BookingEntity
              : null,
        ),
      ),
    ),
    // Close-out steps need the booking as `extra`; a cold deep link goes to
    // the detail instead.
    for (final (step, page) in <(String, Widget Function(BookingEntity))>[
      ('payment', (b) => ProviderPaymentConfirmPage(booking: b)),
      ('rate', (b) => RateCustomerPage(booking: b)),
    ])
      GoRoute(
        path: '/pro/bookings/:id/$step',
        redirect: (_, state) => state.extra is BookingEntity
            ? null
            : AppRoutes.providerBooking(state.pathParameters['id']!),
        pageBuilder: (_, state) =>
            _slide(state, page(state.extra as BookingEntity)),
      ),
  ],
);
