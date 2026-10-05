class ApiConstants {
  ApiConstants._();

  /// Override per build: --dart-define=API_BASE_URL=https://staging…/api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080/api',
  );

  /// S-08: the only base URL a release build may use: https with a host. The emulator default above
  /// is for debug/dev; release builds are blocked at build time (Gradle checkReleaseConfig,
  /// tool/build_release.sh) and again at start-up (main.dart) when this is false.
  static bool isSecureBaseUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  /// Backend media paths are relative to the API base ("/files/public/gallery/x.jpg");
  /// image widgets need an absolute URL. Absolute URLs pass through unchanged.
  static String mediaUrl(String path) =>
      path.startsWith('http://') || path.startsWith('https://')
      ? path
      : '$baseUrl${path.startsWith('/') ? '' : '/'}$path';

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 60);

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String meLanguage = '/auth/me/language';
  // PATCH {phone, code} after send-otp to the NEW number; returns fresh tokens.
  static const String mePhone = '/auth/me/phone';
  static const String mePreferences = '/auth/me/preferences';
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String resetPassword = '/auth/reset-password';
  static const String meAvatar = '/auth/me/avatar';
  static const String mePushToken = '/auth/me/push-token';
  static const String meNotificationPreferences =
      '/auth/me/notification-preferences';

  // Providers (public browse)
  static const String nearbyProviders = '/providers/nearby';
  static const String searchProviders = '/providers/search';
  static String providerProfile(String id) => '/providers/$id';
  static String providerServices(String id) => '/providers/$id/services';
  static String providerAvailability(String id) =>
      '/providers/$id/availability';
  static String providerReviews(String id) => '/providers/$id/reviews';
  static String providerGallery(String id) => '/provider/gallery/$id';
  static String providerStaffList(String id) => '/providers/$id/staff';
  static String providerGalleryReport(String id, String imageId) =>
      '/providers/$id/gallery/$imageId/report';

  // Provider self-management (PROVIDER role)
  static const String myProviderProfile = '/provider/profile';
  static const String providerDashboard = '/provider/dashboard';
  static const String providerStaff = '/provider/staff';
  static String providerStaffById(String id) => '/provider/staff/$id';
  static const String providerMode = '/provider/mode';
  static const String providerTravelFee = '/provider/mode/travel-fee';
  static const String providerTravelBuffer = '/provider/mode/travel-buffer';
  static const String providerSettlement = '/provider/settlement';
  static const String providerSettlementPay = '/provider/settlement/pay';
  static const String providerServiceCreate = '/provider/services';
  static String providerServiceUpdate(String id) => '/provider/services/$id';
  static String providerServiceDelete(String id) => '/provider/services/$id';
  static const String providerAvailabilityCreate = '/provider/availability';
  static String providerAvailabilityDelete(String id) =>
      '/provider/availability/$id';
  static const String providerGalleryUpload = '/provider/gallery';
  static const String providerGalleryImages = '/provider/gallery-images';
  static const String providerVerification = '/provider/verification/documents';
  static const String providerServiceRadius = '/provider/mode/service-radius';
  static String providerReviewReply(String id) => '/provider/reviews/$id/reply';

  /// POST ?category=&lat=&lng= — "Notify me when someone joins".
  static const String providerWaitlist = '/providers/waitlist';

  // Bookings
  static const String bookings = '/bookings';
  static String bookingById(String id) => '/bookings/$id';
  static const String myBookings = '/bookings/my';
  static const String providerBookings = '/bookings/provider';
  static const String availableSlots = '/bookings/slots';
  static String bookingAccept(String id) => '/bookings/$id/accept';
  static String bookingReject(String id) => '/bookings/$id/reject';
  static String bookingCancel(String id) => '/bookings/$id/cancel';
  static String bookingOnTheWay(String id) => '/bookings/$id/on-the-way';
  static String bookingArrived(String id) => '/bookings/$id/arrived';
  static String bookingInProgress(String id) => '/bookings/$id/in-progress';
  static String bookingComplete(String id) => '/bookings/$id/complete';
  static String bookingNoShow(String id) => '/bookings/$id/no-show';
  static String bookingReschedule(String id) => '/bookings/$id/reschedule';
  static String bookingProposeTime(String id) => '/bookings/$id/propose-time';
  static String bookingProposalResponse(String id) =>
      '/bookings/$id/proposal-response';
  static String bookingCheckIn(String id) => '/bookings/$id/check-in';
  static String bookingConfirmPayment(String id) =>
      '/bookings/$id/confirm-payment';
  static String bookingContestNoShow(String id) => '/bookings/$id/contest-no-show';
  static String bookingChat(String id) => '/bookings/$id/chat';
  static String bookingChatReport(String id, String messageId) =>
      '/bookings/$id/chat/$messageId/report';
  static String bookingSafety(String id) => '/bookings/$id/safety';
  static String bookingSafetyResolve(String id, String eventId) =>
      '/bookings/$id/safety/$eventId/resolve';

  /// The other party's phone while the booking is live (Call button).
  static String bookingContact(String id) => '/bookings/$id/contact';
  static String bookingTravelFeeQuote(String id) =>
      '/bookings/$id/travel-fee-quote';
  static String bookingTravelFeeResponse(String id) =>
      '/bookings/$id/travel-fee-response';

  // Saved addresses (AccountController)
  static const String savedAddresses = '/account/addresses';
  static String savedAddressById(String id) => '/account/addresses/$id';

  // Trusted contacts (texted on SOS)
  static const String trustedContacts = '/account/trusted-contacts';
  static String trustedContactById(String id) =>
      '/account/trusted-contacts/$id';

  /// DELETE: anonymize the account and cancel active bookings.
  static const String account = '/account';

  // Reviews
  static const String reviews = '/reviews';

  /// Reviews the signed-in user wrote (totalElements = review count).
  static const String myReviews = '/reviews/my';

  // Saved providers
  static const String savedProviders = '/users/me/saved';
  static String savedProviderById(String id) => '/users/me/saved/$id';
  static String checkSaved(String id) => '/users/me/saved/$id/check';

  // Notifications
  static const String notifications = '/notifications';
  static const String notificationsUnread = '/notifications/unread-count';
  static const String notificationsReadAll = '/notifications/mark-all-read';
  static String notificationRead(String id) => '/notifications/$id/read';

  // Complaints
  static const String complaints = '/complaints';
  static const String myComplaints = '/complaints/my';

  // Support
  static const String supportContact = '/support/contact';

  // Terms
  static const String termsLatest = '/terms/latest';
  static const String termsAccept = '/terms/accept';
}
