// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get authTagline => 'Beauty & grooming, near you.';

  @override
  String get authTaglineSub =>
      'Trusted barbers, hairdressers, nail artists, and spas — one tap away.';

  @override
  String get authChooseLanguage => 'Choose your language';

  @override
  String get authBrowseAsGuest => 'Browse as guest →';

  @override
  String get authChoiceProviderEyebrow => 'Provider · Welcome';

  @override
  String get authChoiceCustomerEyebrow => 'Customer · Welcome';

  @override
  String get authChoiceProviderTitle => 'Run your beauty studio with AIWA.';

  @override
  String get authChoiceProviderSubtitle =>
      'Manage bookings, hours, and your verified profile — all in one app.';

  @override
  String get authChoiceProviderSignUp => 'Set up a new studio';

  @override
  String get authChoiceCustomerSignUp => 'Create an account';

  @override
  String get authChoiceProviderHint => 'ID verification required.';

  @override
  String get authChoiceCustomerHint => 'Takes about a minute.';

  @override
  String get authHaveAccount => 'I already have an account';

  @override
  String get authSignInWithPhoneOrEmail => 'Sign in with phone or email.';

  @override
  String get authSafetyPolicy => 'Protected by AIWA\'s safety policy';

  @override
  String get authGatePerkHistory => 'Your booking history in one place';

  @override
  String get authGatePerkTracking => 'Live status + safety tracking';

  @override
  String get authGatePerkFavorites => 'Save favorite providers';

  @override
  String get authCreateAccount => 'Create account';

  @override
  String get authGateEyebrow => 'One quick step';

  @override
  String get authGateTitle => 'Sign in to book.';

  @override
  String get authGateBody =>
      'Browsing is open to everyone. Booking needs an account so providers can reach you.';

  @override
  String authStepOf(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get authModePhone => 'Phone';

  @override
  String get authModeEmail => 'Email';

  @override
  String get errorNoInternet => 'No internet connection';

  @override
  String get errorTimeout => 'Connection timed out';

  @override
  String get errorGeneric => 'Something went wrong';

  @override
  String get errorUnauthorized => 'Unauthorized. Please sign in again.';

  @override
  String get errorNotSupported => 'This isn\'t available yet.';

  @override
  String get errorLoginFailed => 'Login failed';

  @override
  String get errorRegistrationFailed => 'Registration failed';

  @override
  String get errorSendOtpFailed => 'Failed to send OTP';

  @override
  String get errorInvalidOtp => 'Invalid OTP';

  @override
  String authWelcomeBackName(String name) {
    return 'Welcome back, $name.';
  }

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authNewToAiwa => 'New to AIWA? ';

  @override
  String get authProviderSignIn => 'Provider sign in';

  @override
  String get authWelcomeBack => 'Welcome back';

  @override
  String get authSignInTitle => 'Sign in to AIWA';

  @override
  String get authSignInSubtitlePhone =>
      'Use the number and password you signed up with.';

  @override
  String get authSignInSubtitleEmail =>
      'Use the email and password you signed up with.';

  @override
  String get authPhoneNumber => 'Phone number';

  @override
  String get authPassword => 'Password';

  @override
  String get authRememberMe => 'Remember me';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authSendCode => 'Send code';

  @override
  String get authWhatsYourPhone => 'What\'s your phone number?';

  @override
  String get authWhatsYourEmail => 'What\'s your email?';

  @override
  String get authSendCodeSubtitle => 'We\'ll send a 6-digit code to confirm.';

  @override
  String authAgreeTerms(String terms, String policy) {
    return 'By continuing you agree to AIWA\'s $terms and $policy.';
  }

  @override
  String get authTermsLink => 'terms';

  @override
  String get authSafetyPolicyLink => 'safety policy';

  @override
  String get authVerify => 'Verify';

  @override
  String get authEnterCode => 'Enter the code';

  @override
  String authCodeSentTo(String destination) {
    return 'We sent a 6-digit code to $destination.';
  }

  @override
  String authResendIn(String time) {
    return 'Resend code in $time';
  }

  @override
  String get authResendCode => 'Resend code';

  @override
  String get authOtpHelp =>
      'Didn\'t get it? Check the number, then tap Resend once the timer ends.';

  @override
  String get authResetPassword => 'Reset password';

  @override
  String get authWhereSendCode => 'Where should we send the code?';

  @override
  String get authSendResetCode => 'Send reset code';

  @override
  String get authCheckMessages => 'Check your messages.';

  @override
  String get authCheckInbox => 'Check your inbox.';

  @override
  String get authAlmostDone => 'Almost done';

  @override
  String get authSetNewPassword => 'Set a new password.';

  @override
  String get authCodePlaceholder => '6-digit code';

  @override
  String get authNewPassword => 'New password';

  @override
  String get authConfirmPassword => 'Confirm password';

  @override
  String get authPasswordResetDone => 'Password reset. Please sign in.';

  @override
  String get commonContinue => 'Continue';

  @override
  String get authSetupTitle => 'Set up your account';

  @override
  String get authSetupSubtitle =>
      'A name and a password — that\'s it. We\'ll add the rest later.';

  @override
  String get authNameError => 'Enter your first and last name';

  @override
  String get authEmailError => 'Doesn\'t look like a valid email';

  @override
  String get authPasswordMinError => 'At least 6 characters';

  @override
  String get authPasswordHint => 'At least 6 characters.';

  @override
  String get authStrengthWeak => 'Weak';

  @override
  String get authStrengthOkay => 'Okay';

  @override
  String get authStrengthGood => 'Good';

  @override
  String get authStrengthStrong => 'Strong';

  @override
  String get authFullName => 'Full name';

  @override
  String get authNamePlaceholder => 'e.g. Layla Hassan';

  @override
  String get authNameHint => 'Your real name — providers see it on bookings.';

  @override
  String get authEmailHint => 'For receipts and account recovery.';

  @override
  String get authContinueWithoutPhoto => 'Continue without a photo';

  @override
  String get authMakeItYours => 'Make it yours';

  @override
  String get authMakeItYoursSub =>
      'Add a photo, pick your palette. You can change both later.';

  @override
  String get authUploadPhoto => 'Upload a photo';

  @override
  String get authReplacePhoto => 'Replace photo';

  @override
  String get authSigningUpAs => 'I\'m signing up as';

  @override
  String get authWoman => 'Woman';

  @override
  String get authMan => 'Man';

  @override
  String get authPaletteNote => 'This sets the palette of your app.';

  @override
  String get authRoleCustomerTitle => 'I\'m here to book';

  @override
  String get authRoleCustomerSub =>
      'Find a barber, hairdresser, nail artist, or spa near you.';

  @override
  String get authRolePerkBrowse => 'Browse verified providers';

  @override
  String get authRolePerkCash => 'Cash on visit';

  @override
  String get authRolePerkTrack => 'Track your booking live';

  @override
  String get authRoleProviderTitle => 'I\'m offering services';

  @override
  String get authRoleProviderSub => 'Get bookings from customers in your area.';

  @override
  String get authRolePerkId => 'ID verification required';

  @override
  String get authRolePerkManage => 'Manage your services & hours';

  @override
  String get authRolePerkPayouts => 'Cash payouts';

  @override
  String get authWelcomeToAiwa => 'Welcome to AIWA';

  @override
  String get authHowUsing => 'How will you\nbe using AIWA?';

  @override
  String get authChangeLater => 'You can change this later from your profile.';

  @override
  String get authTermsVerifiedTitle => 'Verified providers only';

  @override
  String get authTermsVerifiedBody =>
      'Every provider is checked with a national ID and a live selfie before they can take bookings.';

  @override
  String get authTermsPrivateTitle => 'Your data stays private';

  @override
  String get authTermsPrivateBody =>
      'Your phone and address are only shared with a provider after you confirm a booking with them.';

  @override
  String get authTermsFlagTitle => 'You can always flag or complain';

  @override
  String get authTermsFlagBody =>
      'If anything feels off, flag the provider or open a complaint. Our team reviews every report.';

  @override
  String get authTermsCashTitle => 'Cash only — for now';

  @override
  String get authTermsCashBody =>
      'In this version you pay the provider directly in cash after the service. Online payment is on the way.';

  @override
  String get authAgreeContinue => 'Agree & continue';

  @override
  String get authTermsTitle => 'A few promises\nbefore you start.';

  @override
  String get authTermsSubtitle =>
      'AIWA\'s customer terms & safety policy in plain words.';

  @override
  String authTermsAgree(String terms, String policy) {
    return 'I\'ve read and agree to the AIWA $terms and $policy.';
  }

  @override
  String get authCustomerTermsLink => 'customer terms';

  @override
  String get authTermsAccepted => 'Thanks — terms accepted.';

  @override
  String get authPoliciesUpdated => 'Policies updated';

  @override
  String get authTermsUpdatedTitle => 'We\'ve updated our terms.';

  @override
  String get authTermsUpdatedBody =>
      'AIWA\'s terms & safety policy changed on May 20, 2026 — mainly around cancellation penalties and provider verification. Please re-accept to keep booking.';

  @override
  String authTermsVersion(Object version) {
    return 'v$version';
  }

  @override
  String get categoryHair => 'Hair';

  @override
  String get categoryNails => 'Nails';

  @override
  String get categorySpa => 'Spa';

  @override
  String get categoryMakeup => 'Makeup';

  @override
  String get categoryLashes => 'Lashes';

  @override
  String get categorySkin => 'Skin';

  @override
  String get categoryMassage => 'Massage';

  @override
  String get categoryOther => 'Other';

  @override
  String get prefsSave => 'Save preferences';

  @override
  String get prefsLastStep => 'Last step';

  @override
  String get prefsTitle => 'Where should we\nlook for providers?';

  @override
  String get prefsSubtitle =>
      'We use these to tune the providers we show you. Change them any time from Profile.';

  @override
  String get commonUseGps => 'Use GPS';

  @override
  String get prefsSearchRadius => 'Search radius';

  @override
  String prefsRadiusRange(int min, int max) {
    return '$min–$max km';
  }

  @override
  String prefsMinKm(int km) {
    return 'Min · $km km';
  }

  @override
  String prefsMaxKm(int km) {
    return 'Max · $km km';
  }

  @override
  String get prefsAppLanguage => 'App language';

  @override
  String get authAccountCreatedReview =>
      'Account created. Verification in review.';

  @override
  String get provBizTitle => 'Set up your studio';

  @override
  String get provBizSubtitle => 'Customers will see this on your profile.';

  @override
  String get provBizName => 'Business name';

  @override
  String get provBizNamePlaceholder => 'e.g. Nadia Studio';

  @override
  String get provBizType => 'Business type';

  @override
  String get provBizIndividual => 'Individual';

  @override
  String get provBizShop => 'Shop / salon';

  @override
  String get provBizShopNote =>
      'Shops can add staff members with their own calendars.';

  @override
  String get provBizStaff => 'Staff members';

  @override
  String get commonOptional => 'Optional';

  @override
  String provBizStaffName(int number) {
    return 'Staff member $number name';
  }

  @override
  String get provBizAddStaff => 'Add staff member';

  @override
  String get provBizStaffNote =>
      'Add the team who\'ll take bookings. You can add more later.';

  @override
  String get provBizBio => 'Short bio';

  @override
  String get provBizBioPlaceholder =>
      'Cairo-trained colorist with a soft, editorial touch…';

  @override
  String get provBizBioHint => '2–3 lines on what makes you stand out.';

  @override
  String get provBizPrimaryCategory => 'Primary category';

  @override
  String get provBizPickOne => 'Pick the one you do most.';

  @override
  String get provBizAddress => 'Studio address';

  @override
  String get provBizAddressPlaceholder => 'Street, neighborhood, city';

  @override
  String provBizGpsLocked(String lat, String lng) {
    return 'GPS locked — $lat, $lng';
  }

  @override
  String get provBizNoGps => 'No GPS — tap \"Use GPS\"';

  @override
  String get provBizNearby => 'Customers nearby can find you';

  @override
  String get provPendingEyebrow => 'Verification submitted';

  @override
  String get provPendingTitle => 'We\'re reviewing\nyour documents.';

  @override
  String provPendingBody(String duration) {
    return 'Most reviews take $duration. You\'ll get a notification the moment AIWA approves your studio — then you can take bookings.';
  }

  @override
  String get provPendingUnder24h => 'under 24 hours';

  @override
  String get provPendingIdReceived => 'ID front & back received';

  @override
  String get provPendingSelfieReceived => 'Live selfie received';

  @override
  String get provPendingAdminReview => 'Admin review in progress';

  @override
  String get provPendingExplore => 'Explore the app while you wait';

  @override
  String get provPendingBrowseNote =>
      'You can browse, but bookings open after verification.';

  @override
  String get provStatusCheck => 'Check status';

  @override
  String get provInfoTitle => 'AIWA needs a bit more from you';

  @override
  String get provRejectedTitle => 'Not approved yet';

  @override
  String get provRejectedBody =>
      'Our team couldn\'t approve your documents. Fix the issue below and send them again.';

  @override
  String get provSuspendedTitle => 'Your provider account is suspended';

  @override
  String get provSuspendedBody =>
      'You can\'t take bookings right now. Contact support to find out why and what to do next.';

  @override
  String get provResubmit => 'Send documents again';

  @override
  String get provAdminNote => 'Note from AIWA';

  @override
  String get provDocsResent => 'Documents sent. We\'ll review them shortly.';

  @override
  String get provVerifySubmit => 'Submit for review';

  @override
  String get provVerifyTitle => 'Verify your identity';

  @override
  String get provVerifySubtitle =>
      'Upload your national ID and a live selfie. AIWA reviews every provider before they can take bookings.';

  @override
  String get provVerifyIdFront => 'National ID — front';

  @override
  String get provVerifyIdFrontHint =>
      'Front side of your government-issued ID. Make sure all four corners are visible.';

  @override
  String get provVerifyIdBack => 'National ID — back';

  @override
  String get provVerifyIdBackHint => 'The back side of the same ID.';

  @override
  String get provVerifySelfie => 'Live selfie';

  @override
  String get provVerifySelfieHint =>
      'A clear photo of your face, taken now. We compare it to your ID.';

  @override
  String get provVerifyPrivate =>
      'Your documents are private. Only AIWA admins reviewing your account see them. They\'re never shown to customers.';

  @override
  String provVerifyUploaded(String label) {
    return '$label uploaded · tap to replace';
  }

  @override
  String moneyEgp(String amount) {
    return 'EGP $amount';
  }

  @override
  String whenToday(String time) {
    return 'Today · $time';
  }

  @override
  String whenTomorrow(String time) {
    return 'Tomorrow · $time';
  }

  @override
  String whenYesterday(String time) {
    return 'Yesterday · $time';
  }

  @override
  String durationMinutes(int m) {
    String _temp0 = intl.Intl.pluralLogic(
      m,
      locale: localeName,
      other: '$m min',
    );
    return '$_temp0';
  }

  @override
  String durationHours(int h) {
    String _temp0 = intl.Intl.pluralLogic(
      h,
      locale: localeName,
      other: '${h}h',
    );
    return '$_temp0';
  }

  @override
  String durationHoursMinutes(int h, int m) {
    return '${h}h ${m}m';
  }

  @override
  String get bookNowOfflineEyebrow => 'Not online';

  @override
  String bookNowOfflineTitle(String name) {
    return '$name is offline right now.';
  }

  @override
  String get bookNowOfflineBody =>
      'They’ll show as available again the moment they come back online. You can try Book Now later, or pick a scheduled time now.';

  @override
  String get bookNowBusyEyebrow => 'Fully booked';

  @override
  String bookNowBusyTitle(String name) {
    return '$name is busy with another client.';
  }

  @override
  String get bookNowBusyBody =>
      'Every Book Now slot is taken for the next stretch. A scheduled slot later today is usually faster than waiting.';

  @override
  String get bookNowVacationEyebrow => 'On vacation';

  @override
  String bookNowVacationTitle(String name) {
    return '$name is on vacation.';
  }

  @override
  String get bookNowVacationBody =>
      'They’ve paused all bookings for now. We’ll show them again as soon as they’re back.';

  @override
  String get bookNowPausedEyebrow => 'Temporarily paused';

  @override
  String bookNowPausedTitle(String name) {
    return '$name can’t take new bookings right now.';
  }

  @override
  String get bookNowPausedBody =>
      'They’re settling an outstanding balance with AIWA. This clears automatically once that’s paid — try again soon.';

  @override
  String get bookNowUnavailableEyebrow => 'Unavailable';

  @override
  String bookNowUnavailableTitle(String name) {
    return '$name isn’t taking bookings.';
  }

  @override
  String get bookNowUnavailableBody =>
      'This provider, staff member, or service is temporarily inactive. Try another provider nearby.';

  @override
  String get bookNowChecking => 'Checking availability…';

  @override
  String bookNowConfirming(String name) {
    return 'Confirming $name can take this right now.';
  }

  @override
  String get bookNowChooseScheduled => 'Choose a scheduled time';

  @override
  String get bookNowSeeOthers => 'See other providers nearby';

  @override
  String get bookingPlaced => 'Booking placed';

  @override
  String bookingSaidAiwa(String aiwa, String name) {
    return 'You said $aiwa. We told $name.';
  }

  @override
  String get bookingAiwaWord => 'aiwa';

  @override
  String bookingWhenLong(String date, String time) {
    return '$date at $time';
  }

  @override
  String bookingConfirmPing(String when) {
    return '$when. We\'ll ping you the moment they confirm — usually within 30 minutes.';
  }

  @override
  String get bookingProvider => 'Provider';

  @override
  String get bookingService => 'Service';

  @override
  String get bookingWhen => 'When';

  @override
  String get bookingTotal => 'Total';

  @override
  String get bookingViewMine => 'View my bookings';

  @override
  String get bookingAddToCalendar => 'Add to calendar';

  @override
  String get bookingTypeEyebrow => 'How do you want to book';

  @override
  String get bookingTypeTitle => 'Now, or later?';

  @override
  String bookingTypeAccepts(String name) {
    return '$name accepts both same-day requests and scheduled bookings.';
  }

  @override
  String get bookingTypeNowEyebrow => 'Book now';

  @override
  String get bookingTypeNowTitle => 'Get someone on the way';

  @override
  String get bookingTypeNowEta => 'Est. arrival 25–40 min';

  @override
  String get bookingTypeNowComes => 'Comes to you';

  @override
  String get bookingTypeScheduleEyebrow => 'Schedule';

  @override
  String get bookingTypeScheduleTitle => 'Pick a date & time slot';

  @override
  String get bookingTypeUpTo14 => 'Up to 14 days out';

  @override
  String get bookingTypeProviderConfirms => 'Provider confirms slot';

  @override
  String bookingTypeCashNote(String cash) {
    return 'Either way, payment is $cash. Online payment is coming in a future version.';
  }

  @override
  String get bookingCashOnVisit => 'cash on visit';

  @override
  String get chatReportEyebrow => 'Report message';

  @override
  String get chatReportTitle => 'Send this to admin review?';

  @override
  String get chatReportBody =>
      'Support reviews reported messages and can remove them. This doesn\'t notify the other person.';

  @override
  String get chatMaskedOnline => 'Masked number · online';

  @override
  String get chatAdminNote =>
      'Admin can view this chat only if you submit a complaint or dispute a payment.';

  @override
  String get chatHint => 'Message…';

  @override
  String get chatRemoved => '[message removed by admin]';

  @override
  String get chatReport => 'Report';

  @override
  String get bookingsGuestTitle => 'See your bookings';

  @override
  String get bookingsGuestBody => 'Sign in to view and track your bookings.';

  @override
  String get bookingsEyebrow => 'Your appointments';

  @override
  String get bookingsTitle => 'Bookings';

  @override
  String get bookingsUpcoming => 'Upcoming';

  @override
  String get bookingsPast => 'Past';

  @override
  String get bookingsEmptyUpcomingTitle => 'Nothing booked yet';

  @override
  String get bookingsEmptyPastTitle => 'No past appointments';

  @override
  String get bookingsEmptyUpcomingBody =>
      'When you book a provider, it shows up here so you can track them on the way.';

  @override
  String get bookingsEmptyPastBody =>
      'Once an appointment is finished it moves here, ready to re-book in a tap.';

  @override
  String get bookingsFindProvider => 'Find a provider';

  @override
  String get commonLoadMore => 'Load more';

  @override
  String distanceKm(String km) {
    return '$km km';
  }

  @override
  String get bookingsNoShow => 'Marked no-show';

  @override
  String get bookingsRejectedByProvider => 'Rejected by provider';

  @override
  String get bookingsCancelledByYou => 'Cancelled by you';

  @override
  String get bookingsCancelledByProvider => 'Cancelled by Provider';

  @override
  String bookingsCancelledBy(String who) {
    return 'Cancelled by $who';
  }

  @override
  String commonQuoted(String text) {
    return '\"$text\"';
  }

  @override
  String get bookingsPenaltyApplied =>
      'Provider penalty applied for late cancellation.';

  @override
  String get bookingsTrack => 'Track';

  @override
  String get bookingsDirections => 'Directions';

  @override
  String get bookingsRebook => 'Re-book';

  @override
  String get bookingsLeaveReview => 'Leave a review';

  @override
  String get bookingsSeeAlternatives => 'See alternatives';

  @override
  String bookingRebookedFor(String time) {
    return 'Rebooked for $time.';
  }

  @override
  String get bookingProviderOnWay => 'Provider is on the way.';

  @override
  String get bookingPlacedWaiting => 'Booking placed. Waiting to confirm.';

  @override
  String get bookingThisProvider => 'this provider';

  @override
  String get bookingBookService => 'Book a service';

  @override
  String get bookingPickTime => 'Pick a time';

  @override
  String bookingDateMonth(String month) {
    return 'Date · $month';
  }

  @override
  String get bookingAvailableSlots => 'Available slots';

  @override
  String get bookingNoSlots => 'No free slots on this day — try another date.';

  @override
  String get bookingWhere => 'Where';

  @override
  String get bookingNowAddressNote =>
      'Book Now always comes to your address — confirm which one below.';

  @override
  String get bookingAtMyAddress => 'At my address';

  @override
  String get bookingAtSalon => 'At the salon';

  @override
  String get bookingAddAddress => 'Add new address';

  @override
  String get bookingPayment => 'Payment';

  @override
  String get bookingCashOnVisitTitle => 'Cash on visit';

  @override
  String get bookingCashOnVisitSub =>
      'Pay the provider directly after your service';

  @override
  String get bookingNoteLabel => 'Note for the provider';

  @override
  String get bookingNotePlaceholder => 'Any special requests…';

  @override
  String get bookingTotalCash => 'Total · cash';

  @override
  String get bookingChooseService => 'Choose a service';

  @override
  String get bookingChooseTime => 'Choose a time';

  @override
  String get bookingChooseAddress => 'Choose an address';

  @override
  String get bookingConfirm => 'Confirm booking';

  @override
  String get bookingChooseServiceBelow => 'Choose a service below';

  @override
  String get outcomeExpiredEyebrow => 'Request expired';

  @override
  String get outcomeExpiredTitle => 'No answer in time.';

  @override
  String outcomeExpiredBody(String name) {
    return '$name didn\'t respond within the booking window, so your request was released. You haven\'t been charged anything.';
  }

  @override
  String get outcomeTheProvider => 'The provider';

  @override
  String get outcomeSeeAlternatives => 'See alternative providers';

  @override
  String get outcomeBackToBookings => 'Back to bookings';

  @override
  String get rejectedEyebrow => 'Booking rejected';

  @override
  String get rejectedTitleGeneric => 'Provider couldn’t take this one.';

  @override
  String rejectedTitle(String name) {
    return '$name couldn\'t take this one.';
  }

  @override
  String get rejectedSimilar => 'Similar providers';

  @override
  String get rejectedOtherNearby => 'Other providers nearby';

  @override
  String rejectedReasonFrom(String name) {
    return 'Reason from $name';
  }

  @override
  String rejectedBookAnother(String name) {
    return 'Book $name at another time';
  }

  @override
  String get rejectedNextSlots => 'Next open slots for the same service';

  @override
  String get rejectedSeeAllTimes => 'See all times';

  @override
  String get commonToday => 'Today';

  @override
  String get commonTomorrow => 'Tomorrow';

  @override
  String get commonBook => 'Book';

  @override
  String distanceMeters(int m) {
    return '$m m';
  }

  @override
  String get proposedAccepted =>
      'New time confirmed — your calendar and reminders are updated.';

  @override
  String get proposedEyebrow => 'New time proposed';

  @override
  String proposedTitle(String name) {
    return '$name suggested a different time.';
  }

  @override
  String get proposedLead =>
      'Your original slot wasn\'t available. Here\'s what they can offer instead.';

  @override
  String proposedInsteadOf(String when) {
    return 'Instead of $when';
  }

  @override
  String get proposedExpiredTitle => 'This offer expired';

  @override
  String get proposedExpiredBody =>
      'You didn\'t respond in time, so the request was released automatically. Ask for another time or see who else is free.';

  @override
  String proposedRespondWithin(String time) {
    return 'Respond within $time or this offer expires automatically.';
  }

  @override
  String get proposedAccept => 'Accept new time';

  @override
  String get proposedDecline => 'Decline & see alternatives';

  @override
  String get payConfirmedToast => 'Payment confirmed. Receipt sent.';

  @override
  String get payUnpaidToast =>
      'Reported as unpaid. AIWA support has been notified.';

  @override
  String get payEyebrow => 'Confirm payment';

  @override
  String payTitle(String name) {
    return 'Did you pay $name in cash?';
  }

  @override
  String payTotalDue(String amount) {
    return 'Total due · $amount';
  }

  @override
  String get payYes => 'Yes, I paid — confirm';

  @override
  String get payNo => 'No / something\'s wrong';

  @override
  String get payRate => 'Rate your provider';

  @override
  String get payUndo => 'Undo — I tapped by mistake';

  @override
  String get payWhatHappened => 'What happened?';

  @override
  String get payExplainPlaceholder => 'Explain the payment issue…';

  @override
  String get paySubmitUnpaid => 'Submit as unpaid';

  @override
  String get commonBack => 'Back';

  @override
  String get paidTitle => 'Payment confirmed';

  @override
  String get paidSub => 'Receipt sent to your email';

  @override
  String get paidCashCollected => 'Cash collected';

  @override
  String paidCommission(String percent) {
    return 'AIWA commission ($percent%) · added to ledger';
  }

  @override
  String get paidBookingStatus => 'Booking status';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get complaintBehavior => 'Provider behavior';

  @override
  String get complaintBehaviorHint =>
      'Rude, unsafe, or unprofessional conduct.';

  @override
  String get complaintQuality => 'Service quality';

  @override
  String get complaintQualityHint =>
      'Service didn\'t match what was advertised.';

  @override
  String get complaintPricing => 'Pricing or billing';

  @override
  String get complaintPricingHint => 'Asked for more cash than agreed.';

  @override
  String get complaintSafety => 'Safety concern';

  @override
  String get complaintSafetyHint => 'Hygiene, identity, or any safety issue.';

  @override
  String get complaintNoShow => 'Provider didn\'t show';

  @override
  String get complaintNoShowHint => 'Booked but never arrived.';

  @override
  String get complaintOther => 'Something else';

  @override
  String get complaintOtherHint => 'Tell us in your own words.';

  @override
  String get complaintSubmitted =>
      'Complaint submitted. We will reach out via WhatsApp.';

  @override
  String get complaintEyebrow => 'Open a complaint';

  @override
  String get complaintPickCategory => 'Pick a category';

  @override
  String get complaintTellMore => 'Tell us more';

  @override
  String get complaintPlaceholder =>
      'Walk us through what happened. The more detail, the faster we can help.';

  @override
  String get complaintPrivate =>
      'Your name and contact info stay private. Only the AIWA support team will see this case.';

  @override
  String get complaintSubmit => 'Submit complaint';

  @override
  String complaintAbout(String name) {
    return 'About $name';
  }

  @override
  String complaintBookingNo(String id) {
    return 'Booking #$id';
  }

  @override
  String get complaintPrivateTag => 'Private';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusConfirmed => 'Confirmed';

  @override
  String get statusAccepted => 'Accepted';

  @override
  String get statusOnTheWay => 'On the way';

  @override
  String get statusArrived => 'Arrived';

  @override
  String get statusInProgress => 'In progress';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusRejected => 'Rejected';

  @override
  String get statusNoShow => 'No-show';

  @override
  String get statusExpired => 'Expired';

  @override
  String get statusDisputed => 'Disputed';

  @override
  String get trackPendingHint => 'Waiting for the provider to confirm.';

  @override
  String get trackAcceptedHint => 'Your booking is confirmed.';

  @override
  String get trackOnTheWayHint => 'Provider is heading to your address.';

  @override
  String get trackArrivedHint => 'Provider has arrived at your door.';

  @override
  String get trackInProgressHint => 'Service is underway.';

  @override
  String get trackCompletedHint => 'Service done. Pay cash and rate.';

  @override
  String get trackWaitPending => 'Waiting for the provider to accept';

  @override
  String get trackWaitAccepted => 'Updates when the provider heads out';

  @override
  String get trackWaitOnTheWay => 'Updates when the provider arrives';

  @override
  String get trackWaitArrived => 'Updates when the provider starts the service';

  @override
  String get trackWaitInProgress =>
      'Updates when the provider marks it complete';

  @override
  String get trackUpdatesAuto => 'Updates automatically';

  @override
  String get cancelReasonMind => 'Changed my mind';

  @override
  String get cancelReasonOther => 'Found another provider';

  @override
  String get cancelReasonWrong => 'Wrong service / time';

  @override
  String get cancelReasonPrice => 'Price is too high';

  @override
  String get cancelReasonUnresponsive => 'Provider not responsive';

  @override
  String get cancelReasonElse => 'Something else';

  @override
  String get trackCancelEyebrow => 'Cancel your booking';

  @override
  String get trackCancelTitle => 'Why are you cancelling?';

  @override
  String trackCancelledToast(String reason) {
    return 'Booking cancelled. Reason: $reason';
  }

  @override
  String get trackStatusTimeline => 'Status timeline';

  @override
  String get trackCancelBooking => 'Cancel booking';

  @override
  String get trackReportProblem => 'Report a problem';

  @override
  String get trackTracking => 'Tracking';

  @override
  String get trackSafetyTitle => 'SOS is one tap away';

  @override
  String get trackSafetySub =>
      'SOS alerts AIWA support and texts your trusted contacts.';

  @override
  String get trackSos => 'SOS — alert a trusted contact & AIWA';

  @override
  String get trackSosAlerting =>
      'Alerting your trusted contact and AIWA support…';

  @override
  String trackSosNotified(String bold, String detail) {
    return '$bold $detail In immediate danger, call 122.';
  }

  @override
  String get trackSosNotifiedBold => 'AIWA support has been alerted.';

  @override
  String get trackSosRecordedBold => 'Your SOS was recorded.';

  @override
  String get trackSosTexting => 'Texting your trusted contacts…';

  @override
  String trackSosTexted(int count) {
    return 'Trusted contacts texted: $count.';
  }

  @override
  String trackSosTextFailed(int count) {
    return 'Texts that could not be sent: $count. Call them yourself if you can.';
  }

  @override
  String get trackSosNoContacts => 'No trusted contacts were texted.';

  @override
  String get trackSosLogged =>
      'You\'re marked safe and the SOS is closed. Support can still see it on this booking.';

  @override
  String get trackSosFailed =>
      'Your SOS could not be sent. Try again. In immediate danger, call 122.';

  @override
  String get trackImSafe => 'I\'m safe';

  @override
  String get trackCheckInTitle => 'On-site service — check in when you arrive';

  @override
  String trackCheckInSub(String name) {
    return 'Tap in at the venue to let $name know you\'re there.';
  }

  @override
  String get trackCheckedIn => 'Checked in';

  @override
  String get trackCheckIn => 'Check in';

  @override
  String get trackConfirmCash => 'Confirm your cash payment';

  @override
  String trackDueTo(String amount, String name) {
    return '$amount due to $name';
  }

  @override
  String get commonConfirm => 'Confirm';

  @override
  String trackFeeWants(String name, String amount) {
    return '$name wants $amount for travel';
  }

  @override
  String trackFeeTotal(String base, String fee, String total) {
    return 'Total will be $base + $fee = $total.';
  }

  @override
  String get commonDecline => 'Decline';

  @override
  String get trackAcceptConfirm => 'Accept & confirm';

  @override
  String trackServicePlusTravel(String service, String travel) {
    return 'Service $service + travel $travel';
  }

  @override
  String trackTotalAmount(String amount) {
    return 'Total $amount';
  }

  @override
  String get trackDeclinedEyebrow => 'Booking cancelled';

  @override
  String get trackDeclinedTitle => 'No problem — no fee applied.';

  @override
  String trackDeclinedBody(String fee) {
    return 'You declined the $fee travel fee, so this request was cancelled cleanly. Neither of you is penalized.';
  }

  @override
  String get trackFindAnother => 'Find another provider';

  @override
  String get agoYesterday => 'Yesterday';

  @override
  String agoDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String agoWeeks(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n weeks ago',
      one: '1 week ago',
    );
    return '$_temp0';
  }

  @override
  String agoMonths(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n months ago',
      one: '1 month ago',
    );
    return '$_temp0';
  }

  @override
  String providerShareText(String name) {
    return '$name on AIWA';
  }

  @override
  String get providerStartsAt => 'Starts at';

  @override
  String get providerAskProvider => 'Ask provider';

  @override
  String get providerBookNow => 'Book now';

  @override
  String get providerNew => 'New';

  @override
  String get providerVerified => 'Verified';

  @override
  String get providerBioFallback =>
      'Top-rated provider in your area. Read more about the studio, services, and recent reviews.';

  @override
  String get providerCall => 'Call';

  @override
  String get providerWhatsApp => 'WhatsApp';

  @override
  String get providerReport => 'Report';

  @override
  String get providerNoReviews => 'No reviews yet';

  @override
  String get providerNoReviewsBody =>
      'Be the first to book and leave a review.';

  @override
  String providerBasedOn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Based on $count reviews',
      one: 'Based on 1 review',
    );
    return '$_temp0';
  }

  @override
  String get providerNoPhotos => 'No photos yet';

  @override
  String get providerNoPhotosBody =>
      'This provider hasn\'t added gallery photos.';

  @override
  String get providerNoServices => 'No services listed';

  @override
  String get providerNoServicesBody =>
      'This provider has not published services yet.';

  @override
  String get providerTabServices => 'Services';

  @override
  String get providerTabReviews => 'Reviews';

  @override
  String get providerTabGallery => 'Gallery';

  @override
  String get providerUnavailable => 'Unavailable';

  @override
  String get staffPickTitle => 'Pick your stylist.';

  @override
  String get staffPickBody =>
      'This is a shop with multiple staff — your booking will be tied to whoever you pick.';

  @override
  String get staffNoPreference => 'No preference';

  @override
  String get staffFirstAvailable => 'First available staff member';

  @override
  String get flagReasonMisleading => 'Misleading profile or gallery';

  @override
  String get flagReasonBehavior => 'Inappropriate or unsafe behavior';

  @override
  String get flagReasonPrice => 'Refused to honor agreed price';

  @override
  String get flagReasonIdentity => 'Identity feels suspicious';

  @override
  String get flagReasonSpam => 'Spam or fake account';

  @override
  String get flagReasonOther => 'Other';

  @override
  String get flagThanks =>
      'Thanks — flag received. Our team reviews every report.';

  @override
  String flagEyebrow(String name) {
    return 'Flag $name';
  }

  @override
  String get flagTitle => 'Tell us what\'s wrong';

  @override
  String get flagBody =>
      'Flags are anonymous. Our team reviews every report and acts on the provider if confirmed.';

  @override
  String get flagHelpUs => 'Help us understand';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get flagSubmit => 'Submit flag';

  @override
  String get providerReportPhoto => 'Report photo';

  @override
  String get providerReportPhotoHint => 'Press and hold a photo to report it.';

  @override
  String get homeOpen => 'Open';

  @override
  String get homeOpenNow => 'Open now';

  @override
  String get homeFrom => 'From';

  @override
  String get homeNearMe => 'Near me';

  @override
  String get homeGoodMorning => 'Good morning';

  @override
  String get homeGoodAfternoon => 'Good afternoon';

  @override
  String get homeGoodEvening => 'Good evening';

  @override
  String homeGreetingName(String greeting, String name) {
    return '$greeting, $name';
  }

  @override
  String get homeHeadline => 'Who\'s making you\nfeel new tonight?';

  @override
  String get homeSearchHint => 'Service or provider';

  @override
  String get homePromoEyebrow => 'This week · 20% off';

  @override
  String get homePromoTitle => 'Bridal lookbook season';

  @override
  String get homePromoBody =>
      'Top-rated makeup & lash artists, with package pricing.';

  @override
  String get homeExplore => 'Explore →';

  @override
  String get homeCategories => 'Categories';

  @override
  String get commonSeeAll => 'See all';

  @override
  String get homeAll => 'All';

  @override
  String get homeNobodyNearby => 'Nobody nearby yet';

  @override
  String get homeNobodyNearbyBody =>
      'No providers within your radius right now. Try browsing all categories.';

  @override
  String get homeBrowseAll => 'Browse all';

  @override
  String get homeTrending => 'Trending near you';

  @override
  String get homeViewMap => 'View map';

  @override
  String get homeAvailableNow => 'Available now';

  @override
  String get searchSortNearest => 'Nearest';

  @override
  String get searchSortTopRated => 'Top rated';

  @override
  String get searchSortPrice => 'Price';

  @override
  String get searchNotifyToast => 'We\'ll let you know.';

  @override
  String get searchEyebrow => 'Find someone new';

  @override
  String get searchTitle => 'Discover';

  @override
  String get searchHint => 'Search providers, services, locations';

  @override
  String searchMinRatingChip(String rating) {
    return '★ $rating+ ×';
  }

  @override
  String searchUnderPriceChip(String price) {
    return 'Under $price ×';
  }

  @override
  String get searchSort => 'Sort';

  @override
  String searchFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count found',
    );
    return '$_temp0';
  }

  @override
  String searchNoMatch(String query) {
    return 'No match for “$query”';
  }

  @override
  String get searchNothingInCategory => 'Nothing in this category nearby';

  @override
  String get searchNoMatchBody =>
      'Try a different spelling, or browse by category instead.';

  @override
  String get searchNoFilterMatchBody =>
      'No providers within your radius match these filters yet.';

  @override
  String get searchClearAll => 'Clear search & filters';

  @override
  String get searchWiden => 'Widen my radius';

  @override
  String get searchNotifyMe => 'Notify me when someone joins';

  @override
  String searchInRange(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count providers in range',
      one: '1 provider in range',
    );
    return '$_temp0';
  }

  @override
  String get searchFilters => 'Filters';

  @override
  String get searchReset => 'Reset';

  @override
  String get searchMinRating => 'Minimum rating';

  @override
  String get searchAny => 'Any';

  @override
  String get searchMaxPrice => 'Max price';

  @override
  String searchShowProviders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show $count providers',
      one: 'Show 1 provider',
    );
    return '$_temp0';
  }

  @override
  String get tabToday => 'Today';

  @override
  String get tabBookings => 'Bookings';

  @override
  String get tabServices => 'Services';

  @override
  String get tabSchedule => 'Schedule';

  @override
  String get tabProfile => 'Profile';

  @override
  String get dashNewRequests => 'New requests';

  @override
  String dashPendingCount(int count) {
    return '$count pending';
  }

  @override
  String get dashConfirmedToday => 'Confirmed today';

  @override
  String get dashNothingElse => 'Nothing else on the books for today.';

  @override
  String dashHelloName(String name) {
    return 'Hello, $name';
  }

  @override
  String get dashHello => 'Hello';

  @override
  String get dashTodaysSchedule => 'Today\'s schedule.';

  @override
  String get dashStatToday => 'Today';

  @override
  String get dashStatEgpToday => 'EGP today';

  @override
  String get dashStatRating => 'Rating';

  @override
  String dashNewRequestsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new booking requests',
      one: '1 new booking request',
    );
    return '$_temp0';
  }

  @override
  String get dashReplyWithin =>
      'Reply within 30 minutes to keep your top rating.';

  @override
  String get commonCustomer => 'Customer';

  @override
  String get commonAccept => 'Accept';

  @override
  String get provBookingsEyebrow => 'Manage';

  @override
  String get provTabPending => 'Pending';

  @override
  String get provTabUpcoming => 'Upcoming';

  @override
  String get provTabPast => 'Past';

  @override
  String get provNothingHere => 'Nothing here yet.';

  @override
  String get closeTheCustomer => 'the customer';

  @override
  String get closeDisputedToast =>
      'Marked as disputed. Admin has been notified.';

  @override
  String get closeEyebrow => 'Close out this job';

  @override
  String closeDidPay(String name) {
    return 'Did $name pay in cash?';
  }

  @override
  String get closeCashReceived => 'Yes, cash received';

  @override
  String get closeMarkDisputed => 'Mark unpaid or disputed';

  @override
  String get closeJobClosed => 'Cash received · job closed';

  @override
  String closeReceiptSentTo(String name) {
    return 'Receipt sent to $name';
  }

  @override
  String closeRate(String name) {
    return 'Rate $name';
  }

  @override
  String get closeSubmitDisputed => 'Submit as disputed';

  @override
  String get rateTagOnTime => 'On time';

  @override
  String get rateTagRespectful => 'Respectful';

  @override
  String get rateTagClear => 'Clear about needs';

  @override
  String get rateTagPaid => 'Paid in full';

  @override
  String get rateTagLate => 'Late';

  @override
  String get rateTagHardToReach => 'Difficult to reach';

  @override
  String get rateSubmitted =>
      'Rating submitted. Slot freed — next booking notified.';

  @override
  String get rateCustomerFallback => 'customer';

  @override
  String get rateSubmit => 'Submit rating';

  @override
  String get rateEyebrow => 'Two-way rating';

  @override
  String rateStars(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n stars',
      one: '1 star',
    );
    return '$_temp0';
  }

  @override
  String get rateQuickTags => 'Quick tags';

  @override
  String get pbdAltTimeSent => 'Alternative time sent to customer.';

  @override
  String get pbdCancelEyebrow => 'Cancelling after accepting';

  @override
  String get pbdCancelTitle => 'This applies a penalty';

  @override
  String get pbdCancelWarning =>
      'Cancelling an accepted booking affects your reliability score and adds a small penalty fee to your ledger.';

  @override
  String get pbdReasonEmergency => 'Emergency / unavailable';

  @override
  String get pbdReasonSick => 'Staff called in sick';

  @override
  String get pbdReasonOverbooked => 'Overbooked by mistake';

  @override
  String get pbdReasonUnreachable => 'Customer unreachable';

  @override
  String get pbdCancelConfirm => 'Cancel + accept penalty';

  @override
  String get pbdCancelledToast =>
      'Booking cancelled. Penalty applied to your ledger.';

  @override
  String get pbdNoShow => 'Customer didn\'t show';

  @override
  String get pbdNoShowTitle => 'Mark this booking as a no-show?';

  @override
  String get pbdNoShowBody =>
      'Use this only if the customer never came and you couldn\'t reach them. It closes the booking without a strike for you and is recorded against the customer.';

  @override
  String get pbdNoShowToast => 'Marked as a no-show.';

  @override
  String get pbdEyebrow => 'Booking request';

  @override
  String get pbdTitle => 'Review & respond';

  @override
  String pbdPriorBookings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count prior bookings',
      one: '1 prior booking',
    );
    return '$_temp0';
  }

  @override
  String get pbdHomeAddress => 'HOME SERVICE ADDRESS';

  @override
  String get pbdNoAddress => 'No address attached';

  @override
  String get pbdNoAddressBody =>
      'This home-service request has no address, so there\'s nothing to price a travel fee against. You can still accept or decline normally.';

  @override
  String pbdQuoteSent(String amount) {
    return 'Travel fee quote sent · $amount';
  }

  @override
  String get pbdQuoteSentBody =>
      'Waiting on the customer to accept or decline. If they accept, this booking confirms automatically — no extra tap needed from you.';

  @override
  String get pbdFeeAccepted => 'Travel fee accepted';

  @override
  String get pbdFeeAcceptedBody =>
      'Locked in and added to the total. The travel fee is pass-through to you — AIWA doesn\'t take commission on it.';

  @override
  String get pbdCustomerNote => 'Customer note';

  @override
  String get pbdQuoteInstead => 'Quote a travel fee instead';

  @override
  String get pbdProposeInstead => 'Propose a different time instead';

  @override
  String get pbdOnMyWay => 'On my way';

  @override
  String get pbdOnMyWayNote => 'Customer gets a push + live tracking starts.';

  @override
  String get pbdArrived => 'I\'ve arrived';

  @override
  String get pbdArrivedNote => 'Customer is told you are at the door.';

  @override
  String get pbdStartService => 'Start service';

  @override
  String get pbdStartNote => 'Timer starts. Safety check-in stays on.';

  @override
  String get pbdStartVenueNote =>
      'Tap once the customer has arrived at your venue.';

  @override
  String get pbdFinishNote =>
      'Finish the job, then confirm the cash you received.';

  @override
  String get pbdMarkCompleted => 'Mark completed';

  @override
  String get pbdJobProgress => 'Job progress';

  @override
  String get pbdDuration => 'Duration';

  @override
  String get pbdRequested => 'Requested';

  @override
  String get pbdServicePrice => 'Service price';

  @override
  String get pbdTravelFeePending => 'Travel fee (pending)';

  @override
  String get pbdTravelFee => 'Travel fee';

  @override
  String get pbdQuoteEyebrow => 'Quote a travel fee';

  @override
  String pbdQuoteTitle(String name) {
    return 'How much to reach $name\'s address?';
  }

  @override
  String pbdQuotePassThrough(String amount) {
    return 'This is pass-through — AIWA doesn\'t take commission on the travel fee, only the $amount service price.';
  }

  @override
  String get currencyEgp => 'EGP';

  @override
  String get pbdSendQuote => 'Send quote';

  @override
  String get svcEyebrow => 'Your menu';

  @override
  String get svcNew => 'New';

  @override
  String get svcEmpty => 'No services yet';

  @override
  String get svcEmptyBody => 'Add what you offer so customers can book it.';

  @override
  String get svcStartsAt => 'Starts at';

  @override
  String get svcFixedPrice => 'Fixed price';

  @override
  String get svcHidden => 'Hidden';

  @override
  String get svcNewService => 'New service';

  @override
  String get svcEditService => 'Edit service';

  @override
  String get svcName => 'Name';

  @override
  String get svcPrice => 'Price (EGP)';

  @override
  String get svcDuration => 'Duration (min)';

  @override
  String get svcHide => 'Hide';

  @override
  String get svcHiddenToast => 'Service hidden.';

  @override
  String get commonSave => 'Save';

  @override
  String get svcSavedToast => 'Service saved.';

  @override
  String get schedEyebrow => 'Weekly availability';

  @override
  String schedTip(String tip) {
    return '$tip Tap any day to add multiple time blocks, breaks, or one-off availability changes.';
  }

  @override
  String get schedTipLabel => 'Tip:';

  @override
  String get schedClosed => 'Closed';

  @override
  String get schedDecrease => 'Decrease buffer';

  @override
  String get schedIncrease => 'Increase buffer';

  @override
  String get schedBufferTitle => 'Travel buffer between bookings';

  @override
  String get schedBufferBody =>
      'Blocks slots too close together for home visits.';

  @override
  String staffNameSchedule(String name) {
    return '$name\'s schedule';
  }

  @override
  String get staffShopPlan => 'Shop plan';

  @override
  String get staffTitle => 'Staff & availability';

  @override
  String get commonAdd => 'Add';

  @override
  String get staffEmpty => 'No staff yet';

  @override
  String get staffEmptyBody => 'Add the people who take bookings at your shop.';

  @override
  String get staffSkills => 'Skills';

  @override
  String get staffOff => 'Off';

  @override
  String staffEditSchedule(String name) {
    return 'Edit $name\'s schedule';
  }

  @override
  String get staffAdded => 'Staff member added.';

  @override
  String get staffRole => 'Role';

  @override
  String get staffSkillsHint => 'Separate with commas.';

  @override
  String get walletEyebrow => 'Commission & settlement';

  @override
  String walletSettleTitle(String amount) {
    return 'Report paying $amount?';
  }

  @override
  String get walletSettleBalance => 'I\'ve paid';

  @override
  String get walletSettled =>
      'Payment reported. AIWA finance will confirm it shortly.';

  @override
  String get walletPaymentReported =>
      'Payment reported — waiting for AIWA finance to confirm.';

  @override
  String get walletTitle => 'Wallet';

  @override
  String get walletOwed => 'Wallet balance owed to AIWA';

  @override
  String walletLimit(String amount) {
    return 'Negative limit $amount — settle weekly to keep taking bookings.';
  }

  @override
  String get walletBlocked => 'Blocked from new bookings';

  @override
  String get walletBlockedBody =>
      'You can still finish any job you\'ve already accepted — completing those and settling this balance lifts the block once finance confirms your payment.';

  @override
  String get walletNextSettlement => 'Next settlement';

  @override
  String get walletStatus => 'Status';

  @override
  String get walletLedger => 'Ledger';

  @override
  String get walletNoCommission => 'No commission yet';

  @override
  String get walletNoCommissionBody => 'Completed bookings show up here.';

  @override
  String get walletSettleNow => 'I\'ve paid this balance';

  @override
  String get walletCommission => 'Commission';

  @override
  String walletCommissionBooking(String id) {
    return 'Commission · Booking #$id';
  }

  @override
  String get walletSettledTag => 'Settled';

  @override
  String get walletOverdue => 'Overdue';

  @override
  String get revFilterAll => 'All';

  @override
  String get revFilterNeedsReply => 'Needs reply';

  @override
  String revFilterStars(int n) {
    return '$n star';
  }

  @override
  String get revEyebrow => 'Provider';

  @override
  String get revTitle => 'Reviews';

  @override
  String get revEmptyBody => 'Reviews from completed bookings show up here.';

  @override
  String get revNothingHere => 'Nothing here';

  @override
  String get revNoMatch => 'No reviews match this filter.';

  @override
  String revTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews total',
      one: '1 review total',
    );
    return '$_temp0';
  }

  @override
  String revCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '1 review',
    );
    return '$_temp0';
  }

  @override
  String get revYourReply => 'YOUR REPLY';

  @override
  String get revReplyPublicly => 'Reply publicly';

  @override
  String get revReplyHint => 'Thank them, or explain what happened…';

  @override
  String get revPostReply => 'Post reply';

  @override
  String get galEyebrow => 'Gallery';

  @override
  String get galDeleteTitle => 'Delete this photo?';

  @override
  String get galDeleteBody =>
      'It\'s removed from your public profile straight away. This can\'t be undone.';

  @override
  String get commonDelete => 'Delete';

  @override
  String get galIntro =>
      'Your best work, shown on your public profile. Drag to reorder — the first photo is your cover.';

  @override
  String get galEmptyBody =>
      'Profiles with photos get noticeably more bookings. Add a few examples of your work.';

  @override
  String get galUploadFirst => 'Upload first photo';

  @override
  String get galOneHidden => 'One photo is hidden';

  @override
  String get galOneHiddenBody =>
      'Our team hid a photo that didn\'t match your services. Replace it or contact support if you disagree.';

  @override
  String get galUploading => 'Uploading photo…';

  @override
  String get galCancelUpload => 'Cancel upload';

  @override
  String get galHiddenByMod => 'Hidden by moderation';

  @override
  String get galCover => 'COVER';

  @override
  String get galDeletePhoto => 'Delete photo';

  @override
  String get ppAccount => 'Provider account';

  @override
  String get ppSignOutTitle => 'Sign out of AIWA?';

  @override
  String get ppSignOutBody =>
      'Your bookings stay exactly as they are. You\'ll need your number and a code to sign back in.';

  @override
  String get commonSignOut => 'Sign out';

  @override
  String get commonSignedOut => 'Signed out.';

  @override
  String get ppVacation => 'Vacation / offline mode';

  @override
  String get ppVacationOn => 'You\'re hidden from search.';

  @override
  String get ppVacationOff => 'Pause new bookings temporarily.';

  @override
  String get ppVerified => 'Verified provider';

  @override
  String get ppApproved => 'Approved by AIWA.';

  @override
  String ppApprovedOn(String date) {
    return 'Approved by AIWA on $date.';
  }

  @override
  String get ppBusinessInfo => 'Business info';

  @override
  String ppPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String get ppWallet => 'Wallet & settlement';

  @override
  String get ppNotifications => 'Notifications';

  @override
  String get ppSafety => 'Safety & policies';

  @override
  String get ppWhatsApp => 'WhatsApp support';

  @override
  String get biNameRequired => 'Business name is required.';

  @override
  String get biAddressRequired => 'Add the area so customers can find you.';

  @override
  String get biSaved => 'Business info saved.';

  @override
  String get biBioHint => 'Shown at the top of your public profile.';

  @override
  String get biBaseAddress => 'Base address';

  @override
  String get biServiceRadius => 'Service radius';

  @override
  String get biSurcharge => 'Home-visit surcharge (EGP)';

  @override
  String get biSurchargeHint =>
      'Added on top of the service price for bookings at the customer\'s address.';

  @override
  String get biVerifiedStudio => 'Verified studio';

  @override
  String get biReReview =>
      'Changing your business name or address sends your profile for a quick re-review.';

  @override
  String get commonSaveChanges => 'Save changes';

  @override
  String get tabHome => 'Home';

  @override
  String get tabDiscover => 'Discover';

  @override
  String get tabSaved => 'Saved';

  @override
  String get profGuestTitle => 'Your profile';

  @override
  String get profGuestBody =>
      'Sign in to manage your account, addresses, and notifications.';

  @override
  String get profPersonalInfo => 'Personal info';

  @override
  String get profSavedAddresses => 'Saved addresses';

  @override
  String get profTrustedContacts => 'Trusted contacts';

  @override
  String profTrustedSaved(int count) {
    return '$count saved';
  }

  @override
  String get profNotificationPrefs => 'Notification preferences';

  @override
  String get profLanguage => 'Language';

  @override
  String get profDeleteAccount => 'Delete account';

  @override
  String get profYourAccount => 'Your account';

  @override
  String get profSignOutBody =>
      'Your bookings, saved providers and addresses all stay safe. You\'ll need a code to sign back in.';

  @override
  String get profAccountDeleted => 'Account deleted. Sorry to see you go.';

  @override
  String get profStatBookings => 'Bookings';

  @override
  String get profStatFavorites => 'Favorites';

  @override
  String get profStatReviews => 'Reviews';

  @override
  String get editNameError => 'Enter your full name.';

  @override
  String get editPhoneError => 'Enter a valid Egyptian mobile number.';

  @override
  String get editEmailError => 'That email doesn’t look right.';

  @override
  String get editProfileUpdated => 'Profile updated.';

  @override
  String get editConfirmTitle => 'Confirm it\'s you';

  @override
  String get editConfirmBody => 'Enter your current password to continue.';

  @override
  String get editCurrentPassword => 'Current password';

  @override
  String get editEmailCodeTitle => 'Confirm your new email';

  @override
  String get editEmailConfirmed => 'Email confirmed.';

  @override
  String get editEmailResend => 'Send the code again';

  @override
  String editEmailPending(String email) {
    return 'Waiting for you to confirm $email.';
  }

  @override
  String get editAccount => 'Account';

  @override
  String get editChangePhoto => 'Change photo';

  @override
  String get editPhotoHint => 'JPG or PNG · max 5 MB';

  @override
  String get editYourName => 'Your name';

  @override
  String get editMobile => 'Mobile number';

  @override
  String get editMobileHint =>
      'Changing this sends a verification code to the new number.';

  @override
  String get editTheme => 'Theme';

  @override
  String get editThemeMauve => 'Mauve';

  @override
  String get editThemeCharcoal => 'Charcoal';

  @override
  String get editSaving => 'Saving…';

  @override
  String get addrHome => 'Home';

  @override
  String get addrWork => 'Work';

  @override
  String get addrOther => 'Other';

  @override
  String get addrEmpty => 'No saved addresses';

  @override
  String get addrEmptyBody =>
      'Add your home or work so booking a home visit takes one tap.';

  @override
  String get addrStreetError =>
      'Add the street and area so your provider can find you.';

  @override
  String get addrBuildingError => 'Building number or name is required.';

  @override
  String addrFloorN(String n) {
    return 'Floor $n';
  }

  @override
  String addrAptN(String n) {
    return 'Apt $n';
  }

  @override
  String get addrUpdated => 'Address updated.';

  @override
  String get addrAdded => 'Address added.';

  @override
  String get addrRemove => 'Remove address';

  @override
  String addrDeleteTitle(String label) {
    return 'Delete \"$label\"?';
  }

  @override
  String get addrDeleteBody =>
      'Bookings already made to this address keep their details. You can add it again any time.';

  @override
  String get addrDeleted => 'Address deleted.';

  @override
  String get addrEditTitle => 'Edit address';

  @override
  String get addrNewTitle => 'New address';

  @override
  String get addrLabel => 'Label';

  @override
  String get addrStreet => 'Street & area';

  @override
  String get addrStreetPlaceholder => 'e.g. Road 9, Maadi';

  @override
  String get addrBuilding => 'Building';

  @override
  String get addrFloor => 'Floor';

  @override
  String get addrApt => 'Apt';

  @override
  String get addrLandmark => 'Nearest landmark';

  @override
  String get addrLandmarkPlaceholder => 'e.g. opposite Sakia';

  @override
  String get addrLandmarkHint =>
      'Helps providers find you faster on the first visit.';

  @override
  String get addrNotes => 'Notes for the provider';

  @override
  String get addrNotesPlaceholder => 'Gate code, parking, which bell to ring…';

  @override
  String get addrDefault => 'Default address';

  @override
  String get addrDefaultSub => 'Pre-selected on every home booking';

  @override
  String get addrDeleteThis => 'Delete this address';

  @override
  String get addrSave => 'Save address';

  @override
  String get addrAdd => 'Add address';

  @override
  String get addrPinDropped => 'Pin dropped';

  @override
  String get addrDropPin => 'Drop pin';

  @override
  String get tcContactDefault => 'Contact';

  @override
  String get tcSafety => 'Safety';

  @override
  String get tcRemoveTitle => 'Remove this contact?';

  @override
  String get tcRemoveBody =>
      'They\'ll no longer be alerted if you press SOS during a home service.';

  @override
  String get tcRemove => 'Remove';

  @override
  String get tcBannerTitle => 'Alerted the moment you press SOS';

  @override
  String get tcBannerBody =>
      'They receive your live location by SMS. Nothing is shared with them at any other time.';

  @override
  String get tcEmpty => 'No trusted contact yet';

  @override
  String get tcEmptyBody =>
      'Add someone you\'d want alerted if you ever felt unsafe during a home service.';

  @override
  String get tcAddContact => 'Add a contact';

  @override
  String get tcNew => 'New trusted contact';

  @override
  String get tcNameError => 'Enter their name.';

  @override
  String get tcNamePlaceholder => 'Their full name';

  @override
  String get tcPhoneError => 'Enter a valid mobile number.';

  @override
  String get tcRelationship => 'Relationship';

  @override
  String get tcRelationshipPlaceholder => 'Sister, friend, partner…';

  @override
  String get tcAdd => 'Add contact';

  @override
  String get tcAddAnother => 'Add another contact';

  @override
  String get supOpening => 'Opening WhatsApp…';

  @override
  String get supNumber => 'WhatsApp number';

  @override
  String get supHours => 'Support hours';

  @override
  String get supEmail => 'Email fallback';

  @override
  String get supLanguages => 'Languages';

  @override
  String get supEyebrow => 'Support';

  @override
  String get supTitle => 'Talk to AIWA';

  @override
  String get supHero => 'Chat with a human on WhatsApp.';

  @override
  String get supHeroBody =>
      'We answer in Arabic or English, usually within a few minutes during support hours.';

  @override
  String get supOpenWhatsApp => 'Open WhatsApp';

  @override
  String get supCommonQuestions => 'Common questions';

  @override
  String get supQCancel => 'How do I cancel a booking?';

  @override
  String get supQPaid => 'When does the provider get paid?';

  @override
  String get supQNoShow => 'My provider didn\'t show up';

  @override
  String get supQBecome => 'How do I become a provider?';

  @override
  String get polTerms => 'Terms of service';

  @override
  String get polSafety => 'Safety policy';

  @override
  String get polSafetySub => 'Home visits, ID checks, SOS';

  @override
  String get polCancel => 'Cancellation policy';

  @override
  String get polCancelSub => 'Cutoffs, penalties, no-shows';

  @override
  String get polPrivacy => 'Privacy policy';

  @override
  String get polPrivacySub => 'What we store and for how long';

  @override
  String get polConduct => 'Community conduct';

  @override
  String get polConductSub => 'What we expect from everyone';

  @override
  String get polUpToDate => 'You\'re up to date';

  @override
  String polUpToDateBody(Object version) {
    return 'You accepted the current terms (v$version). We\'ll tell you if anything changes.';
  }

  @override
  String get polUpdated => 'Updated terms to review';

  @override
  String get polReview => 'Review';

  @override
  String polAccepted(Object version) {
    return 'v$version · accepted';
  }

  @override
  String get polNotAccepted => 'Not accepted yet';

  @override
  String polPlaceholder(String doc) {
    return 'This is the full text of the $doc, shown in the customer\'s language. It stays readable offline and records which version you accepted, so we only ask you again when something material changes.';
  }

  @override
  String get polSafetyTools => 'Your safety tools';

  @override
  String get polTrustedSub => 'Alerted if you press SOS';

  @override
  String get polHowSos => 'How SOS works';

  @override
  String get polHowSosSub => 'What happens when you press it';

  @override
  String get polDownloadPdf => 'Download PDF';

  @override
  String get notifInbox => 'Inbox';

  @override
  String notifNewSuffix(int count) {
    return '· $count new';
  }

  @override
  String get notifMarkAllRead => 'Mark all read';

  @override
  String get notifCaughtUp => 'You\'re all caught up';

  @override
  String get notifCaughtUpBody =>
      'Booking updates, reviews and news from AIWA will show up here.';

  @override
  String get notifEarlier => 'Earlier';

  @override
  String get notifJustNow => 'Just now';

  @override
  String notifMinAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n min ago',
    );
    return '$_temp0';
  }

  @override
  String notifHrAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n hr ago',
    );
    return '$_temp0';
  }

  @override
  String get npPush => 'Push notifications';

  @override
  String get npSms => 'SMS';

  @override
  String get npChannels => 'Channels';

  @override
  String get npQuietHours => 'Quiet hours';

  @override
  String get npMute => 'Mute non-urgent notifications';

  @override
  String get npFrom => 'From';

  @override
  String get npTo => 'To';

  @override
  String get tagPunctual => 'Punctual';

  @override
  String get tagSkilled => 'Skilled';

  @override
  String get tagFriendly => 'Friendly';

  @override
  String get tagCleanStudio => 'Clean studio';

  @override
  String get tagWorthPrice => 'Worth the price';

  @override
  String get tagGreatHair => 'Great with hair';

  @override
  String get reviewTapStar => 'Tap a star';

  @override
  String get reviewDisappointing => 'Disappointing';

  @override
  String get reviewBelow => 'Below expectations';

  @override
  String get reviewGood => 'Good';

  @override
  String get reviewGreat => 'Great';

  @override
  String get reviewOutstanding => 'Outstanding';

  @override
  String get reviewThanks => 'Thanks — your review is live.';

  @override
  String get reviewEyebrow => 'Leave a review';

  @override
  String get reviewTitle => 'How was it?';

  @override
  String get reviewQuickTags => 'Quick tags (optional)';

  @override
  String get reviewStoodOut => 'Tell others what stood out';

  @override
  String get reviewHint =>
      'Optional — your review will be public on the provider\'s profile.';

  @override
  String get reviewSubmit => 'Submit review';

  @override
  String get savedGuestTitle => 'Save your favorites';

  @override
  String get savedGuestBody =>
      'Sign in to save providers you love and book them faster next time.';

  @override
  String get savedEyebrow => 'Your favorites';

  @override
  String get savedEmpty => 'No favorites yet';

  @override
  String get savedEmptyBody =>
      'Tap the heart on any provider to save them here and book again in one tap.';

  @override
  String get savedBrowse => 'Browse providers';

  @override
  String get savedBookAgain => 'Book again';

  @override
  String get permLocEyebrow => 'One quick permission';

  @override
  String get permLocTitle => 'Find beauty pros near you.';

  @override
  String get permLocBody =>
      'AIWA uses your location to show providers within your chosen radius and to share live arrival updates during a home visit.';

  @override
  String get permLocP1 => 'Only used while the app is open';

  @override
  String get permLocP2 => 'Never shared with other customers';

  @override
  String get permLocP3 => 'You can pick an area manually instead';

  @override
  String get permLocAllow => 'Allow location';

  @override
  String get permLocDeny => 'Choose my area manually';

  @override
  String get permNotifEyebrow => 'Stay in the loop';

  @override
  String get permNotifTitle => 'Know the moment you’re confirmed.';

  @override
  String get permNotifBody =>
      'We’ll tell you when a provider accepts, when they’re on the way, and when it’s time for your appointment.';

  @override
  String get permNotifP1 => 'Booking updates only by default';

  @override
  String get permNotifP2 => 'Set quiet hours any time';

  @override
  String get permNotifP3 => 'Turn off individual channels in settings';

  @override
  String get permNotifAllow => 'Turn on notifications';

  @override
  String get permNotNow => 'Not now';

  @override
  String get permCamEyebrow => 'Verification step';

  @override
  String get permCamTitle => 'We need your camera.';

  @override
  String get permCamBody =>
      'To verify providers we capture your national ID and a live selfie. This keeps every customer safe.';

  @override
  String get permCamP1 => 'Documents are encrypted and private';

  @override
  String get permCamP2 => 'Reviewed only by our verification team';

  @override
  String get permCamP3 => 'Never shown on your public profile';

  @override
  String get permCamAllow => 'Open camera';

  @override
  String get permCamDeny => 'Upload from files instead';

  @override
  String get permDeniedCamTitle => 'Camera access is off.';

  @override
  String get permDeniedCamBody =>
      'Verification needs a live selfie. Enable the camera in Settings, or upload photos from your files.';

  @override
  String get permDeniedCamFallback => 'Upload from files';

  @override
  String get permDeniedNotifTitle => 'Notifications are off.';

  @override
  String get permDeniedNotifBody =>
      'You’ll still see every update in your in-app inbox, but we can’t alert you when a provider is on the way.';

  @override
  String get permDeniedNotifFallback => 'Use the in-app inbox';

  @override
  String get permDeniedLocTitle => 'Location is off.';

  @override
  String get permDeniedLocBody =>
      'Turn it on in Settings, or pick your area manually and we’ll search from there.';

  @override
  String get permDeniedLocFallback => 'Pick my area manually';

  @override
  String get permNeeded => 'Permission needed';

  @override
  String get permOpenSettings => 'Open Settings';

  @override
  String get commonDone => 'Done';

  @override
  String get delCantUndo => 'This can\'t be undone';

  @override
  String get delTitle => 'Delete your account?';

  @override
  String delBody(String phrase) {
    return 'Your data will be anonymized and any active bookings cancelled. Type $phrase to confirm.';
  }

  @override
  String get delPhrase => 'DELETE';

  @override
  String get errLoadTitle => 'Couldn\'t load this';

  @override
  String get errLoadBody =>
      'Something went wrong on our side. Give it another try.';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String get guestTitle => 'Sign in to continue';

  @override
  String get guestBrowsing => 'Browsing as guest';

  @override
  String get guestSignIn => 'Sign in or create account';

  @override
  String get offlineBanner => 'No connection — showing saved data';

  @override
  String get commonRetry => 'Retry';

  @override
  String get reasonNotePlaceholder => 'Tell us what happened (optional)';

  @override
  String get reasonKeepBooking => 'Keep booking';

  @override
  String get endOfList => 'That\'s everything';

  @override
  String get slotJustTaken => 'Just taken';

  @override
  String get slotTitle => 'Someone booked that slot.';

  @override
  String slotBody(String name) {
    return 'It went in the last moment. Here\'s what $name still has free today.';
  }

  @override
  String get slotPickAnotherDay => 'Pick another day';

  @override
  String get slotBook => 'Book slot';

  @override
  String slotBookTime(String time) {
    return 'Book $time';
  }

  @override
  String get sysSignedOut => 'Signed out';

  @override
  String get sysSessionTitle => 'Your session expired.';

  @override
  String get sysSessionBody =>
      'For your security we sign you out after a period of inactivity. Your bookings and saved providers are all still here.';

  @override
  String get sysSignInAgain => 'Sign in again';

  @override
  String get sysLocked => 'Account locked';

  @override
  String get sysLockedTitle => 'This account is locked.';

  @override
  String get sysLockedBody =>
      'Your account has been suspended by our team. Our support agents can explain why and what happens next.';

  @override
  String get sysContactSupport => 'Contact support';

  @override
  String get sysBackToSignIn => 'Back to sign in';

  @override
  String get sysNoAccess => 'No access';

  @override
  String get sysNoAccessTitle => 'You can\'t open this.';

  @override
  String get sysNoAccessBody =>
      'This area belongs to a different kind of account. If you think that\'s wrong, contact support.';

  @override
  String get sysGoBack => 'Go back';

  @override
  String get sysNotFound => 'Not found';

  @override
  String get sysNotFoundTitle => 'This page isn\'t available.';

  @override
  String get sysNotFoundBody =>
      'It may have been cancelled, removed, or the link is out of date.';

  @override
  String get trackReschedule => 'Reschedule';

  @override
  String get rescheduleTitle => 'Pick a new time.';

  @override
  String rescheduleBody(String name, String date) {
    return '$name is free at these times on $date.';
  }

  @override
  String get rescheduleNoSlots => 'No free times that day. Try another date.';

  @override
  String rescheduledToast(String time) {
    return 'Moved to $time';
  }

  @override
  String get reportsTitle => 'My reports';

  @override
  String get reportsEmpty => 'You haven\'t reported anything.';

  @override
  String reportsResolution(String note) {
    return 'AIWA: $note';
  }

  @override
  String get reportStatusOpen => 'Received';

  @override
  String get reportStatusReview => 'Under review';

  @override
  String get reportStatusResolved => 'Resolved';

  @override
  String get staffEditDetails => 'Edit details';

  @override
  String get staffServicesHint => 'Does these services (none picked = all)';

  @override
  String get staffSaved => 'Staff member updated.';

  @override
  String get staffDeactivate => 'Remove from bookings';

  @override
  String get staffDeactivated => 'Staff member deactivated.';

  @override
  String get linkOpenFailed =>
      'No app on this phone could open that. Please try another way.';

  @override
  String get a11yChat => 'Open chat';

  @override
  String get a11ySend => 'Send message';

  @override
  String get a11yEdit => 'Edit';

  @override
  String get a11yShare => 'Share';

  @override
  String get a11ySave => 'Save to favourites';

  @override
  String get a11ySaved => 'Saved to favourites';
}
