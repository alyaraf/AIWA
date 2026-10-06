import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @authTagline.
  ///
  /// In en, this message translates to:
  /// **'Beauty & grooming, near you.'**
  String get authTagline;

  /// No description provided for @authTaglineSub.
  ///
  /// In en, this message translates to:
  /// **'Trusted barbers, hairdressers, nail artists, and spas — one tap away.'**
  String get authTaglineSub;

  /// No description provided for @authChooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get authChooseLanguage;

  /// No description provided for @authBrowseAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Browse as guest →'**
  String get authBrowseAsGuest;

  /// No description provided for @authChoiceProviderEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Provider · Welcome'**
  String get authChoiceProviderEyebrow;

  /// No description provided for @authChoiceCustomerEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Customer · Welcome'**
  String get authChoiceCustomerEyebrow;

  /// No description provided for @authChoiceProviderTitle.
  ///
  /// In en, this message translates to:
  /// **'Run your beauty studio with AIWA.'**
  String get authChoiceProviderTitle;

  /// No description provided for @authChoiceProviderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage bookings, hours, and your verified profile — all in one app.'**
  String get authChoiceProviderSubtitle;

  /// No description provided for @authChoiceProviderSignUp.
  ///
  /// In en, this message translates to:
  /// **'Set up a new studio'**
  String get authChoiceProviderSignUp;

  /// No description provided for @authChoiceCustomerSignUp.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get authChoiceCustomerSignUp;

  /// No description provided for @authChoiceProviderHint.
  ///
  /// In en, this message translates to:
  /// **'ID verification required.'**
  String get authChoiceProviderHint;

  /// No description provided for @authChoiceCustomerHint.
  ///
  /// In en, this message translates to:
  /// **'Takes about a minute.'**
  String get authChoiceCustomerHint;

  /// No description provided for @authHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get authHaveAccount;

  /// No description provided for @authSignInWithPhoneOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Sign in with phone or email.'**
  String get authSignInWithPhoneOrEmail;

  /// No description provided for @authSafetyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Protected by AIWA\'s safety policy'**
  String get authSafetyPolicy;

  /// No description provided for @authGatePerkHistory.
  ///
  /// In en, this message translates to:
  /// **'Your booking history in one place'**
  String get authGatePerkHistory;

  /// No description provided for @authGatePerkTracking.
  ///
  /// In en, this message translates to:
  /// **'Live status + safety tracking'**
  String get authGatePerkTracking;

  /// No description provided for @authGatePerkFavorites.
  ///
  /// In en, this message translates to:
  /// **'Save favorite providers'**
  String get authGatePerkFavorites;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccount;

  /// No description provided for @authGateEyebrow.
  ///
  /// In en, this message translates to:
  /// **'One quick step'**
  String get authGateEyebrow;

  /// No description provided for @authGateTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to book.'**
  String get authGateTitle;

  /// No description provided for @authGateBody.
  ///
  /// In en, this message translates to:
  /// **'Browsing is open to everyone. Booking needs an account so providers can reach you.'**
  String get authGateBody;

  /// No description provided for @authStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String authStepOf(int step, int total);

  /// No description provided for @authModePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get authModePhone;

  /// No description provided for @authModeEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authModeEmail;

  /// No description provided for @errorNoInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get errorNoInternet;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out'**
  String get errorTimeout;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorGeneric;

  /// No description provided for @errorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Unauthorized. Please sign in again.'**
  String get errorUnauthorized;

  /// No description provided for @errorNotSupported.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t available yet.'**
  String get errorNotSupported;

  /// No description provided for @errorLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get errorLoginFailed;

  /// No description provided for @errorRegistrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed'**
  String get errorRegistrationFailed;

  /// No description provided for @errorSendOtpFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send OTP'**
  String get errorSendOtpFailed;

  /// No description provided for @errorInvalidOtp.
  ///
  /// In en, this message translates to:
  /// **'Invalid OTP'**
  String get errorInvalidOtp;

  /// No description provided for @authWelcomeBackName.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {name}.'**
  String authWelcomeBackName(String name);

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignIn;

  /// No description provided for @authNewToAiwa.
  ///
  /// In en, this message translates to:
  /// **'New to AIWA? '**
  String get authNewToAiwa;

  /// No description provided for @authProviderSignIn.
  ///
  /// In en, this message translates to:
  /// **'Provider sign in'**
  String get authProviderSignIn;

  /// No description provided for @authWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get authWelcomeBack;

  /// No description provided for @authSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to AIWA'**
  String get authSignInTitle;

  /// No description provided for @authSignInSubtitlePhone.
  ///
  /// In en, this message translates to:
  /// **'Use the number and password you signed up with.'**
  String get authSignInSubtitlePhone;

  /// No description provided for @authSignInSubtitleEmail.
  ///
  /// In en, this message translates to:
  /// **'Use the email and password you signed up with.'**
  String get authSignInSubtitleEmail;

  /// No description provided for @authPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get authPhoneNumber;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authRememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get authRememberMe;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get authSendCode;

  /// No description provided for @authWhatsYourPhone.
  ///
  /// In en, this message translates to:
  /// **'What\'s your phone number?'**
  String get authWhatsYourPhone;

  /// No description provided for @authWhatsYourEmail.
  ///
  /// In en, this message translates to:
  /// **'What\'s your email?'**
  String get authWhatsYourEmail;

  /// No description provided for @authSendCodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send a 6-digit code to confirm.'**
  String get authSendCodeSubtitle;

  /// No description provided for @authAgreeTerms.
  ///
  /// In en, this message translates to:
  /// **'By continuing you agree to AIWA\'s {terms} and {policy}.'**
  String authAgreeTerms(String terms, String policy);

  /// No description provided for @authTermsLink.
  ///
  /// In en, this message translates to:
  /// **'terms'**
  String get authTermsLink;

  /// No description provided for @authSafetyPolicyLink.
  ///
  /// In en, this message translates to:
  /// **'safety policy'**
  String get authSafetyPolicyLink;

  /// No description provided for @authVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get authVerify;

  /// No description provided for @authEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get authEnterCode;

  /// No description provided for @authCodeSentTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {destination}.'**
  String authCodeSentTo(String destination);

  /// No description provided for @authResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {time}'**
  String authResendIn(String time);

  /// No description provided for @authResendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get authResendCode;

  /// No description provided for @authOtpHelp.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t get it? Check the number, then tap Resend once the timer ends.'**
  String get authOtpHelp;

  /// No description provided for @authResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get authResetPassword;

  /// No description provided for @authWhereSendCode.
  ///
  /// In en, this message translates to:
  /// **'Where should we send the code?'**
  String get authWhereSendCode;

  /// No description provided for @authSendResetCode.
  ///
  /// In en, this message translates to:
  /// **'Send reset code'**
  String get authSendResetCode;

  /// No description provided for @authCheckMessages.
  ///
  /// In en, this message translates to:
  /// **'Check your messages.'**
  String get authCheckMessages;

  /// No description provided for @authCheckInbox.
  ///
  /// In en, this message translates to:
  /// **'Check your inbox.'**
  String get authCheckInbox;

  /// No description provided for @authAlmostDone.
  ///
  /// In en, this message translates to:
  /// **'Almost done'**
  String get authAlmostDone;

  /// No description provided for @authSetNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Set a new password.'**
  String get authSetNewPassword;

  /// No description provided for @authCodePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get authCodePlaceholder;

  /// No description provided for @authNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get authNewPassword;

  /// No description provided for @authConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authConfirmPassword;

  /// No description provided for @authPasswordResetDone.
  ///
  /// In en, this message translates to:
  /// **'Password reset. Please sign in.'**
  String get authPasswordResetDone;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @authSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your account'**
  String get authSetupTitle;

  /// No description provided for @authSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A name and a password — that\'s it. We\'ll add the rest later.'**
  String get authSetupSubtitle;

  /// No description provided for @authNameError.
  ///
  /// In en, this message translates to:
  /// **'Enter your first and last name'**
  String get authNameError;

  /// No description provided for @authEmailError.
  ///
  /// In en, this message translates to:
  /// **'Doesn\'t look like a valid email'**
  String get authEmailError;

  /// No description provided for @authPasswordMinError.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get authPasswordMinError;

  /// No description provided for @authPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters.'**
  String get authPasswordHint;

  /// No description provided for @authStrengthWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get authStrengthWeak;

  /// No description provided for @authStrengthOkay.
  ///
  /// In en, this message translates to:
  /// **'Okay'**
  String get authStrengthOkay;

  /// No description provided for @authStrengthGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get authStrengthGood;

  /// No description provided for @authStrengthStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get authStrengthStrong;

  /// No description provided for @authFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get authFullName;

  /// No description provided for @authNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. Layla Hassan'**
  String get authNamePlaceholder;

  /// No description provided for @authNameHint.
  ///
  /// In en, this message translates to:
  /// **'Your real name — providers see it on bookings.'**
  String get authNameHint;

  /// No description provided for @authEmailHint.
  ///
  /// In en, this message translates to:
  /// **'For receipts and account recovery.'**
  String get authEmailHint;

  /// No description provided for @authContinueWithoutPhoto.
  ///
  /// In en, this message translates to:
  /// **'Continue without a photo'**
  String get authContinueWithoutPhoto;

  /// No description provided for @authMakeItYours.
  ///
  /// In en, this message translates to:
  /// **'Make it yours'**
  String get authMakeItYours;

  /// No description provided for @authMakeItYoursSub.
  ///
  /// In en, this message translates to:
  /// **'Add a photo, pick your palette. You can change both later.'**
  String get authMakeItYoursSub;

  /// No description provided for @authUploadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload a photo'**
  String get authUploadPhoto;

  /// No description provided for @authReplacePhoto.
  ///
  /// In en, this message translates to:
  /// **'Replace photo'**
  String get authReplacePhoto;

  /// No description provided for @authSigningUpAs.
  ///
  /// In en, this message translates to:
  /// **'I\'m signing up as'**
  String get authSigningUpAs;

  /// No description provided for @authWoman.
  ///
  /// In en, this message translates to:
  /// **'Woman'**
  String get authWoman;

  /// No description provided for @authMan.
  ///
  /// In en, this message translates to:
  /// **'Man'**
  String get authMan;

  /// No description provided for @authPaletteNote.
  ///
  /// In en, this message translates to:
  /// **'This sets the palette of your app.'**
  String get authPaletteNote;

  /// No description provided for @authRoleCustomerTitle.
  ///
  /// In en, this message translates to:
  /// **'I\'m here to book'**
  String get authRoleCustomerTitle;

  /// No description provided for @authRoleCustomerSub.
  ///
  /// In en, this message translates to:
  /// **'Find a barber, hairdresser, nail artist, or spa near you.'**
  String get authRoleCustomerSub;

  /// No description provided for @authRolePerkBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse verified providers'**
  String get authRolePerkBrowse;

  /// No description provided for @authRolePerkCash.
  ///
  /// In en, this message translates to:
  /// **'Cash on visit'**
  String get authRolePerkCash;

  /// No description provided for @authRolePerkTrack.
  ///
  /// In en, this message translates to:
  /// **'Track your booking live'**
  String get authRolePerkTrack;

  /// No description provided for @authRoleProviderTitle.
  ///
  /// In en, this message translates to:
  /// **'I\'m offering services'**
  String get authRoleProviderTitle;

  /// No description provided for @authRoleProviderSub.
  ///
  /// In en, this message translates to:
  /// **'Get bookings from customers in your area.'**
  String get authRoleProviderSub;

  /// No description provided for @authRolePerkId.
  ///
  /// In en, this message translates to:
  /// **'ID verification required'**
  String get authRolePerkId;

  /// No description provided for @authRolePerkManage.
  ///
  /// In en, this message translates to:
  /// **'Manage your services & hours'**
  String get authRolePerkManage;

  /// No description provided for @authRolePerkPayouts.
  ///
  /// In en, this message translates to:
  /// **'Cash payouts'**
  String get authRolePerkPayouts;

  /// No description provided for @authWelcomeToAiwa.
  ///
  /// In en, this message translates to:
  /// **'Welcome to AIWA'**
  String get authWelcomeToAiwa;

  /// No description provided for @authHowUsing.
  ///
  /// In en, this message translates to:
  /// **'How will you\nbe using AIWA?'**
  String get authHowUsing;

  /// No description provided for @authChangeLater.
  ///
  /// In en, this message translates to:
  /// **'You can change this later from your profile.'**
  String get authChangeLater;

  /// No description provided for @authTermsVerifiedTitle.
  ///
  /// In en, this message translates to:
  /// **'Verified providers only'**
  String get authTermsVerifiedTitle;

  /// No description provided for @authTermsVerifiedBody.
  ///
  /// In en, this message translates to:
  /// **'Every provider is checked with a national ID and a live selfie before they can take bookings.'**
  String get authTermsVerifiedBody;

  /// No description provided for @authTermsPrivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Your data stays private'**
  String get authTermsPrivateTitle;

  /// No description provided for @authTermsPrivateBody.
  ///
  /// In en, this message translates to:
  /// **'Your phone and address are only shared with a provider after you confirm a booking with them.'**
  String get authTermsPrivateBody;

  /// No description provided for @authTermsFlagTitle.
  ///
  /// In en, this message translates to:
  /// **'You can always flag or complain'**
  String get authTermsFlagTitle;

  /// No description provided for @authTermsFlagBody.
  ///
  /// In en, this message translates to:
  /// **'If anything feels off, flag the provider or open a complaint. Our team reviews every report.'**
  String get authTermsFlagBody;

  /// No description provided for @authTermsCashTitle.
  ///
  /// In en, this message translates to:
  /// **'Cash only — for now'**
  String get authTermsCashTitle;

  /// No description provided for @authTermsCashBody.
  ///
  /// In en, this message translates to:
  /// **'In this version you pay the provider directly in cash after the service. Online payment is on the way.'**
  String get authTermsCashBody;

  /// No description provided for @authAgreeContinue.
  ///
  /// In en, this message translates to:
  /// **'Agree & continue'**
  String get authAgreeContinue;

  /// No description provided for @authTermsTitle.
  ///
  /// In en, this message translates to:
  /// **'A few promises\nbefore you start.'**
  String get authTermsTitle;

  /// No description provided for @authTermsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'AIWA\'s customer terms & safety policy in plain words.'**
  String get authTermsSubtitle;

  /// No description provided for @authTermsAgree.
  ///
  /// In en, this message translates to:
  /// **'I\'ve read and agree to the AIWA {terms} and {policy}.'**
  String authTermsAgree(String terms, String policy);

  /// No description provided for @authCustomerTermsLink.
  ///
  /// In en, this message translates to:
  /// **'customer terms'**
  String get authCustomerTermsLink;

  /// No description provided for @authTermsAccepted.
  ///
  /// In en, this message translates to:
  /// **'Thanks — terms accepted.'**
  String get authTermsAccepted;

  /// No description provided for @authPoliciesUpdated.
  ///
  /// In en, this message translates to:
  /// **'Policies updated'**
  String get authPoliciesUpdated;

  /// No description provided for @authTermsUpdatedTitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ve updated our terms.'**
  String get authTermsUpdatedTitle;

  /// No description provided for @authTermsUpdatedBody.
  ///
  /// In en, this message translates to:
  /// **'AIWA\'s terms & safety policy changed on May 20, 2026 — mainly around cancellation penalties and provider verification. Please re-accept to keep booking.'**
  String get authTermsUpdatedBody;

  /// No description provided for @authTermsVersion.
  ///
  /// In en, this message translates to:
  /// **'v{version}'**
  String authTermsVersion(Object version);

  /// No description provided for @authTermsReadFull.
  ///
  /// In en, this message translates to:
  /// **'Full terms and policies'**
  String get authTermsReadFull;

  /// No description provided for @authTermsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load the current terms. Check your connection and try again.'**
  String get authTermsLoadFailed;

  /// No description provided for @authTermsChangedWhileSigningUp.
  ///
  /// In en, this message translates to:
  /// **'The terms were updated while you were signing up. Please review the new version before you continue.'**
  String get authTermsChangedWhileSigningUp;

  /// No description provided for @authTermsReview.
  ///
  /// In en, this message translates to:
  /// **'Review terms'**
  String get authTermsReview;

  /// No description provided for @provSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish setting up your business'**
  String get provSetupTitle;

  /// No description provided for @provSetupBody.
  ///
  /// In en, this message translates to:
  /// **'Your account is created, but your business details have not been saved yet. Add them with your ID so we can review you.'**
  String get provSetupBody;

  /// No description provided for @provSetupContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue setup'**
  String get provSetupContinue;

  /// No description provided for @provDocsMissingTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload your ID'**
  String get provDocsMissingTitle;

  /// No description provided for @provDocsMissingBody.
  ///
  /// In en, this message translates to:
  /// **'Your business is saved, but we have not received your ID photos and selfie yet. Upload them to be reviewed.'**
  String get provDocsMissingBody;

  /// No description provided for @provDocsUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload documents'**
  String get provDocsUpload;

  /// No description provided for @categoryHair.
  ///
  /// In en, this message translates to:
  /// **'Hair'**
  String get categoryHair;

  /// No description provided for @categoryNails.
  ///
  /// In en, this message translates to:
  /// **'Nails'**
  String get categoryNails;

  /// No description provided for @categorySpa.
  ///
  /// In en, this message translates to:
  /// **'Spa'**
  String get categorySpa;

  /// No description provided for @categoryMakeup.
  ///
  /// In en, this message translates to:
  /// **'Makeup'**
  String get categoryMakeup;

  /// No description provided for @categoryLashes.
  ///
  /// In en, this message translates to:
  /// **'Lashes'**
  String get categoryLashes;

  /// No description provided for @categorySkin.
  ///
  /// In en, this message translates to:
  /// **'Skin'**
  String get categorySkin;

  /// No description provided for @categoryMassage.
  ///
  /// In en, this message translates to:
  /// **'Massage'**
  String get categoryMassage;

  /// No description provided for @categoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoryOther;

  /// No description provided for @prefsSave.
  ///
  /// In en, this message translates to:
  /// **'Save preferences'**
  String get prefsSave;

  /// No description provided for @prefsLastStep.
  ///
  /// In en, this message translates to:
  /// **'Last step'**
  String get prefsLastStep;

  /// No description provided for @prefsTitle.
  ///
  /// In en, this message translates to:
  /// **'Where should we\nlook for providers?'**
  String get prefsTitle;

  /// No description provided for @prefsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We use these to tune the providers we show you. Change them any time from Profile.'**
  String get prefsSubtitle;

  /// No description provided for @commonUseGps.
  ///
  /// In en, this message translates to:
  /// **'Use GPS'**
  String get commonUseGps;

  /// No description provided for @prefsSearchRadius.
  ///
  /// In en, this message translates to:
  /// **'Search radius'**
  String get prefsSearchRadius;

  /// No description provided for @prefsRadiusRange.
  ///
  /// In en, this message translates to:
  /// **'{min}–{max} km'**
  String prefsRadiusRange(int min, int max);

  /// No description provided for @prefsMinKm.
  ///
  /// In en, this message translates to:
  /// **'Min · {km} km'**
  String prefsMinKm(int km);

  /// No description provided for @prefsMaxKm.
  ///
  /// In en, this message translates to:
  /// **'Max · {km} km'**
  String prefsMaxKm(int km);

  /// No description provided for @prefsAppLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get prefsAppLanguage;

  /// No description provided for @authAccountCreatedReview.
  ///
  /// In en, this message translates to:
  /// **'Account created. Verification in review.'**
  String get authAccountCreatedReview;

  /// No description provided for @provBizTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your studio'**
  String get provBizTitle;

  /// No description provided for @provBizSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customers will see this on your profile.'**
  String get provBizSubtitle;

  /// No description provided for @provBizName.
  ///
  /// In en, this message translates to:
  /// **'Business name'**
  String get provBizName;

  /// No description provided for @provBizNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. Nadia Studio'**
  String get provBizNamePlaceholder;

  /// No description provided for @provBizType.
  ///
  /// In en, this message translates to:
  /// **'Business type'**
  String get provBizType;

  /// No description provided for @provBizIndividual.
  ///
  /// In en, this message translates to:
  /// **'Individual'**
  String get provBizIndividual;

  /// No description provided for @provBizShop.
  ///
  /// In en, this message translates to:
  /// **'Shop / salon'**
  String get provBizShop;

  /// No description provided for @provBizShopNote.
  ///
  /// In en, this message translates to:
  /// **'Shops can add staff members with their own calendars.'**
  String get provBizShopNote;

  /// No description provided for @provBizStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff members'**
  String get provBizStaff;

  /// No description provided for @commonOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get commonOptional;

  /// No description provided for @provBizStaffName.
  ///
  /// In en, this message translates to:
  /// **'Staff member {number} name'**
  String provBizStaffName(int number);

  /// No description provided for @provBizAddStaff.
  ///
  /// In en, this message translates to:
  /// **'Add staff member'**
  String get provBizAddStaff;

  /// No description provided for @provBizStaffNote.
  ///
  /// In en, this message translates to:
  /// **'Add the team who\'ll take bookings. You can add more later.'**
  String get provBizStaffNote;

  /// No description provided for @provBizBio.
  ///
  /// In en, this message translates to:
  /// **'Short bio'**
  String get provBizBio;

  /// No description provided for @provBizBioPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Cairo-trained colorist with a soft, editorial touch…'**
  String get provBizBioPlaceholder;

  /// No description provided for @provBizBioHint.
  ///
  /// In en, this message translates to:
  /// **'2–3 lines on what makes you stand out.'**
  String get provBizBioHint;

  /// No description provided for @provBizPrimaryCategory.
  ///
  /// In en, this message translates to:
  /// **'Primary category'**
  String get provBizPrimaryCategory;

  /// No description provided for @provBizPickOne.
  ///
  /// In en, this message translates to:
  /// **'Pick the one you do most.'**
  String get provBizPickOne;

  /// No description provided for @provBizAddress.
  ///
  /// In en, this message translates to:
  /// **'Studio address'**
  String get provBizAddress;

  /// No description provided for @provBizAddressPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Street, neighborhood, city'**
  String get provBizAddressPlaceholder;

  /// No description provided for @provBizGpsLocked.
  ///
  /// In en, this message translates to:
  /// **'GPS locked — {lat}, {lng}'**
  String provBizGpsLocked(String lat, String lng);

  /// No description provided for @provBizNoGps.
  ///
  /// In en, this message translates to:
  /// **'No GPS — tap \"Use GPS\"'**
  String get provBizNoGps;

  /// No description provided for @provBizNearby.
  ///
  /// In en, this message translates to:
  /// **'Customers nearby can find you'**
  String get provBizNearby;

  /// No description provided for @provPendingEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Verification submitted'**
  String get provPendingEyebrow;

  /// No description provided for @provPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'We\'re reviewing\nyour documents.'**
  String get provPendingTitle;

  /// No description provided for @provPendingBody.
  ///
  /// In en, this message translates to:
  /// **'Most reviews take {duration}. You\'ll get a notification the moment AIWA approves your studio — then you can take bookings.'**
  String provPendingBody(String duration);

  /// No description provided for @provPendingUnder24h.
  ///
  /// In en, this message translates to:
  /// **'under 24 hours'**
  String get provPendingUnder24h;

  /// No description provided for @provPendingIdReceived.
  ///
  /// In en, this message translates to:
  /// **'ID front & back received'**
  String get provPendingIdReceived;

  /// No description provided for @provPendingSelfieReceived.
  ///
  /// In en, this message translates to:
  /// **'Live selfie received'**
  String get provPendingSelfieReceived;

  /// No description provided for @provPendingAdminReview.
  ///
  /// In en, this message translates to:
  /// **'Admin review in progress'**
  String get provPendingAdminReview;

  /// No description provided for @provPendingExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore the app while you wait'**
  String get provPendingExplore;

  /// No description provided for @provPendingBrowseNote.
  ///
  /// In en, this message translates to:
  /// **'You can browse, but bookings open after verification.'**
  String get provPendingBrowseNote;

  /// No description provided for @provStatusCheck.
  ///
  /// In en, this message translates to:
  /// **'Check status'**
  String get provStatusCheck;

  /// No description provided for @provInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'AIWA needs a bit more from you'**
  String get provInfoTitle;

  /// No description provided for @provRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Not approved yet'**
  String get provRejectedTitle;

  /// No description provided for @provRejectedBody.
  ///
  /// In en, this message translates to:
  /// **'Our team couldn\'t approve your documents. Fix the issue below and send them again.'**
  String get provRejectedBody;

  /// No description provided for @provSuspendedTitle.
  ///
  /// In en, this message translates to:
  /// **'Your provider account is suspended'**
  String get provSuspendedTitle;

  /// No description provided for @provSuspendedBody.
  ///
  /// In en, this message translates to:
  /// **'You can\'t take bookings right now. Contact support to find out why and what to do next.'**
  String get provSuspendedBody;

  /// No description provided for @provResubmit.
  ///
  /// In en, this message translates to:
  /// **'Send documents again'**
  String get provResubmit;

  /// No description provided for @provAdminNote.
  ///
  /// In en, this message translates to:
  /// **'Note from AIWA'**
  String get provAdminNote;

  /// No description provided for @provDocsResent.
  ///
  /// In en, this message translates to:
  /// **'Documents sent. We\'ll review them shortly.'**
  String get provDocsResent;

  /// No description provided for @provVerifySubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit for review'**
  String get provVerifySubmit;

  /// No description provided for @provVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity'**
  String get provVerifyTitle;

  /// No description provided for @provVerifySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload your national ID and a live selfie. AIWA reviews every provider before they can take bookings.'**
  String get provVerifySubtitle;

  /// No description provided for @provVerifyIdFront.
  ///
  /// In en, this message translates to:
  /// **'National ID — front'**
  String get provVerifyIdFront;

  /// No description provided for @provVerifyIdFrontHint.
  ///
  /// In en, this message translates to:
  /// **'Front side of your government-issued ID. Make sure all four corners are visible.'**
  String get provVerifyIdFrontHint;

  /// No description provided for @provVerifyIdBack.
  ///
  /// In en, this message translates to:
  /// **'National ID — back'**
  String get provVerifyIdBack;

  /// No description provided for @provVerifyIdBackHint.
  ///
  /// In en, this message translates to:
  /// **'The back side of the same ID.'**
  String get provVerifyIdBackHint;

  /// No description provided for @provVerifySelfie.
  ///
  /// In en, this message translates to:
  /// **'Live selfie'**
  String get provVerifySelfie;

  /// No description provided for @provVerifySelfieHint.
  ///
  /// In en, this message translates to:
  /// **'A clear photo of your face, taken now. We compare it to your ID.'**
  String get provVerifySelfieHint;

  /// No description provided for @provVerifyPrivate.
  ///
  /// In en, this message translates to:
  /// **'Your documents are private. Only AIWA admins reviewing your account see them. They\'re never shown to customers.'**
  String get provVerifyPrivate;

  /// No description provided for @provVerifyUploaded.
  ///
  /// In en, this message translates to:
  /// **'{label} uploaded · tap to replace'**
  String provVerifyUploaded(String label);

  /// No description provided for @moneyEgp.
  ///
  /// In en, this message translates to:
  /// **'EGP {amount}'**
  String moneyEgp(String amount);

  /// No description provided for @whenToday.
  ///
  /// In en, this message translates to:
  /// **'Today · {time}'**
  String whenToday(String time);

  /// No description provided for @whenTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow · {time}'**
  String whenTomorrow(String time);

  /// No description provided for @whenYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday · {time}'**
  String whenYesterday(String time);

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{m, plural, other{{m} min}}'**
  String durationMinutes(int m);

  /// No description provided for @durationHours.
  ///
  /// In en, this message translates to:
  /// **'{h, plural, other{{h}h}}'**
  String durationHours(int h);

  /// No description provided for @durationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{h}h {m}m'**
  String durationHoursMinutes(int h, int m);

  /// No description provided for @bookNowOfflineEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Not online'**
  String get bookNowOfflineEyebrow;

  /// No description provided for @bookNowOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} is offline right now.'**
  String bookNowOfflineTitle(String name);

  /// No description provided for @bookNowOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'They’ll show as available again the moment they come back online. You can try Book Now later, or pick a scheduled time now.'**
  String get bookNowOfflineBody;

  /// No description provided for @bookNowBusyEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Fully booked'**
  String get bookNowBusyEyebrow;

  /// No description provided for @bookNowBusyTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} is busy with another client.'**
  String bookNowBusyTitle(String name);

  /// No description provided for @bookNowBusyBody.
  ///
  /// In en, this message translates to:
  /// **'Every Book Now slot is taken for the next stretch. A scheduled slot later today is usually faster than waiting.'**
  String get bookNowBusyBody;

  /// No description provided for @bookNowVacationEyebrow.
  ///
  /// In en, this message translates to:
  /// **'On vacation'**
  String get bookNowVacationEyebrow;

  /// No description provided for @bookNowVacationTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} is on vacation.'**
  String bookNowVacationTitle(String name);

  /// No description provided for @bookNowVacationBody.
  ///
  /// In en, this message translates to:
  /// **'They’ve paused all bookings for now. We’ll show them again as soon as they’re back.'**
  String get bookNowVacationBody;

  /// No description provided for @bookNowPausedEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Temporarily paused'**
  String get bookNowPausedEyebrow;

  /// No description provided for @bookNowPausedTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} can’t take new bookings right now.'**
  String bookNowPausedTitle(String name);

  /// No description provided for @bookNowPausedBody.
  ///
  /// In en, this message translates to:
  /// **'They’re settling an outstanding balance with AIWA. This clears automatically once that’s paid — try again soon.'**
  String get bookNowPausedBody;

  /// No description provided for @bookNowUnavailableEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get bookNowUnavailableEyebrow;

  /// No description provided for @bookNowUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} isn’t taking bookings.'**
  String bookNowUnavailableTitle(String name);

  /// No description provided for @bookNowUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'This provider, staff member, or service is temporarily inactive. Try another provider nearby.'**
  String get bookNowUnavailableBody;

  /// No description provided for @bookNowChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking availability…'**
  String get bookNowChecking;

  /// No description provided for @bookNowConfirming.
  ///
  /// In en, this message translates to:
  /// **'Confirming {name} can take this right now.'**
  String bookNowConfirming(String name);

  /// No description provided for @bookNowChooseScheduled.
  ///
  /// In en, this message translates to:
  /// **'Choose a scheduled time'**
  String get bookNowChooseScheduled;

  /// No description provided for @bookNowSeeOthers.
  ///
  /// In en, this message translates to:
  /// **'See other providers nearby'**
  String get bookNowSeeOthers;

  /// No description provided for @bookingPlaced.
  ///
  /// In en, this message translates to:
  /// **'Booking placed'**
  String get bookingPlaced;

  /// No description provided for @bookingSaidAiwa.
  ///
  /// In en, this message translates to:
  /// **'You said {aiwa}. We told {name}.'**
  String bookingSaidAiwa(String aiwa, String name);

  /// No description provided for @bookingAiwaWord.
  ///
  /// In en, this message translates to:
  /// **'aiwa'**
  String get bookingAiwaWord;

  /// No description provided for @bookingWhenLong.
  ///
  /// In en, this message translates to:
  /// **'{date} at {time}'**
  String bookingWhenLong(String date, String time);

  /// No description provided for @bookingConfirmPing.
  ///
  /// In en, this message translates to:
  /// **'{when}. We\'ll ping you the moment they confirm — usually within 30 minutes.'**
  String bookingConfirmPing(String when);

  /// No description provided for @bookingProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get bookingProvider;

  /// No description provided for @bookingService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get bookingService;

  /// No description provided for @bookingWhen.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get bookingWhen;

  /// No description provided for @bookingTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get bookingTotal;

  /// No description provided for @bookingViewMine.
  ///
  /// In en, this message translates to:
  /// **'View my bookings'**
  String get bookingViewMine;

  /// No description provided for @bookingAddToCalendar.
  ///
  /// In en, this message translates to:
  /// **'Add to calendar'**
  String get bookingAddToCalendar;

  /// No description provided for @bookingTypeEyebrow.
  ///
  /// In en, this message translates to:
  /// **'How do you want to book'**
  String get bookingTypeEyebrow;

  /// No description provided for @bookingTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Now, or later?'**
  String get bookingTypeTitle;

  /// No description provided for @bookingTypeAccepts.
  ///
  /// In en, this message translates to:
  /// **'{name} accepts both same-day requests and scheduled bookings.'**
  String bookingTypeAccepts(String name);

  /// No description provided for @bookingTypeNowEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Book now'**
  String get bookingTypeNowEyebrow;

  /// No description provided for @bookingTypeNowTitle.
  ///
  /// In en, this message translates to:
  /// **'Get someone on the way'**
  String get bookingTypeNowTitle;

  /// No description provided for @bookingTypeNowEta.
  ///
  /// In en, this message translates to:
  /// **'Est. arrival 25–40 min'**
  String get bookingTypeNowEta;

  /// No description provided for @bookingTypeNowComes.
  ///
  /// In en, this message translates to:
  /// **'Comes to you'**
  String get bookingTypeNowComes;

  /// No description provided for @bookingTypeScheduleEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get bookingTypeScheduleEyebrow;

  /// No description provided for @bookingTypeScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a date & time slot'**
  String get bookingTypeScheduleTitle;

  /// No description provided for @bookingTypeUpTo14.
  ///
  /// In en, this message translates to:
  /// **'Up to 14 days out'**
  String get bookingTypeUpTo14;

  /// No description provided for @bookingTypeProviderConfirms.
  ///
  /// In en, this message translates to:
  /// **'Provider confirms slot'**
  String get bookingTypeProviderConfirms;

  /// No description provided for @bookingTypeCashNote.
  ///
  /// In en, this message translates to:
  /// **'Either way, payment is {cash}. Online payment is coming in a future version.'**
  String bookingTypeCashNote(String cash);

  /// No description provided for @bookingCashOnVisit.
  ///
  /// In en, this message translates to:
  /// **'cash on visit'**
  String get bookingCashOnVisit;

  /// No description provided for @chatReportEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Report message'**
  String get chatReportEyebrow;

  /// No description provided for @chatReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Send this to admin review?'**
  String get chatReportTitle;

  /// No description provided for @chatReportBody.
  ///
  /// In en, this message translates to:
  /// **'Support reviews reported messages and can remove them. This doesn\'t notify the other person.'**
  String get chatReportBody;

  /// No description provided for @chatMaskedOnline.
  ///
  /// In en, this message translates to:
  /// **'Masked number · online'**
  String get chatMaskedOnline;

  /// No description provided for @chatAdminNote.
  ///
  /// In en, this message translates to:
  /// **'Admin can view this chat only if you submit a complaint or dispute a payment.'**
  String get chatAdminNote;

  /// No description provided for @chatHint.
  ///
  /// In en, this message translates to:
  /// **'Message…'**
  String get chatHint;

  /// No description provided for @chatRemoved.
  ///
  /// In en, this message translates to:
  /// **'[message removed by admin]'**
  String get chatRemoved;

  /// No description provided for @chatReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get chatReport;

  /// No description provided for @bookingsGuestTitle.
  ///
  /// In en, this message translates to:
  /// **'See your bookings'**
  String get bookingsGuestTitle;

  /// No description provided for @bookingsGuestBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view and track your bookings.'**
  String get bookingsGuestBody;

  /// No description provided for @bookingsEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Your appointments'**
  String get bookingsEyebrow;

  /// No description provided for @bookingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get bookingsTitle;

  /// No description provided for @bookingsUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get bookingsUpcoming;

  /// No description provided for @bookingsPast.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get bookingsPast;

  /// No description provided for @bookingsEmptyUpcomingTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing booked yet'**
  String get bookingsEmptyUpcomingTitle;

  /// No description provided for @bookingsEmptyPastTitle.
  ///
  /// In en, this message translates to:
  /// **'No past appointments'**
  String get bookingsEmptyPastTitle;

  /// No description provided for @bookingsEmptyUpcomingBody.
  ///
  /// In en, this message translates to:
  /// **'When you book a provider, it shows up here so you can track them on the way.'**
  String get bookingsEmptyUpcomingBody;

  /// No description provided for @bookingsEmptyPastBody.
  ///
  /// In en, this message translates to:
  /// **'Once an appointment is finished it moves here, ready to re-book in a tap.'**
  String get bookingsEmptyPastBody;

  /// No description provided for @bookingsFindProvider.
  ///
  /// In en, this message translates to:
  /// **'Find a provider'**
  String get bookingsFindProvider;

  /// No description provided for @commonLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get commonLoadMore;

  /// No description provided for @distanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String distanceKm(String km);

  /// No description provided for @bookingsNoShow.
  ///
  /// In en, this message translates to:
  /// **'Marked no-show'**
  String get bookingsNoShow;

  /// No description provided for @bookingsRejectedByProvider.
  ///
  /// In en, this message translates to:
  /// **'Rejected by provider'**
  String get bookingsRejectedByProvider;

  /// No description provided for @bookingsCancelledByYou.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by you'**
  String get bookingsCancelledByYou;

  /// No description provided for @bookingsCancelledByProvider.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by Provider'**
  String get bookingsCancelledByProvider;

  /// No description provided for @bookingsCancelledBy.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by {who}'**
  String bookingsCancelledBy(String who);

  /// No description provided for @commonQuoted.
  ///
  /// In en, this message translates to:
  /// **'\"{text}\"'**
  String commonQuoted(String text);

  /// No description provided for @bookingsPenaltyApplied.
  ///
  /// In en, this message translates to:
  /// **'Provider penalty applied for late cancellation.'**
  String get bookingsPenaltyApplied;

  /// No description provided for @bookingsTrack.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get bookingsTrack;

  /// No description provided for @bookingsDirections.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get bookingsDirections;

  /// No description provided for @bookingsRebook.
  ///
  /// In en, this message translates to:
  /// **'Re-book'**
  String get bookingsRebook;

  /// No description provided for @bookingsLeaveReview.
  ///
  /// In en, this message translates to:
  /// **'Leave a review'**
  String get bookingsLeaveReview;

  /// No description provided for @bookingsSeeAlternatives.
  ///
  /// In en, this message translates to:
  /// **'See alternatives'**
  String get bookingsSeeAlternatives;

  /// No description provided for @bookingRebookedFor.
  ///
  /// In en, this message translates to:
  /// **'Rebooked for {time}.'**
  String bookingRebookedFor(String time);

  /// No description provided for @bookingProviderOnWay.
  ///
  /// In en, this message translates to:
  /// **'Provider is on the way.'**
  String get bookingProviderOnWay;

  /// No description provided for @bookingPlacedWaiting.
  ///
  /// In en, this message translates to:
  /// **'Booking placed. Waiting to confirm.'**
  String get bookingPlacedWaiting;

  /// No description provided for @bookingThisProvider.
  ///
  /// In en, this message translates to:
  /// **'this provider'**
  String get bookingThisProvider;

  /// No description provided for @bookingBookService.
  ///
  /// In en, this message translates to:
  /// **'Book a service'**
  String get bookingBookService;

  /// No description provided for @bookingPickTime.
  ///
  /// In en, this message translates to:
  /// **'Pick a time'**
  String get bookingPickTime;

  /// No description provided for @bookingDateMonth.
  ///
  /// In en, this message translates to:
  /// **'Date · {month}'**
  String bookingDateMonth(String month);

  /// No description provided for @bookingAvailableSlots.
  ///
  /// In en, this message translates to:
  /// **'Available slots'**
  String get bookingAvailableSlots;

  /// No description provided for @bookingNoSlots.
  ///
  /// In en, this message translates to:
  /// **'No free slots on this day — try another date.'**
  String get bookingNoSlots;

  /// No description provided for @bookingWhere.
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get bookingWhere;

  /// No description provided for @bookingNowAddressNote.
  ///
  /// In en, this message translates to:
  /// **'Book Now always comes to your address — confirm which one below.'**
  String get bookingNowAddressNote;

  /// No description provided for @bookingAtMyAddress.
  ///
  /// In en, this message translates to:
  /// **'At my address'**
  String get bookingAtMyAddress;

  /// No description provided for @bookingAtSalon.
  ///
  /// In en, this message translates to:
  /// **'At the salon'**
  String get bookingAtSalon;

  /// No description provided for @bookingAddAddress.
  ///
  /// In en, this message translates to:
  /// **'Add new address'**
  String get bookingAddAddress;

  /// No description provided for @bookingPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get bookingPayment;

  /// No description provided for @bookingCashOnVisitTitle.
  ///
  /// In en, this message translates to:
  /// **'Cash on visit'**
  String get bookingCashOnVisitTitle;

  /// No description provided for @bookingCashOnVisitSub.
  ///
  /// In en, this message translates to:
  /// **'Pay the provider directly after your service'**
  String get bookingCashOnVisitSub;

  /// No description provided for @bookingNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note for the provider'**
  String get bookingNoteLabel;

  /// No description provided for @bookingNotePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Any special requests…'**
  String get bookingNotePlaceholder;

  /// No description provided for @bookingTotalCash.
  ///
  /// In en, this message translates to:
  /// **'Total · cash'**
  String get bookingTotalCash;

  /// No description provided for @bookingChooseService.
  ///
  /// In en, this message translates to:
  /// **'Choose a service'**
  String get bookingChooseService;

  /// No description provided for @bookingChooseTime.
  ///
  /// In en, this message translates to:
  /// **'Choose a time'**
  String get bookingChooseTime;

  /// No description provided for @bookingChooseAddress.
  ///
  /// In en, this message translates to:
  /// **'Choose an address'**
  String get bookingChooseAddress;

  /// No description provided for @bookingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm booking'**
  String get bookingConfirm;

  /// No description provided for @bookingChooseServiceBelow.
  ///
  /// In en, this message translates to:
  /// **'Choose a service below'**
  String get bookingChooseServiceBelow;

  /// No description provided for @outcomeExpiredEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Request expired'**
  String get outcomeExpiredEyebrow;

  /// No description provided for @outcomeExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'No answer in time.'**
  String get outcomeExpiredTitle;

  /// No description provided for @outcomeExpiredBody.
  ///
  /// In en, this message translates to:
  /// **'{name} didn\'t respond within the booking window, so your request was released. You haven\'t been charged anything.'**
  String outcomeExpiredBody(String name);

  /// No description provided for @outcomeTheProvider.
  ///
  /// In en, this message translates to:
  /// **'The provider'**
  String get outcomeTheProvider;

  /// No description provided for @outcomeSeeAlternatives.
  ///
  /// In en, this message translates to:
  /// **'See alternative providers'**
  String get outcomeSeeAlternatives;

  /// No description provided for @outcomeBackToBookings.
  ///
  /// In en, this message translates to:
  /// **'Back to bookings'**
  String get outcomeBackToBookings;

  /// No description provided for @rejectedEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Booking rejected'**
  String get rejectedEyebrow;

  /// No description provided for @rejectedTitleGeneric.
  ///
  /// In en, this message translates to:
  /// **'Provider couldn’t take this one.'**
  String get rejectedTitleGeneric;

  /// No description provided for @rejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} couldn\'t take this one.'**
  String rejectedTitle(String name);

  /// No description provided for @rejectedSimilar.
  ///
  /// In en, this message translates to:
  /// **'Similar providers'**
  String get rejectedSimilar;

  /// No description provided for @rejectedOtherNearby.
  ///
  /// In en, this message translates to:
  /// **'Other providers nearby'**
  String get rejectedOtherNearby;

  /// No description provided for @rejectedReasonFrom.
  ///
  /// In en, this message translates to:
  /// **'Reason from {name}'**
  String rejectedReasonFrom(String name);

  /// No description provided for @rejectedBookAnother.
  ///
  /// In en, this message translates to:
  /// **'Book {name} at another time'**
  String rejectedBookAnother(String name);

  /// No description provided for @rejectedNextSlots.
  ///
  /// In en, this message translates to:
  /// **'Next open slots for the same service'**
  String get rejectedNextSlots;

  /// No description provided for @rejectedSeeAllTimes.
  ///
  /// In en, this message translates to:
  /// **'See all times'**
  String get rejectedSeeAllTimes;

  /// No description provided for @commonToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get commonToday;

  /// No description provided for @commonTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get commonTomorrow;

  /// No description provided for @commonBook.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get commonBook;

  /// No description provided for @distanceMeters.
  ///
  /// In en, this message translates to:
  /// **'{m} m'**
  String distanceMeters(int m);

  /// No description provided for @proposedAccepted.
  ///
  /// In en, this message translates to:
  /// **'New time confirmed — your calendar and reminders are updated.'**
  String get proposedAccepted;

  /// No description provided for @proposedEyebrow.
  ///
  /// In en, this message translates to:
  /// **'New time proposed'**
  String get proposedEyebrow;

  /// No description provided for @proposedTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} suggested a different time.'**
  String proposedTitle(String name);

  /// No description provided for @proposedLead.
  ///
  /// In en, this message translates to:
  /// **'Your original slot wasn\'t available. Here\'s what they can offer instead.'**
  String get proposedLead;

  /// No description provided for @proposedInsteadOf.
  ///
  /// In en, this message translates to:
  /// **'Instead of {when}'**
  String proposedInsteadOf(String when);

  /// No description provided for @proposedExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'This offer expired'**
  String get proposedExpiredTitle;

  /// No description provided for @proposedExpiredBody.
  ///
  /// In en, this message translates to:
  /// **'You didn\'t respond in time, so the request was released automatically. Ask for another time or see who else is free.'**
  String get proposedExpiredBody;

  /// No description provided for @proposedRespondWithin.
  ///
  /// In en, this message translates to:
  /// **'Respond within {time} or this offer expires automatically.'**
  String proposedRespondWithin(String time);

  /// No description provided for @proposedAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept new time'**
  String get proposedAccept;

  /// No description provided for @proposedDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline & see alternatives'**
  String get proposedDecline;

  /// No description provided for @payConfirmedToast.
  ///
  /// In en, this message translates to:
  /// **'Payment confirmed. Receipt sent.'**
  String get payConfirmedToast;

  /// No description provided for @payUnpaidToast.
  ///
  /// In en, this message translates to:
  /// **'Reported as unpaid. AIWA support has been notified.'**
  String get payUnpaidToast;

  /// No description provided for @payEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Confirm payment'**
  String get payEyebrow;

  /// No description provided for @payTitle.
  ///
  /// In en, this message translates to:
  /// **'Did you pay {name} in cash?'**
  String payTitle(String name);

  /// No description provided for @payTotalDue.
  ///
  /// In en, this message translates to:
  /// **'Total due · {amount}'**
  String payTotalDue(String amount);

  /// No description provided for @payYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, I paid — confirm'**
  String get payYes;

  /// No description provided for @payNo.
  ///
  /// In en, this message translates to:
  /// **'No / something\'s wrong'**
  String get payNo;

  /// No description provided for @payRate.
  ///
  /// In en, this message translates to:
  /// **'Rate your provider'**
  String get payRate;

  /// No description provided for @payUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo — I tapped by mistake'**
  String get payUndo;

  /// No description provided for @payWhatHappened.
  ///
  /// In en, this message translates to:
  /// **'What happened?'**
  String get payWhatHappened;

  /// No description provided for @payExplainPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Explain the payment issue…'**
  String get payExplainPlaceholder;

  /// No description provided for @paySubmitUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Submit as unpaid'**
  String get paySubmitUnpaid;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @paidTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment confirmed'**
  String get paidTitle;

  /// No description provided for @paidSub.
  ///
  /// In en, this message translates to:
  /// **'Receipt sent to your email'**
  String get paidSub;

  /// No description provided for @paidCashCollected.
  ///
  /// In en, this message translates to:
  /// **'Cash collected'**
  String get paidCashCollected;

  /// No description provided for @paidCommission.
  ///
  /// In en, this message translates to:
  /// **'AIWA commission ({percent}%) · added to ledger'**
  String paidCommission(String percent);

  /// No description provided for @paidBookingStatus.
  ///
  /// In en, this message translates to:
  /// **'Booking status'**
  String get paidBookingStatus;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @complaintBehavior.
  ///
  /// In en, this message translates to:
  /// **'Provider behavior'**
  String get complaintBehavior;

  /// No description provided for @complaintBehaviorHint.
  ///
  /// In en, this message translates to:
  /// **'Rude, unsafe, or unprofessional conduct.'**
  String get complaintBehaviorHint;

  /// No description provided for @complaintQuality.
  ///
  /// In en, this message translates to:
  /// **'Service quality'**
  String get complaintQuality;

  /// No description provided for @complaintQualityHint.
  ///
  /// In en, this message translates to:
  /// **'Service didn\'t match what was advertised.'**
  String get complaintQualityHint;

  /// No description provided for @complaintPricing.
  ///
  /// In en, this message translates to:
  /// **'Pricing or billing'**
  String get complaintPricing;

  /// No description provided for @complaintPricingHint.
  ///
  /// In en, this message translates to:
  /// **'Asked for more cash than agreed.'**
  String get complaintPricingHint;

  /// No description provided for @complaintSafety.
  ///
  /// In en, this message translates to:
  /// **'Safety concern'**
  String get complaintSafety;

  /// No description provided for @complaintSafetyHint.
  ///
  /// In en, this message translates to:
  /// **'Hygiene, identity, or any safety issue.'**
  String get complaintSafetyHint;

  /// No description provided for @complaintNoShow.
  ///
  /// In en, this message translates to:
  /// **'Provider didn\'t show'**
  String get complaintNoShow;

  /// No description provided for @complaintNoShowHint.
  ///
  /// In en, this message translates to:
  /// **'Booked but never arrived.'**
  String get complaintNoShowHint;

  /// No description provided for @complaintOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get complaintOther;

  /// No description provided for @complaintOtherHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us in your own words.'**
  String get complaintOtherHint;

  /// No description provided for @complaintSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Complaint submitted. We will reach out via WhatsApp.'**
  String get complaintSubmitted;

  /// No description provided for @complaintEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Open a complaint'**
  String get complaintEyebrow;

  /// No description provided for @complaintPickCategory.
  ///
  /// In en, this message translates to:
  /// **'Pick a category'**
  String get complaintPickCategory;

  /// No description provided for @complaintTellMore.
  ///
  /// In en, this message translates to:
  /// **'Tell us more'**
  String get complaintTellMore;

  /// No description provided for @complaintPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Walk us through what happened. The more detail, the faster we can help.'**
  String get complaintPlaceholder;

  /// No description provided for @complaintPrivate.
  ///
  /// In en, this message translates to:
  /// **'Your name and contact info stay private. Only the AIWA support team will see this case.'**
  String get complaintPrivate;

  /// No description provided for @complaintSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit complaint'**
  String get complaintSubmit;

  /// No description provided for @complaintAbout.
  ///
  /// In en, this message translates to:
  /// **'About {name}'**
  String complaintAbout(String name);

  /// No description provided for @complaintBookingNo.
  ///
  /// In en, this message translates to:
  /// **'Booking #{id}'**
  String complaintBookingNo(String id);

  /// No description provided for @complaintPrivateTag.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get complaintPrivateTag;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get statusConfirmed;

  /// No description provided for @statusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get statusAccepted;

  /// No description provided for @statusOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get statusOnTheWay;

  /// No description provided for @statusArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get statusArrived;

  /// No description provided for @statusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get statusInProgress;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @statusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get statusRejected;

  /// No description provided for @statusNoShow.
  ///
  /// In en, this message translates to:
  /// **'No-show'**
  String get statusNoShow;

  /// No description provided for @statusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get statusExpired;

  /// No description provided for @statusDisputed.
  ///
  /// In en, this message translates to:
  /// **'Disputed'**
  String get statusDisputed;

  /// No description provided for @trackPendingHint.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the provider to confirm.'**
  String get trackPendingHint;

  /// No description provided for @trackAcceptedHint.
  ///
  /// In en, this message translates to:
  /// **'Your booking is confirmed.'**
  String get trackAcceptedHint;

  /// No description provided for @trackOnTheWayHint.
  ///
  /// In en, this message translates to:
  /// **'Provider is heading to your address.'**
  String get trackOnTheWayHint;

  /// No description provided for @trackArrivedHint.
  ///
  /// In en, this message translates to:
  /// **'Provider has arrived at your door.'**
  String get trackArrivedHint;

  /// No description provided for @trackInProgressHint.
  ///
  /// In en, this message translates to:
  /// **'Service is underway.'**
  String get trackInProgressHint;

  /// No description provided for @trackCompletedHint.
  ///
  /// In en, this message translates to:
  /// **'Service done. Pay cash and rate.'**
  String get trackCompletedHint;

  /// No description provided for @trackWaitPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the provider to accept'**
  String get trackWaitPending;

  /// No description provided for @trackWaitAccepted.
  ///
  /// In en, this message translates to:
  /// **'Updates when the provider heads out'**
  String get trackWaitAccepted;

  /// No description provided for @trackWaitOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'Updates when the provider arrives'**
  String get trackWaitOnTheWay;

  /// No description provided for @trackWaitArrived.
  ///
  /// In en, this message translates to:
  /// **'Updates when the provider starts the service'**
  String get trackWaitArrived;

  /// No description provided for @trackWaitInProgress.
  ///
  /// In en, this message translates to:
  /// **'Updates when the provider marks it complete'**
  String get trackWaitInProgress;

  /// No description provided for @trackUpdatesAuto.
  ///
  /// In en, this message translates to:
  /// **'Updates automatically'**
  String get trackUpdatesAuto;

  /// No description provided for @cancelReasonMind.
  ///
  /// In en, this message translates to:
  /// **'Changed my mind'**
  String get cancelReasonMind;

  /// No description provided for @cancelReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Found another provider'**
  String get cancelReasonOther;

  /// No description provided for @cancelReasonWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong service / time'**
  String get cancelReasonWrong;

  /// No description provided for @cancelReasonPrice.
  ///
  /// In en, this message translates to:
  /// **'Price is too high'**
  String get cancelReasonPrice;

  /// No description provided for @cancelReasonUnresponsive.
  ///
  /// In en, this message translates to:
  /// **'Provider not responsive'**
  String get cancelReasonUnresponsive;

  /// No description provided for @cancelReasonElse.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get cancelReasonElse;

  /// No description provided for @trackCancelEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Cancel your booking'**
  String get trackCancelEyebrow;

  /// No description provided for @trackCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Why are you cancelling?'**
  String get trackCancelTitle;

  /// No description provided for @trackCancelledToast.
  ///
  /// In en, this message translates to:
  /// **'Booking cancelled. Reason: {reason}'**
  String trackCancelledToast(String reason);

  /// No description provided for @trackStatusTimeline.
  ///
  /// In en, this message translates to:
  /// **'Status timeline'**
  String get trackStatusTimeline;

  /// No description provided for @trackCancelBooking.
  ///
  /// In en, this message translates to:
  /// **'Cancel booking'**
  String get trackCancelBooking;

  /// No description provided for @trackReportProblem.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get trackReportProblem;

  /// No description provided for @trackTracking.
  ///
  /// In en, this message translates to:
  /// **'Tracking'**
  String get trackTracking;

  /// No description provided for @trackSafetyTitle.
  ///
  /// In en, this message translates to:
  /// **'SOS is one tap away'**
  String get trackSafetyTitle;

  /// No description provided for @trackSafetySub.
  ///
  /// In en, this message translates to:
  /// **'SOS alerts AIWA support and texts your trusted contacts.'**
  String get trackSafetySub;

  /// No description provided for @trackSos.
  ///
  /// In en, this message translates to:
  /// **'SOS — alert a trusted contact & AIWA'**
  String get trackSos;

  /// No description provided for @trackSosAlerting.
  ///
  /// In en, this message translates to:
  /// **'Alerting your trusted contact and AIWA support…'**
  String get trackSosAlerting;

  /// No description provided for @trackSosNotified.
  ///
  /// In en, this message translates to:
  /// **'{bold} {detail} In immediate danger, call 122.'**
  String trackSosNotified(String bold, String detail);

  /// No description provided for @trackSosNotifiedBold.
  ///
  /// In en, this message translates to:
  /// **'AIWA support has been alerted.'**
  String get trackSosNotifiedBold;

  /// No description provided for @trackSosRecordedBold.
  ///
  /// In en, this message translates to:
  /// **'Your SOS was recorded.'**
  String get trackSosRecordedBold;

  /// No description provided for @trackSosTexting.
  ///
  /// In en, this message translates to:
  /// **'Texting your trusted contacts…'**
  String get trackSosTexting;

  /// No description provided for @trackSosTexted.
  ///
  /// In en, this message translates to:
  /// **'Trusted contacts texted: {count}.'**
  String trackSosTexted(int count);

  /// No description provided for @trackSosTextFailed.
  ///
  /// In en, this message translates to:
  /// **'Texts that could not be sent: {count}. Call them yourself if you can.'**
  String trackSosTextFailed(int count);

  /// No description provided for @trackSosNoContacts.
  ///
  /// In en, this message translates to:
  /// **'No trusted contacts were texted.'**
  String get trackSosNoContacts;

  /// No description provided for @trackSosLogged.
  ///
  /// In en, this message translates to:
  /// **'You\'re marked safe and the SOS is closed. Support can still see it on this booking.'**
  String get trackSosLogged;

  /// No description provided for @trackSosFailed.
  ///
  /// In en, this message translates to:
  /// **'Your SOS could not be sent. Try again. In immediate danger, call 122.'**
  String get trackSosFailed;

  /// No description provided for @trackImSafe.
  ///
  /// In en, this message translates to:
  /// **'I\'m safe'**
  String get trackImSafe;

  /// No description provided for @trackCheckInTitle.
  ///
  /// In en, this message translates to:
  /// **'On-site service — check in when you arrive'**
  String get trackCheckInTitle;

  /// No description provided for @trackCheckInSub.
  ///
  /// In en, this message translates to:
  /// **'Tap in at the venue to let {name} know you\'re there.'**
  String trackCheckInSub(String name);

  /// No description provided for @trackCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'Checked in'**
  String get trackCheckedIn;

  /// No description provided for @trackCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get trackCheckIn;

  /// No description provided for @trackConfirmCash.
  ///
  /// In en, this message translates to:
  /// **'Confirm your cash payment'**
  String get trackConfirmCash;

  /// No description provided for @trackDueTo.
  ///
  /// In en, this message translates to:
  /// **'{amount} due to {name}'**
  String trackDueTo(String amount, String name);

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @trackFeeWants.
  ///
  /// In en, this message translates to:
  /// **'{name} wants {amount} for travel'**
  String trackFeeWants(String name, String amount);

  /// No description provided for @trackFeeTotal.
  ///
  /// In en, this message translates to:
  /// **'Total will be {base} + {fee} = {total}.'**
  String trackFeeTotal(String base, String fee, String total);

  /// No description provided for @commonDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get commonDecline;

  /// No description provided for @trackAcceptConfirm.
  ///
  /// In en, this message translates to:
  /// **'Accept & confirm'**
  String get trackAcceptConfirm;

  /// No description provided for @trackServicePlusTravel.
  ///
  /// In en, this message translates to:
  /// **'Service {service} + travel {travel}'**
  String trackServicePlusTravel(String service, String travel);

  /// No description provided for @trackTotalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total {amount}'**
  String trackTotalAmount(String amount);

  /// No description provided for @trackDeclinedEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Booking cancelled'**
  String get trackDeclinedEyebrow;

  /// No description provided for @trackDeclinedTitle.
  ///
  /// In en, this message translates to:
  /// **'No problem — no fee applied.'**
  String get trackDeclinedTitle;

  /// No description provided for @trackDeclinedBody.
  ///
  /// In en, this message translates to:
  /// **'You declined the {fee} travel fee, so this request was cancelled cleanly. Neither of you is penalized.'**
  String trackDeclinedBody(String fee);

  /// No description provided for @trackFindAnother.
  ///
  /// In en, this message translates to:
  /// **'Find another provider'**
  String get trackFindAnother;

  /// No description provided for @agoYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get agoYesterday;

  /// No description provided for @agoDays.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 day ago} other{{n} days ago}}'**
  String agoDays(int n);

  /// No description provided for @agoWeeks.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 week ago} other{{n} weeks ago}}'**
  String agoWeeks(int n);

  /// No description provided for @agoMonths.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 month ago} other{{n} months ago}}'**
  String agoMonths(int n);

  /// No description provided for @providerShareText.
  ///
  /// In en, this message translates to:
  /// **'{name} on AIWA'**
  String providerShareText(String name);

  /// No description provided for @providerStartsAt.
  ///
  /// In en, this message translates to:
  /// **'Starts at'**
  String get providerStartsAt;

  /// No description provided for @providerAskProvider.
  ///
  /// In en, this message translates to:
  /// **'Ask provider'**
  String get providerAskProvider;

  /// No description provided for @providerBookNow.
  ///
  /// In en, this message translates to:
  /// **'Book now'**
  String get providerBookNow;

  /// No description provided for @providerNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get providerNew;

  /// No description provided for @providerVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get providerVerified;

  /// No description provided for @providerBioFallback.
  ///
  /// In en, this message translates to:
  /// **'Top-rated provider in your area. Read more about the studio, services, and recent reviews.'**
  String get providerBioFallback;

  /// No description provided for @providerCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get providerCall;

  /// No description provided for @providerWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get providerWhatsApp;

  /// No description provided for @providerReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get providerReport;

  /// No description provided for @providerNoReviews.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get providerNoReviews;

  /// No description provided for @providerNoReviewsBody.
  ///
  /// In en, this message translates to:
  /// **'Be the first to book and leave a review.'**
  String get providerNoReviewsBody;

  /// No description provided for @providerBasedOn.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Based on 1 review} other{Based on {count} reviews}}'**
  String providerBasedOn(int count);

  /// No description provided for @providerNoPhotos.
  ///
  /// In en, this message translates to:
  /// **'No photos yet'**
  String get providerNoPhotos;

  /// No description provided for @providerNoPhotosBody.
  ///
  /// In en, this message translates to:
  /// **'This provider hasn\'t added gallery photos.'**
  String get providerNoPhotosBody;

  /// No description provided for @providerNoServices.
  ///
  /// In en, this message translates to:
  /// **'No services listed'**
  String get providerNoServices;

  /// No description provided for @providerNoServicesBody.
  ///
  /// In en, this message translates to:
  /// **'This provider has not published services yet.'**
  String get providerNoServicesBody;

  /// No description provided for @providerTabServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get providerTabServices;

  /// No description provided for @providerTabReviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get providerTabReviews;

  /// No description provided for @providerTabGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get providerTabGallery;

  /// No description provided for @providerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get providerUnavailable;

  /// No description provided for @staffPickTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick your stylist.'**
  String get staffPickTitle;

  /// No description provided for @staffPickBody.
  ///
  /// In en, this message translates to:
  /// **'This is a shop with multiple staff — your booking will be tied to whoever you pick.'**
  String get staffPickBody;

  /// No description provided for @staffNoPreference.
  ///
  /// In en, this message translates to:
  /// **'No preference'**
  String get staffNoPreference;

  /// No description provided for @staffFirstAvailable.
  ///
  /// In en, this message translates to:
  /// **'First available staff member'**
  String get staffFirstAvailable;

  /// No description provided for @flagReasonMisleading.
  ///
  /// In en, this message translates to:
  /// **'Misleading profile or gallery'**
  String get flagReasonMisleading;

  /// No description provided for @flagReasonBehavior.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate or unsafe behavior'**
  String get flagReasonBehavior;

  /// No description provided for @flagReasonPrice.
  ///
  /// In en, this message translates to:
  /// **'Refused to honor agreed price'**
  String get flagReasonPrice;

  /// No description provided for @flagReasonIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity feels suspicious'**
  String get flagReasonIdentity;

  /// No description provided for @flagReasonSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam or fake account'**
  String get flagReasonSpam;

  /// No description provided for @flagReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get flagReasonOther;

  /// No description provided for @flagThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks — flag received. Our team reviews every report.'**
  String get flagThanks;

  /// No description provided for @flagEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Flag {name}'**
  String flagEyebrow(String name);

  /// No description provided for @flagTitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us what\'s wrong'**
  String get flagTitle;

  /// No description provided for @flagBody.
  ///
  /// In en, this message translates to:
  /// **'Flags are anonymous. Our team reviews every report and acts on the provider if confirmed.'**
  String get flagBody;

  /// No description provided for @flagHelpUs.
  ///
  /// In en, this message translates to:
  /// **'Help us understand'**
  String get flagHelpUs;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @flagSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit flag'**
  String get flagSubmit;

  /// No description provided for @providerReportPhoto.
  ///
  /// In en, this message translates to:
  /// **'Report photo'**
  String get providerReportPhoto;

  /// No description provided for @providerReportPhotoHint.
  ///
  /// In en, this message translates to:
  /// **'Press and hold a photo to report it.'**
  String get providerReportPhotoHint;

  /// No description provided for @homeOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get homeOpen;

  /// No description provided for @homeOpenNow.
  ///
  /// In en, this message translates to:
  /// **'Open now'**
  String get homeOpenNow;

  /// No description provided for @homeFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get homeFrom;

  /// No description provided for @homeNearMe.
  ///
  /// In en, this message translates to:
  /// **'Near me'**
  String get homeNearMe;

  /// No description provided for @homeGoodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get homeGoodMorning;

  /// No description provided for @homeGoodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get homeGoodAfternoon;

  /// No description provided for @homeGoodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get homeGoodEvening;

  /// No description provided for @homeGreetingName.
  ///
  /// In en, this message translates to:
  /// **'{greeting}, {name}'**
  String homeGreetingName(String greeting, String name);

  /// No description provided for @homeHeadline.
  ///
  /// In en, this message translates to:
  /// **'Who\'s making you\nfeel new tonight?'**
  String get homeHeadline;

  /// No description provided for @homeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Service or provider'**
  String get homeSearchHint;

  /// No description provided for @homePromoEyebrow.
  ///
  /// In en, this message translates to:
  /// **'This week · 20% off'**
  String get homePromoEyebrow;

  /// No description provided for @homePromoTitle.
  ///
  /// In en, this message translates to:
  /// **'Bridal lookbook season'**
  String get homePromoTitle;

  /// No description provided for @homePromoBody.
  ///
  /// In en, this message translates to:
  /// **'Top-rated makeup & lash artists, with package pricing.'**
  String get homePromoBody;

  /// No description provided for @homeExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore →'**
  String get homeExplore;

  /// No description provided for @homeCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get homeCategories;

  /// No description provided for @commonSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get commonSeeAll;

  /// No description provided for @homeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get homeAll;

  /// No description provided for @homeNobodyNearby.
  ///
  /// In en, this message translates to:
  /// **'Nobody nearby yet'**
  String get homeNobodyNearby;

  /// No description provided for @homeNobodyNearbyBody.
  ///
  /// In en, this message translates to:
  /// **'No providers within your radius right now. Try browsing all categories.'**
  String get homeNobodyNearbyBody;

  /// No description provided for @homeBrowseAll.
  ///
  /// In en, this message translates to:
  /// **'Browse all'**
  String get homeBrowseAll;

  /// No description provided for @homeTrending.
  ///
  /// In en, this message translates to:
  /// **'Trending near you'**
  String get homeTrending;

  /// No description provided for @homeViewMap.
  ///
  /// In en, this message translates to:
  /// **'View map'**
  String get homeViewMap;

  /// No description provided for @homeAvailableNow.
  ///
  /// In en, this message translates to:
  /// **'Available now'**
  String get homeAvailableNow;

  /// No description provided for @searchSortNearest.
  ///
  /// In en, this message translates to:
  /// **'Nearest'**
  String get searchSortNearest;

  /// No description provided for @searchSortTopRated.
  ///
  /// In en, this message translates to:
  /// **'Top rated'**
  String get searchSortTopRated;

  /// No description provided for @searchSortPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get searchSortPrice;

  /// No description provided for @searchNotifyToast.
  ///
  /// In en, this message translates to:
  /// **'We\'ll let you know.'**
  String get searchNotifyToast;

  /// No description provided for @searchEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Find someone new'**
  String get searchEyebrow;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get searchTitle;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search providers, services, locations'**
  String get searchHint;

  /// No description provided for @searchMinRatingChip.
  ///
  /// In en, this message translates to:
  /// **'★ {rating}+ ×'**
  String searchMinRatingChip(String rating);

  /// No description provided for @searchUnderPriceChip.
  ///
  /// In en, this message translates to:
  /// **'Under {price} ×'**
  String searchUnderPriceChip(String price);

  /// No description provided for @searchSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get searchSort;

  /// No description provided for @searchFound.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} found}}'**
  String searchFound(int count);

  /// No description provided for @searchNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No match for “{query}”'**
  String searchNoMatch(String query);

  /// No description provided for @searchNothingInCategory.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this category nearby'**
  String get searchNothingInCategory;

  /// No description provided for @searchNoMatchBody.
  ///
  /// In en, this message translates to:
  /// **'Try a different spelling, or browse by category instead.'**
  String get searchNoMatchBody;

  /// No description provided for @searchNoFilterMatchBody.
  ///
  /// In en, this message translates to:
  /// **'No providers within your radius match these filters yet.'**
  String get searchNoFilterMatchBody;

  /// No description provided for @searchClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear search & filters'**
  String get searchClearAll;

  /// No description provided for @searchWiden.
  ///
  /// In en, this message translates to:
  /// **'Widen my radius'**
  String get searchWiden;

  /// No description provided for @searchNotifyMe.
  ///
  /// In en, this message translates to:
  /// **'Notify me when someone joins'**
  String get searchNotifyMe;

  /// No description provided for @searchInRange.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 provider in range} other{{count} providers in range}}'**
  String searchInRange(int count);

  /// No description provided for @searchFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get searchFilters;

  /// No description provided for @searchReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get searchReset;

  /// No description provided for @searchMinRating.
  ///
  /// In en, this message translates to:
  /// **'Minimum rating'**
  String get searchMinRating;

  /// No description provided for @searchAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get searchAny;

  /// No description provided for @searchMaxPrice.
  ///
  /// In en, this message translates to:
  /// **'Max price'**
  String get searchMaxPrice;

  /// No description provided for @searchShowProviders.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Show 1 provider} other{Show {count} providers}}'**
  String searchShowProviders(int count);

  /// No description provided for @tabToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tabToday;

  /// No description provided for @tabBookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get tabBookings;

  /// No description provided for @tabServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get tabServices;

  /// No description provided for @tabSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get tabSchedule;

  /// No description provided for @tabProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// No description provided for @dashNewRequests.
  ///
  /// In en, this message translates to:
  /// **'New requests'**
  String get dashNewRequests;

  /// No description provided for @dashPendingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} pending'**
  String dashPendingCount(int count);

  /// No description provided for @dashConfirmedToday.
  ///
  /// In en, this message translates to:
  /// **'Confirmed today'**
  String get dashConfirmedToday;

  /// No description provided for @dashNothingElse.
  ///
  /// In en, this message translates to:
  /// **'Nothing else on the books for today.'**
  String get dashNothingElse;

  /// No description provided for @dashHelloName.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String dashHelloName(String name);

  /// No description provided for @dashHello.
  ///
  /// In en, this message translates to:
  /// **'Hello'**
  String get dashHello;

  /// No description provided for @dashTodaysSchedule.
  ///
  /// In en, this message translates to:
  /// **'Today\'s schedule.'**
  String get dashTodaysSchedule;

  /// No description provided for @dashStatToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dashStatToday;

  /// No description provided for @dashStatEgpToday.
  ///
  /// In en, this message translates to:
  /// **'EGP today'**
  String get dashStatEgpToday;

  /// No description provided for @dashStatRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get dashStatRating;

  /// No description provided for @dashNewRequestsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new booking request} other{{count} new booking requests}}'**
  String dashNewRequestsCount(int count);

  /// No description provided for @dashReplyWithin.
  ///
  /// In en, this message translates to:
  /// **'Reply within 30 minutes to keep your top rating.'**
  String get dashReplyWithin;

  /// No description provided for @commonCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get commonCustomer;

  /// No description provided for @commonAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get commonAccept;

  /// No description provided for @provBookingsEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get provBookingsEyebrow;

  /// No description provided for @provTabPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get provTabPending;

  /// No description provided for @provTabUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get provTabUpcoming;

  /// No description provided for @provTabPast.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get provTabPast;

  /// No description provided for @provNothingHere.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet.'**
  String get provNothingHere;

  /// No description provided for @closeTheCustomer.
  ///
  /// In en, this message translates to:
  /// **'the customer'**
  String get closeTheCustomer;

  /// No description provided for @closeDisputedToast.
  ///
  /// In en, this message translates to:
  /// **'Marked as disputed. Admin has been notified.'**
  String get closeDisputedToast;

  /// No description provided for @closeEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Close out this job'**
  String get closeEyebrow;

  /// No description provided for @closeDidPay.
  ///
  /// In en, this message translates to:
  /// **'Did {name} pay in cash?'**
  String closeDidPay(String name);

  /// No description provided for @closeCashReceived.
  ///
  /// In en, this message translates to:
  /// **'Yes, cash received'**
  String get closeCashReceived;

  /// No description provided for @closeMarkDisputed.
  ///
  /// In en, this message translates to:
  /// **'Mark unpaid or disputed'**
  String get closeMarkDisputed;

  /// No description provided for @closeJobClosed.
  ///
  /// In en, this message translates to:
  /// **'Cash received · job closed'**
  String get closeJobClosed;

  /// No description provided for @closeReceiptSentTo.
  ///
  /// In en, this message translates to:
  /// **'Receipt sent to {name}'**
  String closeReceiptSentTo(String name);

  /// No description provided for @closeRate.
  ///
  /// In en, this message translates to:
  /// **'Rate {name}'**
  String closeRate(String name);

  /// No description provided for @closeSubmitDisputed.
  ///
  /// In en, this message translates to:
  /// **'Submit as disputed'**
  String get closeSubmitDisputed;

  /// No description provided for @rateTagOnTime.
  ///
  /// In en, this message translates to:
  /// **'On time'**
  String get rateTagOnTime;

  /// No description provided for @rateTagRespectful.
  ///
  /// In en, this message translates to:
  /// **'Respectful'**
  String get rateTagRespectful;

  /// No description provided for @rateTagClear.
  ///
  /// In en, this message translates to:
  /// **'Clear about needs'**
  String get rateTagClear;

  /// No description provided for @rateTagPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid in full'**
  String get rateTagPaid;

  /// No description provided for @rateTagLate.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get rateTagLate;

  /// No description provided for @rateTagHardToReach.
  ///
  /// In en, this message translates to:
  /// **'Difficult to reach'**
  String get rateTagHardToReach;

  /// No description provided for @rateSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Rating submitted. Slot freed — next booking notified.'**
  String get rateSubmitted;

  /// No description provided for @rateCustomerFallback.
  ///
  /// In en, this message translates to:
  /// **'customer'**
  String get rateCustomerFallback;

  /// No description provided for @rateSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit rating'**
  String get rateSubmit;

  /// No description provided for @rateEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Two-way rating'**
  String get rateEyebrow;

  /// No description provided for @rateStars.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 star} other{{n} stars}}'**
  String rateStars(int n);

  /// No description provided for @rateQuickTags.
  ///
  /// In en, this message translates to:
  /// **'Quick tags'**
  String get rateQuickTags;

  /// No description provided for @pbdAltTimeSent.
  ///
  /// In en, this message translates to:
  /// **'Alternative time sent to customer.'**
  String get pbdAltTimeSent;

  /// No description provided for @pbdCancelEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Cancelling after accepting'**
  String get pbdCancelEyebrow;

  /// No description provided for @pbdCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'This applies a penalty'**
  String get pbdCancelTitle;

  /// No description provided for @pbdCancelWarning.
  ///
  /// In en, this message translates to:
  /// **'Cancelling an accepted booking affects your reliability score and adds a small penalty fee to your ledger.'**
  String get pbdCancelWarning;

  /// No description provided for @pbdReasonEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency / unavailable'**
  String get pbdReasonEmergency;

  /// No description provided for @pbdReasonSick.
  ///
  /// In en, this message translates to:
  /// **'Staff called in sick'**
  String get pbdReasonSick;

  /// No description provided for @pbdReasonOverbooked.
  ///
  /// In en, this message translates to:
  /// **'Overbooked by mistake'**
  String get pbdReasonOverbooked;

  /// No description provided for @pbdReasonUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Customer unreachable'**
  String get pbdReasonUnreachable;

  /// No description provided for @pbdCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Cancel + accept penalty'**
  String get pbdCancelConfirm;

  /// No description provided for @pbdCancelledToast.
  ///
  /// In en, this message translates to:
  /// **'Booking cancelled. Penalty applied to your ledger.'**
  String get pbdCancelledToast;

  /// No description provided for @pbdNoShow.
  ///
  /// In en, this message translates to:
  /// **'Customer didn\'t show'**
  String get pbdNoShow;

  /// No description provided for @pbdNoShowTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark this booking as a no-show?'**
  String get pbdNoShowTitle;

  /// No description provided for @pbdNoShowBody.
  ///
  /// In en, this message translates to:
  /// **'Use this only if the customer never came and you couldn\'t reach them. It closes the booking without a strike for you and is recorded against the customer.'**
  String get pbdNoShowBody;

  /// No description provided for @pbdNoShowToast.
  ///
  /// In en, this message translates to:
  /// **'Marked as a no-show.'**
  String get pbdNoShowToast;

  /// No description provided for @pbdEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Booking request'**
  String get pbdEyebrow;

  /// No description provided for @pbdTitle.
  ///
  /// In en, this message translates to:
  /// **'Review & respond'**
  String get pbdTitle;

  /// No description provided for @pbdPriorBookings.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 prior booking} other{{count} prior bookings}}'**
  String pbdPriorBookings(int count);

  /// No description provided for @pbdHomeAddress.
  ///
  /// In en, this message translates to:
  /// **'HOME SERVICE ADDRESS'**
  String get pbdHomeAddress;

  /// No description provided for @pbdNoAddress.
  ///
  /// In en, this message translates to:
  /// **'No address attached'**
  String get pbdNoAddress;

  /// No description provided for @pbdNoAddressBody.
  ///
  /// In en, this message translates to:
  /// **'This home-service request has no address, so there\'s nothing to price a travel fee against. You can still accept or decline normally.'**
  String get pbdNoAddressBody;

  /// No description provided for @pbdQuoteSent.
  ///
  /// In en, this message translates to:
  /// **'Travel fee quote sent · {amount}'**
  String pbdQuoteSent(String amount);

  /// No description provided for @pbdQuoteSentBody.
  ///
  /// In en, this message translates to:
  /// **'Waiting on the customer to accept or decline. If they accept, this booking confirms automatically — no extra tap needed from you.'**
  String get pbdQuoteSentBody;

  /// No description provided for @pbdFeeAccepted.
  ///
  /// In en, this message translates to:
  /// **'Travel fee accepted'**
  String get pbdFeeAccepted;

  /// No description provided for @pbdFeeAcceptedBody.
  ///
  /// In en, this message translates to:
  /// **'Locked in and added to the total. The travel fee is pass-through to you — AIWA doesn\'t take commission on it.'**
  String get pbdFeeAcceptedBody;

  /// No description provided for @pbdCustomerNote.
  ///
  /// In en, this message translates to:
  /// **'Customer note'**
  String get pbdCustomerNote;

  /// No description provided for @pbdQuoteInstead.
  ///
  /// In en, this message translates to:
  /// **'Quote a travel fee instead'**
  String get pbdQuoteInstead;

  /// No description provided for @pbdProposeInstead.
  ///
  /// In en, this message translates to:
  /// **'Propose a different time instead'**
  String get pbdProposeInstead;

  /// No description provided for @pbdOnMyWay.
  ///
  /// In en, this message translates to:
  /// **'On my way'**
  String get pbdOnMyWay;

  /// No description provided for @pbdOnMyWayNote.
  ///
  /// In en, this message translates to:
  /// **'Customer gets a push + live tracking starts.'**
  String get pbdOnMyWayNote;

  /// No description provided for @pbdArrived.
  ///
  /// In en, this message translates to:
  /// **'I\'ve arrived'**
  String get pbdArrived;

  /// No description provided for @pbdArrivedNote.
  ///
  /// In en, this message translates to:
  /// **'Customer is told you are at the door.'**
  String get pbdArrivedNote;

  /// No description provided for @pbdStartService.
  ///
  /// In en, this message translates to:
  /// **'Start service'**
  String get pbdStartService;

  /// No description provided for @pbdStartNote.
  ///
  /// In en, this message translates to:
  /// **'Timer starts. Safety check-in stays on.'**
  String get pbdStartNote;

  /// No description provided for @pbdStartVenueNote.
  ///
  /// In en, this message translates to:
  /// **'Tap once the customer has arrived at your venue.'**
  String get pbdStartVenueNote;

  /// No description provided for @pbdFinishNote.
  ///
  /// In en, this message translates to:
  /// **'Finish the job, then confirm the cash you received.'**
  String get pbdFinishNote;

  /// No description provided for @pbdMarkCompleted.
  ///
  /// In en, this message translates to:
  /// **'Mark completed'**
  String get pbdMarkCompleted;

  /// No description provided for @pbdJobProgress.
  ///
  /// In en, this message translates to:
  /// **'Job progress'**
  String get pbdJobProgress;

  /// No description provided for @pbdDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get pbdDuration;

  /// No description provided for @pbdRequested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get pbdRequested;

  /// No description provided for @pbdServicePrice.
  ///
  /// In en, this message translates to:
  /// **'Service price'**
  String get pbdServicePrice;

  /// No description provided for @pbdTravelFeePending.
  ///
  /// In en, this message translates to:
  /// **'Travel fee (pending)'**
  String get pbdTravelFeePending;

  /// No description provided for @pbdTravelFee.
  ///
  /// In en, this message translates to:
  /// **'Travel fee'**
  String get pbdTravelFee;

  /// No description provided for @pbdQuoteEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Quote a travel fee'**
  String get pbdQuoteEyebrow;

  /// No description provided for @pbdQuoteTitle.
  ///
  /// In en, this message translates to:
  /// **'How much to reach {name}\'s address?'**
  String pbdQuoteTitle(String name);

  /// No description provided for @pbdQuotePassThrough.
  ///
  /// In en, this message translates to:
  /// **'This is pass-through — AIWA doesn\'t take commission on the travel fee, only the {amount} service price.'**
  String pbdQuotePassThrough(String amount);

  /// No description provided for @currencyEgp.
  ///
  /// In en, this message translates to:
  /// **'EGP'**
  String get currencyEgp;

  /// No description provided for @pbdSendQuote.
  ///
  /// In en, this message translates to:
  /// **'Send quote'**
  String get pbdSendQuote;

  /// No description provided for @svcEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Your menu'**
  String get svcEyebrow;

  /// No description provided for @svcNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get svcNew;

  /// No description provided for @svcEmpty.
  ///
  /// In en, this message translates to:
  /// **'No services yet'**
  String get svcEmpty;

  /// No description provided for @svcEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add what you offer so customers can book it.'**
  String get svcEmptyBody;

  /// No description provided for @svcStartsAt.
  ///
  /// In en, this message translates to:
  /// **'Starts at'**
  String get svcStartsAt;

  /// No description provided for @svcFixedPrice.
  ///
  /// In en, this message translates to:
  /// **'Fixed price'**
  String get svcFixedPrice;

  /// No description provided for @svcHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get svcHidden;

  /// No description provided for @svcNewService.
  ///
  /// In en, this message translates to:
  /// **'New service'**
  String get svcNewService;

  /// No description provided for @svcEditService.
  ///
  /// In en, this message translates to:
  /// **'Edit service'**
  String get svcEditService;

  /// No description provided for @svcName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get svcName;

  /// No description provided for @svcPrice.
  ///
  /// In en, this message translates to:
  /// **'Price (EGP)'**
  String get svcPrice;

  /// No description provided for @svcDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration (min)'**
  String get svcDuration;

  /// No description provided for @svcHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get svcHide;

  /// No description provided for @svcHiddenToast.
  ///
  /// In en, this message translates to:
  /// **'Service hidden.'**
  String get svcHiddenToast;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @svcSavedToast.
  ///
  /// In en, this message translates to:
  /// **'Service saved.'**
  String get svcSavedToast;

  /// No description provided for @schedEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Weekly availability'**
  String get schedEyebrow;

  /// No description provided for @schedTip.
  ///
  /// In en, this message translates to:
  /// **'{tip} Tap any day to add multiple time blocks, breaks, or one-off availability changes.'**
  String schedTip(String tip);

  /// No description provided for @schedTipLabel.
  ///
  /// In en, this message translates to:
  /// **'Tip:'**
  String get schedTipLabel;

  /// No description provided for @schedClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get schedClosed;

  /// No description provided for @schedDecrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease buffer'**
  String get schedDecrease;

  /// No description provided for @schedIncrease.
  ///
  /// In en, this message translates to:
  /// **'Increase buffer'**
  String get schedIncrease;

  /// No description provided for @schedBufferTitle.
  ///
  /// In en, this message translates to:
  /// **'Travel buffer between bookings'**
  String get schedBufferTitle;

  /// No description provided for @schedBufferBody.
  ///
  /// In en, this message translates to:
  /// **'Blocks slots too close together for home visits.'**
  String get schedBufferBody;

  /// No description provided for @staffNameSchedule.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s schedule'**
  String staffNameSchedule(String name);

  /// No description provided for @staffShopPlan.
  ///
  /// In en, this message translates to:
  /// **'Shop plan'**
  String get staffShopPlan;

  /// No description provided for @staffTitle.
  ///
  /// In en, this message translates to:
  /// **'Staff & availability'**
  String get staffTitle;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @staffEmpty.
  ///
  /// In en, this message translates to:
  /// **'No staff yet'**
  String get staffEmpty;

  /// No description provided for @staffEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add the people who take bookings at your shop.'**
  String get staffEmptyBody;

  /// No description provided for @staffSkills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get staffSkills;

  /// No description provided for @staffOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get staffOff;

  /// No description provided for @staffEditSchedule.
  ///
  /// In en, this message translates to:
  /// **'Edit {name}\'s schedule'**
  String staffEditSchedule(String name);

  /// No description provided for @staffAdded.
  ///
  /// In en, this message translates to:
  /// **'Staff member added.'**
  String get staffAdded;

  /// No description provided for @staffRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get staffRole;

  /// No description provided for @staffSkillsHint.
  ///
  /// In en, this message translates to:
  /// **'Separate with commas.'**
  String get staffSkillsHint;

  /// No description provided for @walletEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Commission & settlement'**
  String get walletEyebrow;

  /// No description provided for @walletSettleTitle.
  ///
  /// In en, this message translates to:
  /// **'Report paying {amount}?'**
  String walletSettleTitle(String amount);

  /// No description provided for @walletSettleBalance.
  ///
  /// In en, this message translates to:
  /// **'I\'ve paid'**
  String get walletSettleBalance;

  /// No description provided for @walletSettled.
  ///
  /// In en, this message translates to:
  /// **'Payment reported. AIWA finance will confirm it shortly.'**
  String get walletSettled;

  /// No description provided for @walletPaymentReported.
  ///
  /// In en, this message translates to:
  /// **'Payment reported — waiting for AIWA finance to confirm.'**
  String get walletPaymentReported;

  /// No description provided for @walletTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get walletTitle;

  /// No description provided for @walletOwed.
  ///
  /// In en, this message translates to:
  /// **'Wallet balance owed to AIWA'**
  String get walletOwed;

  /// No description provided for @walletLimit.
  ///
  /// In en, this message translates to:
  /// **'Negative limit {amount} — settle weekly to keep taking bookings.'**
  String walletLimit(String amount);

  /// No description provided for @walletBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked from new bookings'**
  String get walletBlocked;

  /// No description provided for @walletBlockedBody.
  ///
  /// In en, this message translates to:
  /// **'You can still finish any job you\'ve already accepted — completing those and settling this balance lifts the block once finance confirms your payment.'**
  String get walletBlockedBody;

  /// No description provided for @walletNextSettlement.
  ///
  /// In en, this message translates to:
  /// **'Next settlement'**
  String get walletNextSettlement;

  /// No description provided for @walletStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get walletStatus;

  /// No description provided for @walletLedger.
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get walletLedger;

  /// No description provided for @walletNoCommission.
  ///
  /// In en, this message translates to:
  /// **'No commission yet'**
  String get walletNoCommission;

  /// No description provided for @walletNoCommissionBody.
  ///
  /// In en, this message translates to:
  /// **'Completed bookings show up here.'**
  String get walletNoCommissionBody;

  /// No description provided for @walletSettleNow.
  ///
  /// In en, this message translates to:
  /// **'I\'ve paid this balance'**
  String get walletSettleNow;

  /// No description provided for @walletCommission.
  ///
  /// In en, this message translates to:
  /// **'Commission'**
  String get walletCommission;

  /// No description provided for @walletCommissionBooking.
  ///
  /// In en, this message translates to:
  /// **'Commission · Booking #{id}'**
  String walletCommissionBooking(String id);

  /// No description provided for @walletSettledTag.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get walletSettledTag;

  /// No description provided for @walletOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get walletOverdue;

  /// No description provided for @revFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get revFilterAll;

  /// No description provided for @revFilterNeedsReply.
  ///
  /// In en, this message translates to:
  /// **'Needs reply'**
  String get revFilterNeedsReply;

  /// No description provided for @revFilterStars.
  ///
  /// In en, this message translates to:
  /// **'{n} star'**
  String revFilterStars(int n);

  /// No description provided for @revEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get revEyebrow;

  /// No description provided for @revTitle.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get revTitle;

  /// No description provided for @revEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Reviews from completed bookings show up here.'**
  String get revEmptyBody;

  /// No description provided for @revNothingHere.
  ///
  /// In en, this message translates to:
  /// **'Nothing here'**
  String get revNothingHere;

  /// No description provided for @revNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No reviews match this filter.'**
  String get revNoMatch;

  /// No description provided for @revTotal.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 review total} other{{count} reviews total}}'**
  String revTotal(int count);

  /// No description provided for @revCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 review} other{{count} reviews}}'**
  String revCount(int count);

  /// No description provided for @revYourReply.
  ///
  /// In en, this message translates to:
  /// **'YOUR REPLY'**
  String get revYourReply;

  /// No description provided for @revReplyPublicly.
  ///
  /// In en, this message translates to:
  /// **'Reply publicly'**
  String get revReplyPublicly;

  /// No description provided for @revReplyHint.
  ///
  /// In en, this message translates to:
  /// **'Thank them, or explain what happened…'**
  String get revReplyHint;

  /// No description provided for @revPostReply.
  ///
  /// In en, this message translates to:
  /// **'Post reply'**
  String get revPostReply;

  /// No description provided for @galEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get galEyebrow;

  /// No description provided for @galDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this photo?'**
  String get galDeleteTitle;

  /// No description provided for @galDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'It\'s removed from your public profile straight away. This can\'t be undone.'**
  String get galDeleteBody;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @galIntro.
  ///
  /// In en, this message translates to:
  /// **'Your best work, shown on your public profile. Drag to reorder — the first photo is your cover.'**
  String get galIntro;

  /// No description provided for @galEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Profiles with photos get noticeably more bookings. Add a few examples of your work.'**
  String get galEmptyBody;

  /// No description provided for @galUploadFirst.
  ///
  /// In en, this message translates to:
  /// **'Upload first photo'**
  String get galUploadFirst;

  /// No description provided for @galOneHidden.
  ///
  /// In en, this message translates to:
  /// **'One photo is hidden'**
  String get galOneHidden;

  /// No description provided for @galOneHiddenBody.
  ///
  /// In en, this message translates to:
  /// **'Our team hid a photo that didn\'t match your services. Replace it or contact support if you disagree.'**
  String get galOneHiddenBody;

  /// No description provided for @galUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading photo…'**
  String get galUploading;

  /// No description provided for @galCancelUpload.
  ///
  /// In en, this message translates to:
  /// **'Cancel upload'**
  String get galCancelUpload;

  /// No description provided for @galHiddenByMod.
  ///
  /// In en, this message translates to:
  /// **'Hidden by moderation'**
  String get galHiddenByMod;

  /// No description provided for @galCover.
  ///
  /// In en, this message translates to:
  /// **'COVER'**
  String get galCover;

  /// No description provided for @galDeletePhoto.
  ///
  /// In en, this message translates to:
  /// **'Delete photo'**
  String get galDeletePhoto;

  /// No description provided for @ppAccount.
  ///
  /// In en, this message translates to:
  /// **'Provider account'**
  String get ppAccount;

  /// No description provided for @ppSignOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out of AIWA?'**
  String get ppSignOutTitle;

  /// No description provided for @ppSignOutBody.
  ///
  /// In en, this message translates to:
  /// **'Your bookings stay exactly as they are. You\'ll need your number and a code to sign back in.'**
  String get ppSignOutBody;

  /// No description provided for @commonSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get commonSignOut;

  /// No description provided for @commonSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out.'**
  String get commonSignedOut;

  /// No description provided for @ppVacation.
  ///
  /// In en, this message translates to:
  /// **'Vacation / offline mode'**
  String get ppVacation;

  /// No description provided for @ppVacationOn.
  ///
  /// In en, this message translates to:
  /// **'You\'re hidden from search.'**
  String get ppVacationOn;

  /// No description provided for @ppVacationOff.
  ///
  /// In en, this message translates to:
  /// **'Pause new bookings temporarily.'**
  String get ppVacationOff;

  /// No description provided for @ppVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified provider'**
  String get ppVerified;

  /// No description provided for @ppApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved by AIWA.'**
  String get ppApproved;

  /// No description provided for @ppApprovedOn.
  ///
  /// In en, this message translates to:
  /// **'Approved by AIWA on {date}.'**
  String ppApprovedOn(String date);

  /// No description provided for @ppBusinessInfo.
  ///
  /// In en, this message translates to:
  /// **'Business info'**
  String get ppBusinessInfo;

  /// No description provided for @ppPhotos.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo} other{{count} photos}}'**
  String ppPhotos(int count);

  /// No description provided for @ppWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet & settlement'**
  String get ppWallet;

  /// No description provided for @ppNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get ppNotifications;

  /// No description provided for @ppSafety.
  ///
  /// In en, this message translates to:
  /// **'Safety & policies'**
  String get ppSafety;

  /// No description provided for @ppWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp support'**
  String get ppWhatsApp;

  /// No description provided for @biNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Business name is required.'**
  String get biNameRequired;

  /// No description provided for @biAddressRequired.
  ///
  /// In en, this message translates to:
  /// **'Add the area so customers can find you.'**
  String get biAddressRequired;

  /// No description provided for @biSaved.
  ///
  /// In en, this message translates to:
  /// **'Business info saved.'**
  String get biSaved;

  /// No description provided for @biBioHint.
  ///
  /// In en, this message translates to:
  /// **'Shown at the top of your public profile.'**
  String get biBioHint;

  /// No description provided for @biBaseAddress.
  ///
  /// In en, this message translates to:
  /// **'Base address'**
  String get biBaseAddress;

  /// No description provided for @biServiceRadius.
  ///
  /// In en, this message translates to:
  /// **'Service radius'**
  String get biServiceRadius;

  /// No description provided for @biSurcharge.
  ///
  /// In en, this message translates to:
  /// **'Home-visit surcharge (EGP)'**
  String get biSurcharge;

  /// No description provided for @biSurchargeHint.
  ///
  /// In en, this message translates to:
  /// **'Added on top of the service price for bookings at the customer\'s address.'**
  String get biSurchargeHint;

  /// No description provided for @biVerifiedStudio.
  ///
  /// In en, this message translates to:
  /// **'Verified studio'**
  String get biVerifiedStudio;

  /// No description provided for @biReReview.
  ///
  /// In en, this message translates to:
  /// **'Changing your business name or address sends your profile for a quick re-review.'**
  String get biReReview;

  /// No description provided for @commonSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get commonSaveChanges;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get tabDiscover;

  /// No description provided for @tabSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get tabSaved;

  /// No description provided for @profGuestTitle.
  ///
  /// In en, this message translates to:
  /// **'Your profile'**
  String get profGuestTitle;

  /// No description provided for @profGuestBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in to manage your account, addresses, and notifications.'**
  String get profGuestBody;

  /// No description provided for @profPersonalInfo.
  ///
  /// In en, this message translates to:
  /// **'Personal info'**
  String get profPersonalInfo;

  /// No description provided for @profSavedAddresses.
  ///
  /// In en, this message translates to:
  /// **'Saved addresses'**
  String get profSavedAddresses;

  /// No description provided for @profTrustedContacts.
  ///
  /// In en, this message translates to:
  /// **'Trusted contacts'**
  String get profTrustedContacts;

  /// No description provided for @profTrustedSaved.
  ///
  /// In en, this message translates to:
  /// **'{count} saved'**
  String profTrustedSaved(int count);

  /// No description provided for @profNotificationPrefs.
  ///
  /// In en, this message translates to:
  /// **'Notification preferences'**
  String get profNotificationPrefs;

  /// No description provided for @profLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profLanguage;

  /// No description provided for @profDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get profDeleteAccount;

  /// No description provided for @profYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Your account'**
  String get profYourAccount;

  /// No description provided for @profSignOutBody.
  ///
  /// In en, this message translates to:
  /// **'Your bookings, saved providers and addresses all stay safe. You\'ll need a code to sign back in.'**
  String get profSignOutBody;

  /// No description provided for @profAccountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted. Sorry to see you go.'**
  String get profAccountDeleted;

  /// No description provided for @profStatBookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get profStatBookings;

  /// No description provided for @profStatFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get profStatFavorites;

  /// No description provided for @profStatReviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get profStatReviews;

  /// No description provided for @editNameError.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name.'**
  String get editNameError;

  /// No description provided for @editPhoneError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Egyptian mobile number.'**
  String get editPhoneError;

  /// No description provided for @editEmailError.
  ///
  /// In en, this message translates to:
  /// **'That email doesn’t look right.'**
  String get editEmailError;

  /// No description provided for @editProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated.'**
  String get editProfileUpdated;

  /// No description provided for @editConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm it\'s you'**
  String get editConfirmTitle;

  /// No description provided for @editConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your current password to continue.'**
  String get editConfirmBody;

  /// No description provided for @editCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get editCurrentPassword;

  /// No description provided for @editEmailCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your new email'**
  String get editEmailCodeTitle;

  /// No description provided for @editEmailConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Email confirmed.'**
  String get editEmailConfirmed;

  /// No description provided for @editEmailResend.
  ///
  /// In en, this message translates to:
  /// **'Send the code again'**
  String get editEmailResend;

  /// No description provided for @editEmailPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for you to confirm {email}.'**
  String editEmailPending(String email);

  /// No description provided for @editAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get editAccount;

  /// No description provided for @editChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get editChangePhoto;

  /// No description provided for @editPhotoHint.
  ///
  /// In en, this message translates to:
  /// **'JPG or PNG · max 5 MB'**
  String get editPhotoHint;

  /// No description provided for @editYourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get editYourName;

  /// No description provided for @editMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get editMobile;

  /// No description provided for @editMobileHint.
  ///
  /// In en, this message translates to:
  /// **'Changing this sends a verification code to the new number.'**
  String get editMobileHint;

  /// No description provided for @editTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get editTheme;

  /// No description provided for @editThemeMauve.
  ///
  /// In en, this message translates to:
  /// **'Mauve'**
  String get editThemeMauve;

  /// No description provided for @editThemeCharcoal.
  ///
  /// In en, this message translates to:
  /// **'Charcoal'**
  String get editThemeCharcoal;

  /// No description provided for @editSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get editSaving;

  /// No description provided for @addrHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get addrHome;

  /// No description provided for @addrWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get addrWork;

  /// No description provided for @addrOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get addrOther;

  /// No description provided for @addrEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved addresses'**
  String get addrEmpty;

  /// No description provided for @addrEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add your home or work so booking a home visit takes one tap.'**
  String get addrEmptyBody;

  /// No description provided for @addrStreetError.
  ///
  /// In en, this message translates to:
  /// **'Add the street and area so your provider can find you.'**
  String get addrStreetError;

  /// No description provided for @addrBuildingError.
  ///
  /// In en, this message translates to:
  /// **'Building number or name is required.'**
  String get addrBuildingError;

  /// No description provided for @addrFloorN.
  ///
  /// In en, this message translates to:
  /// **'Floor {n}'**
  String addrFloorN(String n);

  /// No description provided for @addrAptN.
  ///
  /// In en, this message translates to:
  /// **'Apt {n}'**
  String addrAptN(String n);

  /// No description provided for @addrUpdated.
  ///
  /// In en, this message translates to:
  /// **'Address updated.'**
  String get addrUpdated;

  /// No description provided for @addrAdded.
  ///
  /// In en, this message translates to:
  /// **'Address added.'**
  String get addrAdded;

  /// No description provided for @addrRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove address'**
  String get addrRemove;

  /// No description provided for @addrDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{label}\"?'**
  String addrDeleteTitle(String label);

  /// No description provided for @addrDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Bookings already made to this address keep their details. You can add it again any time.'**
  String get addrDeleteBody;

  /// No description provided for @addrDeleted.
  ///
  /// In en, this message translates to:
  /// **'Address deleted.'**
  String get addrDeleted;

  /// No description provided for @addrEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit address'**
  String get addrEditTitle;

  /// No description provided for @addrNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New address'**
  String get addrNewTitle;

  /// No description provided for @addrLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get addrLabel;

  /// No description provided for @addrStreet.
  ///
  /// In en, this message translates to:
  /// **'Street & area'**
  String get addrStreet;

  /// No description provided for @addrStreetPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. Road 9, Maadi'**
  String get addrStreetPlaceholder;

  /// No description provided for @addrBuilding.
  ///
  /// In en, this message translates to:
  /// **'Building'**
  String get addrBuilding;

  /// No description provided for @addrFloor.
  ///
  /// In en, this message translates to:
  /// **'Floor'**
  String get addrFloor;

  /// No description provided for @addrApt.
  ///
  /// In en, this message translates to:
  /// **'Apt'**
  String get addrApt;

  /// No description provided for @addrLandmark.
  ///
  /// In en, this message translates to:
  /// **'Nearest landmark'**
  String get addrLandmark;

  /// No description provided for @addrLandmarkPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. opposite Sakia'**
  String get addrLandmarkPlaceholder;

  /// No description provided for @addrLandmarkHint.
  ///
  /// In en, this message translates to:
  /// **'Helps providers find you faster on the first visit.'**
  String get addrLandmarkHint;

  /// No description provided for @addrNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes for the provider'**
  String get addrNotes;

  /// No description provided for @addrNotesPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Gate code, parking, which bell to ring…'**
  String get addrNotesPlaceholder;

  /// No description provided for @addrDefault.
  ///
  /// In en, this message translates to:
  /// **'Default address'**
  String get addrDefault;

  /// No description provided for @addrDefaultSub.
  ///
  /// In en, this message translates to:
  /// **'Pre-selected on every home booking'**
  String get addrDefaultSub;

  /// No description provided for @addrDeleteThis.
  ///
  /// In en, this message translates to:
  /// **'Delete this address'**
  String get addrDeleteThis;

  /// No description provided for @addrSave.
  ///
  /// In en, this message translates to:
  /// **'Save address'**
  String get addrSave;

  /// No description provided for @addrAdd.
  ///
  /// In en, this message translates to:
  /// **'Add address'**
  String get addrAdd;

  /// No description provided for @addrPinDropped.
  ///
  /// In en, this message translates to:
  /// **'Pin dropped'**
  String get addrPinDropped;

  /// No description provided for @addrDropPin.
  ///
  /// In en, this message translates to:
  /// **'Drop pin'**
  String get addrDropPin;

  /// No description provided for @tcContactDefault.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get tcContactDefault;

  /// No description provided for @tcSafety.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get tcSafety;

  /// No description provided for @tcRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this contact?'**
  String get tcRemoveTitle;

  /// No description provided for @tcRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'They\'ll no longer be alerted if you press SOS during a home service.'**
  String get tcRemoveBody;

  /// No description provided for @tcRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get tcRemove;

  /// No description provided for @tcBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Alerted the moment you press SOS'**
  String get tcBannerTitle;

  /// No description provided for @tcBannerBody.
  ///
  /// In en, this message translates to:
  /// **'They receive your live location by SMS. Nothing is shared with them at any other time.'**
  String get tcBannerBody;

  /// No description provided for @tcEmpty.
  ///
  /// In en, this message translates to:
  /// **'No trusted contact yet'**
  String get tcEmpty;

  /// No description provided for @tcEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add someone you\'d want alerted if you ever felt unsafe during a home service.'**
  String get tcEmptyBody;

  /// No description provided for @tcAddContact.
  ///
  /// In en, this message translates to:
  /// **'Add a contact'**
  String get tcAddContact;

  /// No description provided for @tcNew.
  ///
  /// In en, this message translates to:
  /// **'New trusted contact'**
  String get tcNew;

  /// No description provided for @tcNameError.
  ///
  /// In en, this message translates to:
  /// **'Enter their name.'**
  String get tcNameError;

  /// No description provided for @tcNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Their full name'**
  String get tcNamePlaceholder;

  /// No description provided for @tcPhoneError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid mobile number.'**
  String get tcPhoneError;

  /// No description provided for @tcRelationship.
  ///
  /// In en, this message translates to:
  /// **'Relationship'**
  String get tcRelationship;

  /// No description provided for @tcRelationshipPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Sister, friend, partner…'**
  String get tcRelationshipPlaceholder;

  /// No description provided for @tcAdd.
  ///
  /// In en, this message translates to:
  /// **'Add contact'**
  String get tcAdd;

  /// No description provided for @tcAddAnother.
  ///
  /// In en, this message translates to:
  /// **'Add another contact'**
  String get tcAddAnother;

  /// No description provided for @supOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening WhatsApp…'**
  String get supOpening;

  /// No description provided for @supNumber.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp number'**
  String get supNumber;

  /// No description provided for @supHours.
  ///
  /// In en, this message translates to:
  /// **'Support hours'**
  String get supHours;

  /// No description provided for @supEmail.
  ///
  /// In en, this message translates to:
  /// **'Email fallback'**
  String get supEmail;

  /// No description provided for @supLanguages.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get supLanguages;

  /// No description provided for @supEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get supEyebrow;

  /// No description provided for @supTitle.
  ///
  /// In en, this message translates to:
  /// **'Talk to AIWA'**
  String get supTitle;

  /// No description provided for @supHero.
  ///
  /// In en, this message translates to:
  /// **'Chat with a human on WhatsApp.'**
  String get supHero;

  /// No description provided for @supHeroBody.
  ///
  /// In en, this message translates to:
  /// **'We answer in Arabic or English, usually within a few minutes during support hours.'**
  String get supHeroBody;

  /// No description provided for @supOpenWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Open WhatsApp'**
  String get supOpenWhatsApp;

  /// No description provided for @supCommonQuestions.
  ///
  /// In en, this message translates to:
  /// **'Common questions'**
  String get supCommonQuestions;

  /// No description provided for @supQCancel.
  ///
  /// In en, this message translates to:
  /// **'How do I cancel a booking?'**
  String get supQCancel;

  /// No description provided for @supQPaid.
  ///
  /// In en, this message translates to:
  /// **'When does the provider get paid?'**
  String get supQPaid;

  /// No description provided for @supQNoShow.
  ///
  /// In en, this message translates to:
  /// **'My provider didn\'t show up'**
  String get supQNoShow;

  /// No description provided for @supQBecome.
  ///
  /// In en, this message translates to:
  /// **'How do I become a provider?'**
  String get supQBecome;

  /// No description provided for @polTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of service'**
  String get polTerms;

  /// No description provided for @polSafety.
  ///
  /// In en, this message translates to:
  /// **'Safety policy'**
  String get polSafety;

  /// No description provided for @polSafetySub.
  ///
  /// In en, this message translates to:
  /// **'Home visits, ID checks, SOS'**
  String get polSafetySub;

  /// No description provided for @polCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancellation policy'**
  String get polCancel;

  /// No description provided for @polCancelSub.
  ///
  /// In en, this message translates to:
  /// **'Cutoffs, penalties, no-shows'**
  String get polCancelSub;

  /// No description provided for @polPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get polPrivacy;

  /// No description provided for @polPrivacySub.
  ///
  /// In en, this message translates to:
  /// **'What we store and for how long'**
  String get polPrivacySub;

  /// No description provided for @polConduct.
  ///
  /// In en, this message translates to:
  /// **'Community conduct'**
  String get polConduct;

  /// No description provided for @polConductSub.
  ///
  /// In en, this message translates to:
  /// **'What we expect from everyone'**
  String get polConductSub;

  /// No description provided for @polUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You\'re up to date'**
  String get polUpToDate;

  /// No description provided for @polUpToDateBody.
  ///
  /// In en, this message translates to:
  /// **'You accepted the current terms (v{version}). We\'ll tell you if anything changes.'**
  String polUpToDateBody(Object version);

  /// No description provided for @polUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated terms to review'**
  String get polUpdated;

  /// No description provided for @polReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get polReview;

  /// No description provided for @polAccepted.
  ///
  /// In en, this message translates to:
  /// **'v{version} · accepted'**
  String polAccepted(Object version);

  /// No description provided for @polNotAccepted.
  ///
  /// In en, this message translates to:
  /// **'Not accepted yet'**
  String get polNotAccepted;

  /// No description provided for @polPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'This is the full text of the {doc}, shown in the customer\'s language. It stays readable offline and records which version you accepted, so we only ask you again when something material changes.'**
  String polPlaceholder(String doc);

  /// No description provided for @polSafetyTools.
  ///
  /// In en, this message translates to:
  /// **'Your safety tools'**
  String get polSafetyTools;

  /// No description provided for @polTrustedSub.
  ///
  /// In en, this message translates to:
  /// **'Alerted if you press SOS'**
  String get polTrustedSub;

  /// No description provided for @polHowSos.
  ///
  /// In en, this message translates to:
  /// **'How SOS works'**
  String get polHowSos;

  /// No description provided for @polHowSosSub.
  ///
  /// In en, this message translates to:
  /// **'What happens when you press it'**
  String get polHowSosSub;

  /// No description provided for @polDownloadPdf.
  ///
  /// In en, this message translates to:
  /// **'Download PDF'**
  String get polDownloadPdf;

  /// No description provided for @notifInbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get notifInbox;

  /// No description provided for @notifNewSuffix.
  ///
  /// In en, this message translates to:
  /// **'· {count} new'**
  String notifNewSuffix(int count);

  /// No description provided for @notifMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notifMarkAllRead;

  /// No description provided for @notifCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up'**
  String get notifCaughtUp;

  /// No description provided for @notifCaughtUpBody.
  ///
  /// In en, this message translates to:
  /// **'Booking updates, reviews and news from AIWA will show up here.'**
  String get notifCaughtUpBody;

  /// No description provided for @notifEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get notifEarlier;

  /// No description provided for @notifJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get notifJustNow;

  /// No description provided for @notifMinAgo.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, other{{n} min ago}}'**
  String notifMinAgo(int n);

  /// No description provided for @notifHrAgo.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, other{{n} hr ago}}'**
  String notifHrAgo(int n);

  /// No description provided for @npPush.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get npPush;

  /// No description provided for @npSms.
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get npSms;

  /// No description provided for @npChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get npChannels;

  /// No description provided for @npQuietHours.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours'**
  String get npQuietHours;

  /// No description provided for @npMute.
  ///
  /// In en, this message translates to:
  /// **'Mute non-urgent notifications'**
  String get npMute;

  /// No description provided for @npFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get npFrom;

  /// No description provided for @npTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get npTo;

  /// No description provided for @tagPunctual.
  ///
  /// In en, this message translates to:
  /// **'Punctual'**
  String get tagPunctual;

  /// No description provided for @tagSkilled.
  ///
  /// In en, this message translates to:
  /// **'Skilled'**
  String get tagSkilled;

  /// No description provided for @tagFriendly.
  ///
  /// In en, this message translates to:
  /// **'Friendly'**
  String get tagFriendly;

  /// No description provided for @tagCleanStudio.
  ///
  /// In en, this message translates to:
  /// **'Clean studio'**
  String get tagCleanStudio;

  /// No description provided for @tagWorthPrice.
  ///
  /// In en, this message translates to:
  /// **'Worth the price'**
  String get tagWorthPrice;

  /// No description provided for @tagGreatHair.
  ///
  /// In en, this message translates to:
  /// **'Great with hair'**
  String get tagGreatHair;

  /// No description provided for @reviewTapStar.
  ///
  /// In en, this message translates to:
  /// **'Tap a star'**
  String get reviewTapStar;

  /// No description provided for @reviewDisappointing.
  ///
  /// In en, this message translates to:
  /// **'Disappointing'**
  String get reviewDisappointing;

  /// No description provided for @reviewBelow.
  ///
  /// In en, this message translates to:
  /// **'Below expectations'**
  String get reviewBelow;

  /// No description provided for @reviewGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get reviewGood;

  /// No description provided for @reviewGreat.
  ///
  /// In en, this message translates to:
  /// **'Great'**
  String get reviewGreat;

  /// No description provided for @reviewOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get reviewOutstanding;

  /// No description provided for @reviewThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks — your review is live.'**
  String get reviewThanks;

  /// No description provided for @reviewEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Leave a review'**
  String get reviewEyebrow;

  /// No description provided for @reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'How was it?'**
  String get reviewTitle;

  /// No description provided for @reviewQuickTags.
  ///
  /// In en, this message translates to:
  /// **'Quick tags (optional)'**
  String get reviewQuickTags;

  /// No description provided for @reviewStoodOut.
  ///
  /// In en, this message translates to:
  /// **'Tell others what stood out'**
  String get reviewStoodOut;

  /// No description provided for @reviewHint.
  ///
  /// In en, this message translates to:
  /// **'Optional — your review will be public on the provider\'s profile.'**
  String get reviewHint;

  /// No description provided for @reviewSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit review'**
  String get reviewSubmit;

  /// No description provided for @savedGuestTitle.
  ///
  /// In en, this message translates to:
  /// **'Save your favorites'**
  String get savedGuestTitle;

  /// No description provided for @savedGuestBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in to save providers you love and book them faster next time.'**
  String get savedGuestBody;

  /// No description provided for @savedEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Your favorites'**
  String get savedEyebrow;

  /// No description provided for @savedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get savedEmpty;

  /// No description provided for @savedEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart on any provider to save them here and book again in one tap.'**
  String get savedEmptyBody;

  /// No description provided for @savedBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse providers'**
  String get savedBrowse;

  /// No description provided for @savedBookAgain.
  ///
  /// In en, this message translates to:
  /// **'Book again'**
  String get savedBookAgain;

  /// No description provided for @permLocEyebrow.
  ///
  /// In en, this message translates to:
  /// **'One quick permission'**
  String get permLocEyebrow;

  /// No description provided for @permLocTitle.
  ///
  /// In en, this message translates to:
  /// **'Find beauty pros near you.'**
  String get permLocTitle;

  /// No description provided for @permLocBody.
  ///
  /// In en, this message translates to:
  /// **'AIWA uses your location to show providers within your chosen radius and to share live arrival updates during a home visit.'**
  String get permLocBody;

  /// No description provided for @permLocP1.
  ///
  /// In en, this message translates to:
  /// **'Only used while the app is open'**
  String get permLocP1;

  /// No description provided for @permLocP2.
  ///
  /// In en, this message translates to:
  /// **'Never shared with other customers'**
  String get permLocP2;

  /// No description provided for @permLocP3.
  ///
  /// In en, this message translates to:
  /// **'You can pick an area manually instead'**
  String get permLocP3;

  /// No description provided for @permLocAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow location'**
  String get permLocAllow;

  /// No description provided for @permLocDeny.
  ///
  /// In en, this message translates to:
  /// **'Choose my area manually'**
  String get permLocDeny;

  /// No description provided for @permNotifEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Stay in the loop'**
  String get permNotifEyebrow;

  /// No description provided for @permNotifTitle.
  ///
  /// In en, this message translates to:
  /// **'Know the moment you’re confirmed.'**
  String get permNotifTitle;

  /// No description provided for @permNotifBody.
  ///
  /// In en, this message translates to:
  /// **'We’ll tell you when a provider accepts, when they’re on the way, and when it’s time for your appointment.'**
  String get permNotifBody;

  /// No description provided for @permNotifP1.
  ///
  /// In en, this message translates to:
  /// **'Booking updates only by default'**
  String get permNotifP1;

  /// No description provided for @permNotifP2.
  ///
  /// In en, this message translates to:
  /// **'Set quiet hours any time'**
  String get permNotifP2;

  /// No description provided for @permNotifP3.
  ///
  /// In en, this message translates to:
  /// **'Turn off individual channels in settings'**
  String get permNotifP3;

  /// No description provided for @permNotifAllow.
  ///
  /// In en, this message translates to:
  /// **'Turn on notifications'**
  String get permNotifAllow;

  /// No description provided for @permNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get permNotNow;

  /// No description provided for @permCamEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Verification step'**
  String get permCamEyebrow;

  /// No description provided for @permCamTitle.
  ///
  /// In en, this message translates to:
  /// **'We need your camera.'**
  String get permCamTitle;

  /// No description provided for @permCamBody.
  ///
  /// In en, this message translates to:
  /// **'To verify providers we capture your national ID and a live selfie. This keeps every customer safe.'**
  String get permCamBody;

  /// No description provided for @permCamP1.
  ///
  /// In en, this message translates to:
  /// **'Documents are encrypted and private'**
  String get permCamP1;

  /// No description provided for @permCamP2.
  ///
  /// In en, this message translates to:
  /// **'Reviewed only by our verification team'**
  String get permCamP2;

  /// No description provided for @permCamP3.
  ///
  /// In en, this message translates to:
  /// **'Never shown on your public profile'**
  String get permCamP3;

  /// No description provided for @permCamAllow.
  ///
  /// In en, this message translates to:
  /// **'Open camera'**
  String get permCamAllow;

  /// No description provided for @permCamDeny.
  ///
  /// In en, this message translates to:
  /// **'Upload from files instead'**
  String get permCamDeny;

  /// No description provided for @permDeniedCamTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera access is off.'**
  String get permDeniedCamTitle;

  /// No description provided for @permDeniedCamBody.
  ///
  /// In en, this message translates to:
  /// **'Verification needs a live selfie. Enable the camera in Settings, or upload photos from your files.'**
  String get permDeniedCamBody;

  /// No description provided for @permDeniedCamFallback.
  ///
  /// In en, this message translates to:
  /// **'Upload from files'**
  String get permDeniedCamFallback;

  /// No description provided for @permDeniedNotifTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off.'**
  String get permDeniedNotifTitle;

  /// No description provided for @permDeniedNotifBody.
  ///
  /// In en, this message translates to:
  /// **'You’ll still see every update in your in-app inbox, but we can’t alert you when a provider is on the way.'**
  String get permDeniedNotifBody;

  /// No description provided for @permDeniedNotifFallback.
  ///
  /// In en, this message translates to:
  /// **'Use the in-app inbox'**
  String get permDeniedNotifFallback;

  /// No description provided for @permDeniedLocTitle.
  ///
  /// In en, this message translates to:
  /// **'Location is off.'**
  String get permDeniedLocTitle;

  /// No description provided for @permDeniedLocBody.
  ///
  /// In en, this message translates to:
  /// **'Turn it on in Settings, or pick your area manually and we’ll search from there.'**
  String get permDeniedLocBody;

  /// No description provided for @permDeniedLocFallback.
  ///
  /// In en, this message translates to:
  /// **'Pick my area manually'**
  String get permDeniedLocFallback;

  /// No description provided for @permNeeded.
  ///
  /// In en, this message translates to:
  /// **'Permission needed'**
  String get permNeeded;

  /// No description provided for @permOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get permOpenSettings;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @delCantUndo.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone'**
  String get delCantUndo;

  /// No description provided for @delTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get delTitle;

  /// No description provided for @delBody.
  ///
  /// In en, this message translates to:
  /// **'Your data will be anonymized and any active bookings cancelled. Type {phrase} to confirm.'**
  String delBody(String phrase);

  /// No description provided for @delPhrase.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get delPhrase;

  /// No description provided for @errLoadTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this'**
  String get errLoadTitle;

  /// No description provided for @errLoadBody.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on our side. Give it another try.'**
  String get errLoadBody;

  /// No description provided for @commonTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonTryAgain;

  /// No description provided for @guestTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get guestTitle;

  /// No description provided for @guestBrowsing.
  ///
  /// In en, this message translates to:
  /// **'Browsing as guest'**
  String get guestBrowsing;

  /// No description provided for @guestSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in or create account'**
  String get guestSignIn;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'No connection — showing saved data'**
  String get offlineBanner;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @reasonNotePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Tell us what happened (optional)'**
  String get reasonNotePlaceholder;

  /// No description provided for @reasonKeepBooking.
  ///
  /// In en, this message translates to:
  /// **'Keep booking'**
  String get reasonKeepBooking;

  /// No description provided for @endOfList.
  ///
  /// In en, this message translates to:
  /// **'That\'s everything'**
  String get endOfList;

  /// No description provided for @slotJustTaken.
  ///
  /// In en, this message translates to:
  /// **'Just taken'**
  String get slotJustTaken;

  /// No description provided for @slotTitle.
  ///
  /// In en, this message translates to:
  /// **'Someone booked that slot.'**
  String get slotTitle;

  /// No description provided for @slotBody.
  ///
  /// In en, this message translates to:
  /// **'It went in the last moment. Here\'s what {name} still has free today.'**
  String slotBody(String name);

  /// No description provided for @slotPickAnotherDay.
  ///
  /// In en, this message translates to:
  /// **'Pick another day'**
  String get slotPickAnotherDay;

  /// No description provided for @slotBook.
  ///
  /// In en, this message translates to:
  /// **'Book slot'**
  String get slotBook;

  /// No description provided for @slotBookTime.
  ///
  /// In en, this message translates to:
  /// **'Book {time}'**
  String slotBookTime(String time);

  /// No description provided for @sysSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get sysSignedOut;

  /// No description provided for @sysSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Your session expired.'**
  String get sysSessionTitle;

  /// No description provided for @sysSessionBody.
  ///
  /// In en, this message translates to:
  /// **'For your security we sign you out after a period of inactivity. Your bookings and saved providers are all still here.'**
  String get sysSessionBody;

  /// No description provided for @sysSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get sysSignInAgain;

  /// No description provided for @sysLocked.
  ///
  /// In en, this message translates to:
  /// **'Account locked'**
  String get sysLocked;

  /// No description provided for @sysLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'This account is locked.'**
  String get sysLockedTitle;

  /// No description provided for @sysLockedBody.
  ///
  /// In en, this message translates to:
  /// **'Your account has been suspended by our team. Our support agents can explain why and what happens next.'**
  String get sysLockedBody;

  /// No description provided for @sysContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get sysContactSupport;

  /// No description provided for @sysBackToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get sysBackToSignIn;

  /// No description provided for @sysNoAccess.
  ///
  /// In en, this message translates to:
  /// **'No access'**
  String get sysNoAccess;

  /// No description provided for @sysNoAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'You can\'t open this.'**
  String get sysNoAccessTitle;

  /// No description provided for @sysNoAccessBody.
  ///
  /// In en, this message translates to:
  /// **'This area belongs to a different kind of account. If you think that\'s wrong, contact support.'**
  String get sysNoAccessBody;

  /// No description provided for @sysGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get sysGoBack;

  /// No description provided for @sysNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get sysNotFound;

  /// No description provided for @sysNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'This page isn\'t available.'**
  String get sysNotFoundTitle;

  /// No description provided for @sysNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'It may have been cancelled, removed, or the link is out of date.'**
  String get sysNotFoundBody;

  /// No description provided for @trackReschedule.
  ///
  /// In en, this message translates to:
  /// **'Reschedule'**
  String get trackReschedule;

  /// No description provided for @rescheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a new time.'**
  String get rescheduleTitle;

  /// No description provided for @rescheduleBody.
  ///
  /// In en, this message translates to:
  /// **'{name} is free at these times on {date}.'**
  String rescheduleBody(String name, String date);

  /// No description provided for @rescheduleNoSlots.
  ///
  /// In en, this message translates to:
  /// **'No free times that day. Try another date.'**
  String get rescheduleNoSlots;

  /// No description provided for @rescheduledToast.
  ///
  /// In en, this message translates to:
  /// **'Moved to {time}'**
  String rescheduledToast(String time);

  /// No description provided for @reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'My reports'**
  String get reportsTitle;

  /// No description provided for @reportsEmpty.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t reported anything.'**
  String get reportsEmpty;

  /// No description provided for @reportsResolution.
  ///
  /// In en, this message translates to:
  /// **'AIWA: {note}'**
  String reportsResolution(String note);

  /// No description provided for @reportStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get reportStatusOpen;

  /// No description provided for @reportStatusReview.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get reportStatusReview;

  /// No description provided for @reportStatusResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get reportStatusResolved;

  /// No description provided for @staffEditDetails.
  ///
  /// In en, this message translates to:
  /// **'Edit details'**
  String get staffEditDetails;

  /// No description provided for @staffServicesHint.
  ///
  /// In en, this message translates to:
  /// **'Does these services (none picked = all)'**
  String get staffServicesHint;

  /// No description provided for @staffSaved.
  ///
  /// In en, this message translates to:
  /// **'Staff member updated.'**
  String get staffSaved;

  /// No description provided for @staffDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Remove from bookings'**
  String get staffDeactivate;

  /// No description provided for @staffDeactivated.
  ///
  /// In en, this message translates to:
  /// **'Staff member deactivated.'**
  String get staffDeactivated;

  /// No description provided for @linkOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'No app on this phone could open that. Please try another way.'**
  String get linkOpenFailed;

  /// No description provided for @a11yChat.
  ///
  /// In en, this message translates to:
  /// **'Open chat'**
  String get a11yChat;

  /// No description provided for @a11ySend.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get a11ySend;

  /// No description provided for @a11yEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get a11yEdit;

  /// No description provided for @a11yShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get a11yShare;

  /// No description provided for @a11ySave.
  ///
  /// In en, this message translates to:
  /// **'Save to favourites'**
  String get a11ySave;

  /// No description provided for @a11ySaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to favourites'**
  String get a11ySaved;

  /// No description provided for @bookingsContestNoShow.
  ///
  /// In en, this message translates to:
  /// **'This wasn’t a no-show'**
  String get bookingsContestNoShow;

  /// No description provided for @bookingsNoShowContested.
  ///
  /// In en, this message translates to:
  /// **'Sent. AIWA support will review it.'**
  String get bookingsNoShowContested;

  /// No description provided for @bookingsNoShowContestOpen.
  ///
  /// In en, this message translates to:
  /// **'Contest sent, waiting for AIWA support'**
  String get bookingsNoShowContestOpen;

  /// No description provided for @trackChangeAddress.
  ///
  /// In en, this message translates to:
  /// **'Change visit address'**
  String get trackChangeAddress;

  /// No description provided for @addressAmendEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Home visit'**
  String get addressAmendEyebrow;

  /// No description provided for @addressAmendTitle.
  ///
  /// In en, this message translates to:
  /// **'Where should they come?'**
  String get addressAmendTitle;

  /// No description provided for @addressAmendBody.
  ///
  /// In en, this message translates to:
  /// **'Pick one of your saved addresses. It has to be inside {name}\'s service area.'**
  String addressAmendBody(String name);

  /// No description provided for @addressAmendReconfirm.
  ///
  /// In en, this message translates to:
  /// **'{name} already accepted this visit. Changing the address sends it back to Pending until they confirm again.'**
  String addressAmendReconfirm(String name);

  /// No description provided for @addressAmendCurrent.
  ///
  /// In en, this message translates to:
  /// **'Now: {address}'**
  String addressAmendCurrent(String address);

  /// No description provided for @addressAmendNone.
  ///
  /// In en, this message translates to:
  /// **'You have no other saved address. Add one under Profile › Addresses, then come back.'**
  String get addressAmendNone;

  /// No description provided for @addressAmendConfirm.
  ///
  /// In en, this message translates to:
  /// **'Change address'**
  String get addressAmendConfirm;

  /// No description provided for @addressAmendedToast.
  ///
  /// In en, this message translates to:
  /// **'Address changed'**
  String get addressAmendedToast;

  /// No description provided for @addressAmendedReconfirmToast.
  ///
  /// In en, this message translates to:
  /// **'Address changed. {name} has to confirm the visit again.'**
  String addressAmendedReconfirmToast(String name);

  /// No description provided for @addressAmendLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your addresses. Try again.'**
  String get addressAmendLoadFailed;

  /// No description provided for @authTermsUpdatedNotice.
  ///
  /// In en, this message translates to:
  /// **'The terms were updated while you were signing up. Please read and agree to the new version.'**
  String get authTermsUpdatedNotice;

  /// No description provided for @provResumeSetup.
  ///
  /// In en, this message translates to:
  /// **'Finish setup where I left off'**
  String get provResumeSetup;

  /// No description provided for @provResumeFilesMissing.
  ///
  /// In en, this message translates to:
  /// **'Your ID photos are no longer on this phone. Upload them again to finish.'**
  String get provResumeFilesMissing;

  /// No description provided for @provResumeDone.
  ///
  /// In en, this message translates to:
  /// **'Setup finished'**
  String get provResumeDone;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
