class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'http://10.0.2.2:8080/api';
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 60);

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String me = '/auth/me';
  static const String meLanguage = '/auth/me/language';
  static const String mePreferences = '/auth/me/preferences';
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String resetPassword = '/auth/reset-password';
  static const String meAvatar = '/auth/me/avatar';
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

  // Provider self-management (PROVIDER role)
  static const String myProviderProfile = '/provider/profile';
  static const String providerDashboard = '/provider/dashboard';
  static const String providerStaff = '/provider/staff';
  static String providerStaffById(String id) => '/provider/staff/$id';
  static const String providerMode = '/provider/mode';
  static const String providerTravelFee = '/provider/mode/travel-fee';
  static const String providerSettlement = '/provider/settlement';
  static const String providerSettlementPay = '/provider/settlement/pay';
  static const String providerServiceCreate = '/provider/services';
  static String providerServiceUpdate(String id) => '/provider/services/$id';
  static String providerServiceDelete(String id) => '/provider/services/$id';
  static const String providerAvailabilityCreate = '/provider/availability';
  static String providerAvailabilityDelete(String id) =>
      '/provider/availability/$id';
  static const String providerGalleryUpload = '/provider/gallery';
  static const String providerVerification = '/provider/verification/documents';

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
  static String bookingChat(String id) => '/bookings/$id/chat';
  static String bookingChatReport(String id, String messageId) =>
      '/bookings/$id/chat/$messageId/report';
  static String bookingSafety(String id) => '/bookings/$id/safety';

  // Saved addresses (AccountController)
  static const String savedAddresses = '/account/addresses';
  static String savedAddressById(String id) => '/account/addresses/$id';

  /// DELETE: anonymize the account and cancel active bookings.
  static const String account = '/account';

  // Reviews
  static const String reviews = '/reviews';

  // Saved providers
  static const String savedProviders = '/users/me/saved';
  static String savedProviderById(String id) => '/users/me/saved/$id';
  static String checkSaved(String id) => '/users/me/saved/$id/check';

  // Notifications
  static const String notifications = '/notifications';
  static const String notificationsUnread = '/notifications/unread-count';
  static const String notificationsReadAll = '/notifications/mark-all-read';

  // Complaints
  static const String complaints = '/complaints';
  static const String myComplaints = '/complaints/my';

  // Support
  static const String supportContact = '/support/contact';

  // Terms
  static const String termsLatest = '/terms/latest';
  static const String termsAccept = '/terms/accept';
}
