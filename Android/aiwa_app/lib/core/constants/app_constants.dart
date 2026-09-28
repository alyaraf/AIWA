class AppConstants {
  AppConstants._();

  // ponytail: only the 4 storage keys are referenced; the other 10 constants are unused, delete or wire them up
  static const String appName = 'AIWA';
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userRoleKey = 'user_role';
  static const String userIdKey = 'user_id';
  static const String languageKey = 'language';
  static const String onboardingDoneKey = 'onboarding_done';

  static const double defaultSearchRadius = 10.0;
  static const int pageSize = 20;
  static const int otpLength = 6;
  static const int otpExpirySeconds = 600;
  static const int otpResendSeconds = 45;

  static const String defaultCountryCode = '+20';
  static const String defaultCurrency = 'EGP';
}
