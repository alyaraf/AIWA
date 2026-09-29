// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get authTagline => 'الجمال والعناية، بالقرب منك.';

  @override
  String get authTaglineSub =>
      'حلّاقون ومصففو شعر وفنانو أظافر ومراكز سبا موثوقون — على بُعد لمسة واحدة.';

  @override
  String get authChooseLanguage => 'اختر لغتك';

  @override
  String get authBrowseAsGuest => 'تصفّح كضيف ←';

  @override
  String get authChoiceProviderEyebrow => 'مقدّم خدمة · أهلًا بك';

  @override
  String get authChoiceCustomerEyebrow => 'عميل · أهلًا بك';

  @override
  String get authChoiceProviderTitle => 'أدِر صالونك مع AIWA.';

  @override
  String get authChoiceProviderSubtitle =>
      'أدِر حجوزاتك ومواعيد عملك وملفك الموثّق — كل ذلك في تطبيق واحد.';

  @override
  String get authChoiceProviderSignUp => 'أنشئ صالونًا جديدًا';

  @override
  String get authChoiceCustomerSignUp => 'أنشئ حسابًا';

  @override
  String get authChoiceProviderHint => 'يلزم التحقق من الهوية.';

  @override
  String get authChoiceCustomerHint => 'يستغرق دقيقة تقريبًا.';

  @override
  String get authHaveAccount => 'لديّ حساب بالفعل';

  @override
  String get authSignInWithPhoneOrEmail =>
      'سجّل الدخول برقم الهاتف أو البريد الإلكتروني.';

  @override
  String get authSafetyPolicy => 'محمي بسياسة الأمان من AIWA';

  @override
  String get authGatePerkHistory => 'سجل حجوزاتك في مكان واحد';

  @override
  String get authGatePerkTracking => 'متابعة مباشرة للحالة وتتبّع للأمان';

  @override
  String get authGatePerkFavorites => 'احفظ مقدّمي الخدمة المفضّلين';

  @override
  String get authCreateAccount => 'إنشاء حساب';

  @override
  String get authGateEyebrow => 'خطوة واحدة سريعة';

  @override
  String get authGateTitle => 'سجّل الدخول لتحجز.';

  @override
  String get authGateBody =>
      'التصفّح متاح للجميع، أما الحجز فيتطلب حسابًا حتى يتمكن مقدّمو الخدمة من التواصل معك.';

  @override
  String authStepOf(int step, int total) {
    return 'الخطوة $step من $total';
  }

  @override
  String get authModePhone => 'الهاتف';

  @override
  String get authModeEmail => 'البريد الإلكتروني';

  @override
  String get errorNoInternet => 'لا يوجد اتصال بالإنترنت';

  @override
  String get errorTimeout => 'انتهت مهلة الاتصال';

  @override
  String get errorGeneric => 'حدث خطأ ما';

  @override
  String get errorUnauthorized =>
      'انتهت صلاحية الجلسة. يُرجى تسجيل الدخول مجددًا.';

  @override
  String get errorNotSupported => 'هذه الميزة غير متاحة بعد.';

  @override
  String get errorLoginFailed => 'تعذّر تسجيل الدخول';

  @override
  String get errorRegistrationFailed => 'تعذّر إنشاء الحساب';

  @override
  String get errorSendOtpFailed => 'تعذّر إرسال رمز التحقق';

  @override
  String get errorInvalidOtp => 'رمز التحقق غير صحيح';

  @override
  String authWelcomeBackName(String name) {
    return 'أهلًا بعودتك يا $name.';
  }

  @override
  String get authSignIn => 'تسجيل الدخول';

  @override
  String get authNewToAiwa => 'جديد على AIWA؟ ';

  @override
  String get authProviderSignIn => 'دخول مقدّمي الخدمة';

  @override
  String get authWelcomeBack => 'أهلًا بعودتك';

  @override
  String get authSignInTitle => 'سجّل الدخول إلى AIWA';

  @override
  String get authSignInSubtitlePhone =>
      'استخدم الرقم وكلمة المرور اللذين سجّلت بهما.';

  @override
  String get authSignInSubtitleEmail =>
      'استخدم البريد الإلكتروني وكلمة المرور اللذين سجّلت بهما.';

  @override
  String get authPhoneNumber => 'رقم الهاتف';

  @override
  String get authPassword => 'كلمة المرور';

  @override
  String get authRememberMe => 'تذكّرني';

  @override
  String get authForgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get authSendCode => 'إرسال الرمز';

  @override
  String get authWhatsYourPhone => 'ما رقم هاتفك؟';

  @override
  String get authWhatsYourEmail => 'ما بريدك الإلكتروني؟';

  @override
  String get authSendCodeSubtitle =>
      'سنرسل إليك رمزًا مكوّنًا من 6 أرقام للتأكيد.';

  @override
  String authAgreeTerms(String terms, String policy) {
    return 'بالمتابعة فإنك توافق على $terms و$policy لدى AIWA.';
  }

  @override
  String get authTermsLink => 'الشروط';

  @override
  String get authSafetyPolicyLink => 'سياسة الأمان';

  @override
  String get authVerify => 'تحقّق';

  @override
  String get authEnterCode => 'أدخل الرمز';

  @override
  String authCodeSentTo(String destination) {
    return 'أرسلنا رمزًا مكوّنًا من 6 أرقام إلى $destination.';
  }

  @override
  String authResendIn(String time) {
    return 'إعادة إرسال الرمز خلال $time';
  }

  @override
  String get authResendCode => 'إعادة إرسال الرمز';

  @override
  String get authOtpHelp =>
      'لم يصلك الرمز؟ تحقّق من الرقم، ثم اضغط «إعادة إرسال الرمز» بعد انتهاء العدّاد.';

  @override
  String get authResetPassword => 'إعادة تعيين كلمة المرور';

  @override
  String get authWhereSendCode => 'إلى أين نرسل الرمز؟';

  @override
  String get authSendResetCode => 'إرسال رمز إعادة التعيين';

  @override
  String get authCheckMessages => 'تفقّد رسائلك.';

  @override
  String get authCheckInbox => 'تفقّد بريدك الوارد.';

  @override
  String get authAlmostDone => 'أوشكت على الانتهاء';

  @override
  String get authSetNewPassword => 'عيّن كلمة مرور جديدة.';

  @override
  String get authCodePlaceholder => 'رمز من 6 أرقام';

  @override
  String get authNewPassword => 'كلمة المرور الجديدة';

  @override
  String get authConfirmPassword => 'تأكيد كلمة المرور';

  @override
  String get authPasswordResetDone =>
      'تمت إعادة تعيين كلمة المرور. يُرجى تسجيل الدخول.';

  @override
  String get commonContinue => 'متابعة';

  @override
  String get authSetupTitle => 'أعِدّ حسابك';

  @override
  String get authSetupSubtitle =>
      'اسم وكلمة مرور — هذا كل شيء. سنضيف الباقي لاحقًا.';

  @override
  String get authNameError => 'أدخل اسمك الأول واسم العائلة';

  @override
  String get authEmailError => 'يبدو أن البريد الإلكتروني غير صالح';

  @override
  String get authPasswordMinError => '6 أحرف على الأقل';

  @override
  String get authPasswordHint => '6 أحرف على الأقل.';

  @override
  String get authStrengthWeak => 'ضعيفة';

  @override
  String get authStrengthOkay => 'مقبولة';

  @override
  String get authStrengthGood => 'جيدة';

  @override
  String get authStrengthStrong => 'قوية';

  @override
  String get authFullName => 'الاسم الكامل';

  @override
  String get authNamePlaceholder => 'مثال: ليلى حسن';

  @override
  String get authNameHint => 'اسمك الحقيقي — يظهر لمقدّمي الخدمة في الحجوزات.';

  @override
  String get authEmailHint => 'للإيصالات واستعادة الحساب.';

  @override
  String get authContinueWithoutPhoto => 'المتابعة بدون صورة';

  @override
  String get authMakeItYours => 'اجعله على ذوقك';

  @override
  String get authMakeItYoursSub =>
      'أضف صورة واختر ألوانك. يمكنك تغيير الاثنين لاحقًا.';

  @override
  String get authUploadPhoto => 'ارفع صورة';

  @override
  String get authReplacePhoto => 'استبدل الصورة';

  @override
  String get authSigningUpAs => 'أسجّل بصفتي';

  @override
  String get authWoman => 'امرأة';

  @override
  String get authMan => 'رجل';

  @override
  String get authPaletteNote => 'يحدّد هذا ألوان تطبيقك.';

  @override
  String get authRoleCustomerTitle => 'أريد الحجز';

  @override
  String get authRoleCustomerSub =>
      'اعثر على حلّاق أو مصفف شعر أو فنان أظافر أو سبا بالقرب منك.';

  @override
  String get authRolePerkBrowse => 'تصفّح مقدّمي خدمة موثّقين';

  @override
  String get authRolePerkCash => 'الدفع نقدًا عند الزيارة';

  @override
  String get authRolePerkTrack => 'تابع حجزك مباشرةً';

  @override
  String get authRoleProviderTitle => 'أقدّم خدمات';

  @override
  String get authRoleProviderSub => 'استقبل حجوزات من العملاء في منطقتك.';

  @override
  String get authRolePerkId => 'يلزم التحقق من الهوية';

  @override
  String get authRolePerkManage => 'أدِر خدماتك ومواعيد عملك';

  @override
  String get authRolePerkPayouts => 'مدفوعات نقدية';

  @override
  String get authWelcomeToAiwa => 'مرحبًا بك في AIWA';

  @override
  String get authHowUsing => 'كيف ستستخدم\nAIWA؟';

  @override
  String get authChangeLater => 'يمكنك تغيير ذلك لاحقًا من ملفك الشخصي.';

  @override
  String get authTermsVerifiedTitle => 'مقدّمو خدمة موثّقون فقط';

  @override
  String get authTermsVerifiedBody =>
      'نتحقق من كل مقدّم خدمة ببطاقة الرقم القومي وصورة سيلفي حيّة قبل أن يستقبل أي حجز.';

  @override
  String get authTermsPrivateTitle => 'بياناتك تبقى خاصة';

  @override
  String get authTermsPrivateBody =>
      'لا نشارك رقم هاتفك وعنوانك مع مقدّم الخدمة إلا بعد تأكيدك الحجز معه.';

  @override
  String get authTermsFlagTitle => 'يمكنك دائمًا الإبلاغ أو تقديم شكوى';

  @override
  String get authTermsFlagBody =>
      'إذا شعرت بأن شيئًا ليس على ما يرام، أبلِغ عن مقدّم الخدمة أو افتح شكوى. يراجع فريقنا كل بلاغ.';

  @override
  String get authTermsCashTitle => 'نقدًا فقط — حاليًا';

  @override
  String get authTermsCashBody =>
      'في هذا الإصدار تدفع لمقدّم الخدمة نقدًا مباشرةً بعد الخدمة. الدفع الإلكتروني قادم قريبًا.';

  @override
  String get authAgreeContinue => 'موافقة ومتابعة';

  @override
  String get authTermsTitle => 'بعض الوعود\nقبل أن تبدأ.';

  @override
  String get authTermsSubtitle =>
      'شروط العملاء وسياسة الأمان لدى AIWA بكلمات بسيطة.';

  @override
  String authTermsAgree(String terms, String policy) {
    return 'قرأت $terms و$policy لدى AIWA وأوافق عليها.';
  }

  @override
  String get authCustomerTermsLink => 'شروط العملاء';

  @override
  String get authTermsAccepted => 'شكرًا — تم قبول الشروط.';

  @override
  String get authPoliciesUpdated => 'تم تحديث السياسات';

  @override
  String get authTermsUpdatedTitle => 'حدّثنا شروطنا.';

  @override
  String get authTermsUpdatedBody =>
      'تغيّرت شروط AIWA وسياسة الأمان في 20 مايو 2026 — وبشكل أساسي فيما يخص غرامات الإلغاء والتحقق من مقدّمي الخدمة. يُرجى الموافقة عليها مجددًا لمواصلة الحجز.';

  @override
  String authTermsVersion(Object version) {
    return 'الإصدار $version';
  }

  @override
  String get categoryHair => 'الشعر';

  @override
  String get categoryNails => 'الأظافر';

  @override
  String get categorySpa => 'السبا';

  @override
  String get categoryMakeup => 'المكياج';

  @override
  String get categoryLashes => 'الرموش';

  @override
  String get categorySkin => 'البشرة';

  @override
  String get categoryMassage => 'المساج';

  @override
  String get categoryOther => 'أخرى';

  @override
  String get prefsSave => 'حفظ التفضيلات';

  @override
  String get prefsLastStep => 'الخطوة الأخيرة';

  @override
  String get prefsTitle => 'أين نبحث لك\nعن مقدّمي الخدمة؟';

  @override
  String get prefsSubtitle =>
      'نستخدم هذه الإعدادات لاختيار مقدّمي الخدمة الذين نعرضهم لك. يمكنك تغييرها في أي وقت من ملفك الشخصي.';

  @override
  String get commonUseGps => 'حدّد موقعي';

  @override
  String get prefsSearchRadius => 'نطاق البحث';

  @override
  String prefsRadiusRange(int min, int max) {
    return '$min–$max كم';
  }

  @override
  String prefsMinKm(int km) {
    return 'الأدنى · $km كم';
  }

  @override
  String prefsMaxKm(int km) {
    return 'الأقصى · $km كم';
  }

  @override
  String get prefsAppLanguage => 'لغة التطبيق';

  @override
  String get authAccountCreatedReview =>
      'تم إنشاء الحساب. التحقق قيد المراجعة.';

  @override
  String get provBizTitle => 'أعِدّ صالونك';

  @override
  String get provBizSubtitle => 'سيرى العملاء هذه المعلومات في ملفك.';

  @override
  String get provBizName => 'اسم النشاط';

  @override
  String get provBizNamePlaceholder => 'مثال: ستوديو نادية';

  @override
  String get provBizType => 'نوع النشاط';

  @override
  String get provBizIndividual => 'فردي';

  @override
  String get provBizShop => 'محل / صالون';

  @override
  String get provBizShopNote =>
      'يمكن للمحلات إضافة موظفين لكلٍّ منهم تقويمه الخاص.';

  @override
  String get provBizStaff => 'الموظفون';

  @override
  String get commonOptional => 'اختياري';

  @override
  String provBizStaffName(int number) {
    return 'اسم الموظف $number';
  }

  @override
  String get provBizAddStaff => 'إضافة موظف';

  @override
  String get provBizStaffNote =>
      'أضف الفريق الذي سيستقبل الحجوزات. يمكنك إضافة المزيد لاحقًا.';

  @override
  String get provBizBio => 'نبذة قصيرة';

  @override
  String get provBizBioPlaceholder =>
      'خبيرة صبغات تدرّبت في القاهرة بلمسة ناعمة وعصرية…';

  @override
  String get provBizBioHint => 'سطران أو ثلاثة عمّا يميّزك.';

  @override
  String get provBizPrimaryCategory => 'الفئة الرئيسية';

  @override
  String get provBizPickOne => 'اختر الخدمة التي تقدّمها أكثر.';

  @override
  String get provBizAddress => 'عنوان الصالون';

  @override
  String get provBizAddressPlaceholder => 'الشارع، الحي، المدينة';

  @override
  String provBizGpsLocked(String lat, String lng) {
    return 'تم تحديد الموقع — $lat، $lng';
  }

  @override
  String get provBizNoGps => 'لم يُحدَّد الموقع — اضغط «حدّد موقعي»';

  @override
  String get provBizNearby => 'يمكن للعملاء القريبين العثور عليك';

  @override
  String get provPendingEyebrow => 'تم إرسال طلب التحقق';

  @override
  String get provPendingTitle => 'نراجع\nمستنداتك الآن.';

  @override
  String provPendingBody(String duration) {
    return 'تستغرق معظم المراجعات $duration. سيصلك إشعار فور موافقة AIWA على صالونك — وبعدها يمكنك استقبال الحجوزات.';
  }

  @override
  String get provPendingUnder24h => 'أقل من 24 ساعة';

  @override
  String get provPendingIdReceived => 'تم استلام وجهَي بطاقة الهوية';

  @override
  String get provPendingSelfieReceived => 'تم استلام صورة السيلفي الحيّة';

  @override
  String get provPendingAdminReview => 'مراجعة الإدارة جارية';

  @override
  String get provPendingExplore => 'استكشف التطبيق أثناء الانتظار';

  @override
  String get provPendingBrowseNote =>
      'يمكنك التصفّح، لكن الحجوزات تُفتح بعد التحقق.';

  @override
  String get provStatusCheck => 'تحقق من الحالة';

  @override
  String get provInfoTitle => 'تحتاج AIWA إلى المزيد منك';

  @override
  String get provRejectedTitle => 'لم تتم الموافقة بعد';

  @override
  String get provRejectedBody =>
      'لم يتمكن فريقنا من اعتماد مستنداتك. أصلح المشكلة الموضحة أدناه وأرسلها مرة أخرى.';

  @override
  String get provSuspendedTitle => 'حساب مقدم الخدمة موقوف';

  @override
  String get provSuspendedBody =>
      'لا يمكنك استقبال الحجوزات حاليًا. تواصل مع الدعم لمعرفة السبب والخطوة التالية.';

  @override
  String get provResubmit => 'أعد إرسال المستندات';

  @override
  String get provAdminNote => 'ملاحظة من AIWA';

  @override
  String get provDocsResent => 'تم إرسال المستندات. سنراجعها قريبًا.';

  @override
  String get provVerifySubmit => 'إرسال للمراجعة';

  @override
  String get provVerifyTitle => 'تحقّق من هويتك';

  @override
  String get provVerifySubtitle =>
      'ارفع بطاقة الرقم القومي وصورة سيلفي حيّة. تراجع AIWA كل مقدّم خدمة قبل أن يستقبل الحجوزات.';

  @override
  String get provVerifyIdFront => 'بطاقة الرقم القومي — الوجه الأمامي';

  @override
  String get provVerifyIdFrontHint =>
      'الوجه الأمامي لبطاقة هويتك الرسمية. تأكّد من ظهور الزوايا الأربع كاملة.';

  @override
  String get provVerifyIdBack => 'بطاقة الرقم القومي — الوجه الخلفي';

  @override
  String get provVerifyIdBackHint => 'الوجه الخلفي للبطاقة نفسها.';

  @override
  String get provVerifySelfie => 'سيلفي حيّة';

  @override
  String get provVerifySelfieHint =>
      'صورة واضحة لوجهك تُلتقط الآن، نقارنها ببطاقة هويتك.';

  @override
  String get provVerifyPrivate =>
      'مستنداتك خاصة. لا يطّلع عليها إلا مسؤولو AIWA الذين يراجعون حسابك، ولا تُعرض على العملاء أبدًا.';

  @override
  String provVerifyUploaded(String label) {
    return '$label: تم الرفع · اضغط للاستبدال';
  }

  @override
  String moneyEgp(String amount) {
    return '$amount ج.م';
  }

  @override
  String whenToday(String time) {
    return 'اليوم · $time';
  }

  @override
  String whenTomorrow(String time) {
    return 'غدًا · $time';
  }

  @override
  String whenYesterday(String time) {
    return 'أمس · $time';
  }

  @override
  String durationMinutes(int m) {
    String _temp0 = intl.Intl.pluralLogic(
      m,
      locale: localeName,
      other: '$m دقيقة',
      many: '$m دقيقة',
      few: '$m دقائق',
      two: 'دقيقتان',
      one: 'دقيقة واحدة',
      zero: '$m دقيقة',
    );
    return '$_temp0';
  }

  @override
  String durationHours(int h) {
    String _temp0 = intl.Intl.pluralLogic(
      h,
      locale: localeName,
      other: '$h ساعة',
      many: '$h ساعة',
      few: '$h ساعات',
      two: 'ساعتان',
      one: 'ساعة',
      zero: '$h ساعة',
    );
    return '$_temp0';
  }

  @override
  String durationHoursMinutes(int h, int m) {
    return '$h س $m د';
  }

  @override
  String get bookNowOfflineEyebrow => 'غير متصل';

  @override
  String bookNowOfflineTitle(String name) {
    return '$name غير متصل الآن.';
  }

  @override
  String get bookNowOfflineBody =>
      'سيظهر متاحًا مجددًا فور عودته للاتصال. يمكنك تجربة «احجز الآن» لاحقًا، أو اختيار موعد مجدول الآن.';

  @override
  String get bookNowBusyEyebrow => 'محجوز بالكامل';

  @override
  String bookNowBusyTitle(String name) {
    return '$name مشغول مع عميل آخر.';
  }

  @override
  String get bookNowBusyBody =>
      'كل مواعيد «احجز الآن» محجوزة للفترة القادمة. غالبًا ما يكون حجز موعد لاحق اليوم أسرع من الانتظار.';

  @override
  String get bookNowVacationEyebrow => 'في إجازة';

  @override
  String bookNowVacationTitle(String name) {
    return '$name في إجازة.';
  }

  @override
  String get bookNowVacationBody =>
      'أوقف جميع الحجوزات مؤقتًا. سنعرضه مجددًا فور عودته.';

  @override
  String get bookNowPausedEyebrow => 'متوقف مؤقتًا';

  @override
  String bookNowPausedTitle(String name) {
    return 'لا يستطيع $name استقبال حجوزات جديدة الآن.';
  }

  @override
  String get bookNowPausedBody =>
      'يقوم بتسوية رصيد مستحق لدى AIWA، وسيُرفع الإيقاف تلقائيًا بعد السداد — حاول مجددًا قريبًا.';

  @override
  String get bookNowUnavailableEyebrow => 'غير متاح';

  @override
  String bookNowUnavailableTitle(String name) {
    return 'لا يستقبل $name حجوزات حاليًا.';
  }

  @override
  String get bookNowUnavailableBody =>
      'مقدّم الخدمة أو الموظف أو الخدمة غير نشط مؤقتًا. جرّب مقدّم خدمة آخر بالقرب منك.';

  @override
  String get bookNowChecking => 'جارٍ التحقق من التوفّر…';

  @override
  String bookNowConfirming(String name) {
    return 'نتأكد من أن $name يستطيع استقبال هذا الحجز الآن.';
  }

  @override
  String get bookNowChooseScheduled => 'اختر موعدًا مجدولًا';

  @override
  String get bookNowSeeOthers => 'اعرض مقدّمي خدمة آخرين بالقرب منك';

  @override
  String get bookingPlaced => 'تم إرسال الحجز';

  @override
  String bookingSaidAiwa(String aiwa, String name) {
    return 'قلتَ $aiwa، وأبلغنا $name.';
  }

  @override
  String get bookingAiwaWord => 'أيوه';

  @override
  String bookingWhenLong(String date, String time) {
    return '$date الساعة $time';
  }

  @override
  String bookingConfirmPing(String when) {
    return '$when. سنُعلمك فور التأكيد — عادةً خلال 30 دقيقة.';
  }

  @override
  String get bookingProvider => 'مقدّم الخدمة';

  @override
  String get bookingService => 'الخدمة';

  @override
  String get bookingWhen => 'الموعد';

  @override
  String get bookingTotal => 'الإجمالي';

  @override
  String get bookingViewMine => 'عرض حجوزاتي';

  @override
  String get bookingAddToCalendar => 'أضف إلى التقويم';

  @override
  String get bookingTypeEyebrow => 'كيف تريد الحجز؟';

  @override
  String get bookingTypeTitle => 'الآن أم لاحقًا؟';

  @override
  String bookingTypeAccepts(String name) {
    return 'يقبل $name طلبات اليوم نفسه والحجوزات المجدولة.';
  }

  @override
  String get bookingTypeNowEyebrow => 'احجز الآن';

  @override
  String get bookingTypeNowTitle => 'اطلب من يأتيك الآن';

  @override
  String get bookingTypeNowEta => 'الوصول المتوقع خلال 25–40 دقيقة';

  @override
  String get bookingTypeNowComes => 'يأتي إليك';

  @override
  String get bookingTypeScheduleEyebrow => 'جدولة';

  @override
  String get bookingTypeScheduleTitle => 'اختر تاريخًا وموعدًا';

  @override
  String get bookingTypeUpTo14 => 'حتى 14 يومًا مقدّمًا';

  @override
  String get bookingTypeProviderConfirms => 'يؤكد مقدّم الخدمة الموعد';

  @override
  String bookingTypeCashNote(String cash) {
    return 'في الحالتين، الدفع $cash. الدفع الإلكتروني قادم في إصدار لاحق.';
  }

  @override
  String get bookingCashOnVisit => 'نقدًا عند الزيارة';

  @override
  String get chatReportEyebrow => 'الإبلاغ عن رسالة';

  @override
  String get chatReportTitle => 'هل تريد إرسالها لمراجعة الإدارة؟';

  @override
  String get chatReportBody =>
      'يراجع فريق الدعم الرسائل المُبلَّغ عنها ويمكنه حذفها. لن يتم إشعار الطرف الآخر.';

  @override
  String get chatMaskedOnline => 'رقم مخفي · متصل';

  @override
  String get chatAdminNote =>
      'لا تطّلع الإدارة على هذه المحادثة إلا إذا قدّمت شكوى أو اعترضت على دفعة.';

  @override
  String get chatHint => 'اكتب رسالة…';

  @override
  String get chatRemoved => '[حذفت الإدارة هذه الرسالة]';

  @override
  String get chatReport => 'إبلاغ';

  @override
  String get bookingsGuestTitle => 'اطّلع على حجوزاتك';

  @override
  String get bookingsGuestBody => 'سجّل الدخول لعرض حجوزاتك ومتابعتها.';

  @override
  String get bookingsEyebrow => 'مواعيدك';

  @override
  String get bookingsTitle => 'الحجوزات';

  @override
  String get bookingsUpcoming => 'القادمة';

  @override
  String get bookingsPast => 'السابقة';

  @override
  String get bookingsEmptyUpcomingTitle => 'لا توجد حجوزات بعد';

  @override
  String get bookingsEmptyPastTitle => 'لا توجد مواعيد سابقة';

  @override
  String get bookingsEmptyUpcomingBody =>
      'عندما تحجز مع مقدّم خدمة، يظهر الحجز هنا لتتابعه وهو في الطريق إليك.';

  @override
  String get bookingsEmptyPastBody =>
      'بعد انتهاء أي موعد ينتقل إلى هنا، جاهزًا لإعادة الحجز بلمسة واحدة.';

  @override
  String get bookingsFindProvider => 'ابحث عن مقدّم خدمة';

  @override
  String get commonLoadMore => 'عرض المزيد';

  @override
  String distanceKm(String km) {
    return '$km كم';
  }

  @override
  String get bookingsNoShow => 'تم تسجيل عدم الحضور';

  @override
  String get bookingsRejectedByProvider => 'رفضه مقدّم الخدمة';

  @override
  String get bookingsCancelledByYou => 'ألغيتَه أنت';

  @override
  String get bookingsCancelledByProvider => 'ألغاه مقدّم الخدمة';

  @override
  String bookingsCancelledBy(String who) {
    return 'ألغاه $who';
  }

  @override
  String commonQuoted(String text) {
    return '«$text»';
  }

  @override
  String get bookingsPenaltyApplied =>
      'طُبّقت غرامة على مقدّم الخدمة بسبب الإلغاء المتأخر.';

  @override
  String get bookingsTrack => 'تتبّع';

  @override
  String get bookingsDirections => 'الاتجاهات';

  @override
  String get bookingsRebook => 'احجز مجددًا';

  @override
  String get bookingsLeaveReview => 'اكتب تقييمًا';

  @override
  String get bookingsSeeAlternatives => 'اعرض البدائل';

  @override
  String bookingRebookedFor(String time) {
    return 'أُعيد الحجز على الساعة $time.';
  }

  @override
  String get bookingProviderOnWay => 'مقدّم الخدمة في الطريق إليك.';

  @override
  String get bookingPlacedWaiting => 'تم إرسال الحجز. بانتظار التأكيد.';

  @override
  String get bookingThisProvider => 'مقدّم الخدمة هذا';

  @override
  String get bookingBookService => 'احجز خدمة';

  @override
  String get bookingPickTime => 'اختر موعدًا';

  @override
  String bookingDateMonth(String month) {
    return 'التاريخ · $month';
  }

  @override
  String get bookingAvailableSlots => 'المواعيد المتاحة';

  @override
  String get bookingNoSlots =>
      'لا توجد مواعيد متاحة في هذا اليوم — جرّب تاريخًا آخر.';

  @override
  String get bookingWhere => 'المكان';

  @override
  String get bookingNowAddressNote =>
      'في «احجز الآن» يأتيك مقدّم الخدمة دائمًا إلى عنوانك — أكّد العنوان أدناه.';

  @override
  String get bookingAtMyAddress => 'في عنواني';

  @override
  String get bookingAtSalon => 'في الصالون';

  @override
  String get bookingAddAddress => 'إضافة عنوان جديد';

  @override
  String get bookingPayment => 'الدفع';

  @override
  String get bookingCashOnVisitTitle => 'نقدًا عند الزيارة';

  @override
  String get bookingCashOnVisitSub =>
      'ادفع لمقدّم الخدمة مباشرةً بعد انتهاء الخدمة';

  @override
  String get bookingNoteLabel => 'ملاحظة لمقدّم الخدمة';

  @override
  String get bookingNotePlaceholder => 'أي طلبات خاصة…';

  @override
  String get bookingTotalCash => 'الإجمالي · نقدًا';

  @override
  String get bookingChooseService => 'اختر خدمة';

  @override
  String get bookingChooseTime => 'اختر موعدًا';

  @override
  String get bookingChooseAddress => 'اختر عنوانًا';

  @override
  String get bookingConfirm => 'تأكيد الحجز';

  @override
  String get bookingChooseServiceBelow => 'اختر خدمة من الأسفل';

  @override
  String get outcomeExpiredEyebrow => 'انتهت صلاحية الطلب';

  @override
  String get outcomeExpiredTitle => 'لم يصل ردّ في الوقت المحدد.';

  @override
  String outcomeExpiredBody(String name) {
    return 'لم يردّ $name خلال مهلة الحجز، لذا أُلغي طلبك. لم يُخصم منك أي مبلغ.';
  }

  @override
  String get outcomeTheProvider => 'مقدّم الخدمة';

  @override
  String get outcomeSeeAlternatives => 'اعرض مقدّمي خدمة بديلين';

  @override
  String get outcomeBackToBookings => 'العودة إلى الحجوزات';

  @override
  String get rejectedEyebrow => 'تم رفض الحجز';

  @override
  String get rejectedTitleGeneric => 'تعذّر على مقدّم الخدمة قبول هذا الحجز.';

  @override
  String rejectedTitle(String name) {
    return 'تعذّر على $name قبول هذا الحجز.';
  }

  @override
  String get rejectedSimilar => 'مقدّمو خدمة مشابهون';

  @override
  String get rejectedOtherNearby => 'مقدّمو خدمة آخرون بالقرب منك';

  @override
  String rejectedReasonFrom(String name) {
    return 'السبب من $name';
  }

  @override
  String rejectedBookAnother(String name) {
    return 'احجز مع $name في وقت آخر';
  }

  @override
  String get rejectedNextSlots => 'أقرب المواعيد المتاحة للخدمة نفسها';

  @override
  String get rejectedSeeAllTimes => 'اعرض كل المواعيد';

  @override
  String get commonToday => 'اليوم';

  @override
  String get commonTomorrow => 'غدًا';

  @override
  String get commonBook => 'احجز';

  @override
  String distanceMeters(int m) {
    return '$m م';
  }

  @override
  String get proposedAccepted =>
      'تم تأكيد الموعد الجديد — حدّثنا تقويمك وتذكيراتك.';

  @override
  String get proposedEyebrow => 'موعد جديد مقترح';

  @override
  String proposedTitle(String name) {
    return 'اقترح $name موعدًا مختلفًا.';
  }

  @override
  String get proposedLead =>
      'موعدك الأصلي لم يكن متاحًا. إليك ما يمكنه تقديمه بدلًا منه.';

  @override
  String proposedInsteadOf(String when) {
    return 'بدلًا من $when';
  }

  @override
  String get proposedExpiredTitle => 'انتهت صلاحية هذا العرض';

  @override
  String get proposedExpiredBody =>
      'لم تردّ في الوقت المحدد، لذا أُلغي الطلب تلقائيًا. اطلب موعدًا آخر أو اعرض من هو متاح غيره.';

  @override
  String proposedRespondWithin(String time) {
    return 'ردّ خلال $time وإلا تنتهي صلاحية هذا العرض تلقائيًا.';
  }

  @override
  String get proposedAccept => 'قبول الموعد الجديد';

  @override
  String get proposedDecline => 'رفض وعرض البدائل';

  @override
  String get payConfirmedToast => 'تم تأكيد الدفع وإرسال الإيصال.';

  @override
  String get payUnpaidToast => 'تم الإبلاغ عن عدم الدفع، وأُبلغ فريق دعم AIWA.';

  @override
  String get payEyebrow => 'تأكيد الدفع';

  @override
  String payTitle(String name) {
    return 'هل دفعت لـ$name نقدًا؟';
  }

  @override
  String payTotalDue(String amount) {
    return 'المبلغ المستحق · $amount';
  }

  @override
  String get payYes => 'نعم، دفعت — تأكيد';

  @override
  String get payNo => 'لا / هناك مشكلة';

  @override
  String get payRate => 'قيّم مقدّم الخدمة';

  @override
  String get payUndo => 'تراجع — ضغطت بالخطأ';

  @override
  String get payWhatHappened => 'ماذا حدث؟';

  @override
  String get payExplainPlaceholder => 'اشرح مشكلة الدفع…';

  @override
  String get paySubmitUnpaid => 'إرسال كغير مدفوع';

  @override
  String get commonBack => 'رجوع';

  @override
  String get paidTitle => 'تم تأكيد الدفع';

  @override
  String get paidSub => 'أُرسل الإيصال إلى بريدك الإلكتروني';

  @override
  String get paidCashCollected => 'المبلغ المُحصَّل نقدًا';

  @override
  String paidCommission(String percent) {
    return 'عمولة AIWA ($percent%) · أُضيفت إلى السجل';
  }

  @override
  String get paidBookingStatus => 'حالة الحجز';

  @override
  String get statusCompleted => 'مكتمل';

  @override
  String get complaintBehavior => 'سلوك مقدّم الخدمة';

  @override
  String get complaintBehaviorHint => 'تصرّف فظ أو غير آمن أو غير مهني.';

  @override
  String get complaintQuality => 'جودة الخدمة';

  @override
  String get complaintQualityHint => 'الخدمة لم تطابق ما هو معلن.';

  @override
  String get complaintPricing => 'الأسعار أو الفوترة';

  @override
  String get complaintPricingHint => 'طُلب مبلغ نقدي أكثر من المتفق عليه.';

  @override
  String get complaintSafety => 'مخاوف تتعلق بالأمان';

  @override
  String get complaintSafetyHint =>
      'النظافة أو الهوية أو أي مشكلة تتعلق بالأمان.';

  @override
  String get complaintNoShow => 'لم يحضر مقدّم الخدمة';

  @override
  String get complaintNoShowHint => 'تم الحجز لكنه لم يصل أبدًا.';

  @override
  String get complaintOther => 'شيء آخر';

  @override
  String get complaintOtherHint => 'أخبرنا بكلماتك الخاصة.';

  @override
  String get complaintSubmitted => 'تم إرسال الشكوى. سنتواصل معك عبر واتساب.';

  @override
  String get complaintEyebrow => 'تقديم شكوى';

  @override
  String get complaintPickCategory => 'اختر فئة';

  @override
  String get complaintTellMore => 'أخبرنا بالمزيد';

  @override
  String get complaintPlaceholder =>
      'اشرح لنا ما حدث. كلما زادت التفاصيل، استطعنا مساعدتك أسرع.';

  @override
  String get complaintPrivate =>
      'يبقى اسمك وبيانات تواصلك سرية. لن يطّلع على هذه الحالة إلا فريق دعم AIWA.';

  @override
  String get complaintSubmit => 'إرسال الشكوى';

  @override
  String complaintAbout(String name) {
    return 'بخصوص $name';
  }

  @override
  String complaintBookingNo(String id) {
    return 'الحجز رقم $id';
  }

  @override
  String get complaintPrivateTag => 'خاص';

  @override
  String get statusPending => 'قيد الانتظار';

  @override
  String get statusConfirmed => 'مؤكَّد';

  @override
  String get statusAccepted => 'مقبول';

  @override
  String get statusOnTheWay => 'في الطريق';

  @override
  String get statusArrived => 'وصل';

  @override
  String get statusInProgress => 'قيد التنفيذ';

  @override
  String get statusCancelled => 'ملغى';

  @override
  String get statusRejected => 'مرفوض';

  @override
  String get statusNoShow => 'لم يحضر';

  @override
  String get statusExpired => 'منتهي';

  @override
  String get statusDisputed => 'متنازع عليه';

  @override
  String get trackPendingHint => 'بانتظار تأكيد مقدّم الخدمة.';

  @override
  String get trackAcceptedHint => 'تم تأكيد حجزك.';

  @override
  String get trackOnTheWayHint => 'مقدّم الخدمة في طريقه إلى عنوانك.';

  @override
  String get trackArrivedHint => 'وصل مقدّم الخدمة إلى بابك.';

  @override
  String get trackInProgressHint => 'الخدمة جارية.';

  @override
  String get trackCompletedHint => 'انتهت الخدمة. ادفع نقدًا وقيّم التجربة.';

  @override
  String get trackWaitPending => 'بانتظار قبول مقدّم الخدمة';

  @override
  String get trackWaitAccepted => 'يتحدّث عند انطلاق مقدّم الخدمة';

  @override
  String get trackWaitOnTheWay => 'يتحدّث عند وصول مقدّم الخدمة';

  @override
  String get trackWaitArrived => 'يتحدّث عند بدء مقدّم الخدمة للخدمة';

  @override
  String get trackWaitInProgress => 'يتحدّث عندما يُنهي مقدّم الخدمة الخدمة';

  @override
  String get trackUpdatesAuto => 'يتحدّث تلقائيًا';

  @override
  String get cancelReasonMind => 'غيّرت رأيي';

  @override
  String get cancelReasonOther => 'وجدت مقدّم خدمة آخر';

  @override
  String get cancelReasonWrong => 'خدمة أو موعد خاطئ';

  @override
  String get cancelReasonPrice => 'السعر مرتفع جدًا';

  @override
  String get cancelReasonUnresponsive => 'مقدّم الخدمة لا يستجيب';

  @override
  String get cancelReasonElse => 'سبب آخر';

  @override
  String get trackCancelEyebrow => 'إلغاء حجزك';

  @override
  String get trackCancelTitle => 'لماذا تلغي الحجز؟';

  @override
  String trackCancelledToast(String reason) {
    return 'تم إلغاء الحجز. السبب: $reason';
  }

  @override
  String get trackStatusTimeline => 'مراحل الحجز';

  @override
  String get trackCancelBooking => 'إلغاء الحجز';

  @override
  String get trackReportProblem => 'الإبلاغ عن مشكلة';

  @override
  String get trackTracking => 'التتبّع';

  @override
  String get trackSafetyTitle => 'زر الاستغاثة على بُعد لمسة';

  @override
  String get trackSafetySub =>
      'زر الاستغاثة ينبّه دعم AIWA ويرسل رسالة إلى جهات اتصالك الموثوقة.';

  @override
  String get trackSos => 'طوارئ — تنبيه جهة اتصال موثوقة وAIWA';

  @override
  String get trackSosAlerting => 'جارٍ تنبيه جهة اتصالك الموثوقة ودعم AIWA…';

  @override
  String trackSosNotified(String bold) {
    return '$bold تم تنبيه جهة اتصال موثوقة بموقعك المباشر. ابقَ بأمان — قد يتصل بك مختص قريبًا.';
  }

  @override
  String get trackSosNotifiedBold => 'تم إبلاغ الدعم.';

  @override
  String get trackSosLogged =>
      'تم تسجيل الحادثة لمراجعة الإدارة. سيتابع فريق الثقة والأمان خلال 24 ساعة.';

  @override
  String get trackImSafe => 'أنا بأمان';

  @override
  String get trackCheckInTitle => 'خدمة في المكان — سجّل وصولك عند الحضور';

  @override
  String trackCheckInSub(String name) {
    return 'سجّل وصولك في المكان ليعرف $name أنك هناك.';
  }

  @override
  String get trackCheckedIn => 'تم تسجيل الوصول';

  @override
  String get trackCheckIn => 'تسجيل الوصول';

  @override
  String get trackConfirmCash => 'أكّد دفعك النقدي';

  @override
  String trackDueTo(String amount, String name) {
    return '$amount مستحقة لـ$name';
  }

  @override
  String get commonConfirm => 'تأكيد';

  @override
  String trackFeeWants(String name, String amount) {
    return 'يطلب $name مبلغ $amount مقابل الانتقال';
  }

  @override
  String trackFeeTotal(String base, String fee, String total) {
    return 'سيكون الإجمالي $base + $fee = $total.';
  }

  @override
  String get commonDecline => 'رفض';

  @override
  String get trackAcceptConfirm => 'قبول وتأكيد';

  @override
  String trackServicePlusTravel(String service, String travel) {
    return 'الخدمة $service + الانتقال $travel';
  }

  @override
  String trackTotalAmount(String amount) {
    return 'الإجمالي $amount';
  }

  @override
  String get trackDeclinedEyebrow => 'تم إلغاء الحجز';

  @override
  String get trackDeclinedTitle => 'لا مشكلة — لم تُطبَّق أي رسوم.';

  @override
  String trackDeclinedBody(String fee) {
    return 'رفضت رسوم الانتقال البالغة $fee، لذا أُلغي هذا الطلب دون أي تبعات. لن تُفرض غرامة على أيٍّ منكما.';
  }

  @override
  String get trackFindAnother => 'ابحث عن مقدّم خدمة آخر';

  @override
  String get agoYesterday => 'أمس';

  @override
  String agoDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'منذ $n يوم',
      many: 'منذ $n يومًا',
      few: 'منذ $n أيام',
      two: 'منذ يومين',
      one: 'منذ يوم',
      zero: 'اليوم',
    );
    return '$_temp0';
  }

  @override
  String agoWeeks(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'منذ $n أسبوع',
      many: 'منذ $n أسبوعًا',
      few: 'منذ $n أسابيع',
      two: 'منذ أسبوعين',
      one: 'منذ أسبوع',
      zero: 'هذا الأسبوع',
    );
    return '$_temp0';
  }

  @override
  String agoMonths(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'منذ $n شهر',
      many: 'منذ $n شهرًا',
      few: 'منذ $n أشهر',
      two: 'منذ شهرين',
      one: 'منذ شهر',
      zero: 'هذا الشهر',
    );
    return '$_temp0';
  }

  @override
  String providerShareText(String name) {
    return '$name على AIWA';
  }

  @override
  String get providerStartsAt => 'يبدأ من';

  @override
  String get providerAskProvider => 'اسأل مقدّم الخدمة';

  @override
  String get providerBookNow => 'احجز الآن';

  @override
  String get providerNew => 'جديد';

  @override
  String get providerVerified => 'موثّق';

  @override
  String get providerBioFallback =>
      'مقدّم خدمة من الأعلى تقييمًا في منطقتك. تعرّف أكثر على الصالون وخدماته وأحدث التقييمات.';

  @override
  String get providerCall => 'اتصال';

  @override
  String get providerWhatsApp => 'واتساب';

  @override
  String get providerReport => 'إبلاغ';

  @override
  String get providerNoReviews => 'لا توجد تقييمات بعد';

  @override
  String get providerNoReviewsBody => 'كن أول من يحجز ويكتب تقييمًا.';

  @override
  String providerBasedOn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بناءً على $count تقييم',
      many: 'بناءً على $count تقييمًا',
      few: 'بناءً على $count تقييمات',
      two: 'بناءً على تقييمين',
      one: 'بناءً على تقييم واحد',
      zero: 'لا توجد تقييمات',
    );
    return '$_temp0';
  }

  @override
  String get providerNoPhotos => 'لا توجد صور بعد';

  @override
  String get providerNoPhotosBody =>
      'لم يُضف مقدّم الخدمة صورًا إلى المعرض بعد.';

  @override
  String get providerNoServices => 'لا توجد خدمات مدرجة';

  @override
  String get providerNoServicesBody => 'لم ينشر مقدّم الخدمة أي خدمات بعد.';

  @override
  String get providerTabServices => 'الخدمات';

  @override
  String get providerTabReviews => 'التقييمات';

  @override
  String get providerTabGallery => 'المعرض';

  @override
  String get providerUnavailable => 'غير متاح';

  @override
  String get staffPickTitle => 'اختر مصففك.';

  @override
  String get staffPickBody =>
      'هذا محل يضم عدة موظفين — سيرتبط حجزك بمن تختاره.';

  @override
  String get staffNoPreference => 'لا تفضيل';

  @override
  String get staffFirstAvailable => 'أول موظف متاح';

  @override
  String get flagReasonMisleading => 'ملف شخصي أو معرض مضلِّل';

  @override
  String get flagReasonBehavior => 'سلوك غير لائق أو غير آمن';

  @override
  String get flagReasonPrice => 'رفض الالتزام بالسعر المتفق عليه';

  @override
  String get flagReasonIdentity => 'الهوية تبدو مريبة';

  @override
  String get flagReasonSpam => 'حساب مزعج أو وهمي';

  @override
  String get flagReasonOther => 'أخرى';

  @override
  String get flagThanks => 'شكرًا — استلمنا بلاغك. يراجع فريقنا كل بلاغ.';

  @override
  String flagEyebrow(String name) {
    return 'الإبلاغ عن $name';
  }

  @override
  String get flagTitle => 'أخبرنا بالمشكلة';

  @override
  String get flagBody =>
      'البلاغات مجهولة الهوية. يراجع فريقنا كل بلاغ ويتخذ الإجراء اللازم بحق مقدّم الخدمة إذا ثبت.';

  @override
  String get flagHelpUs => 'ساعدنا على الفهم';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get flagSubmit => 'إرسال البلاغ';

  @override
  String get providerReportPhoto => 'الإبلاغ عن الصورة';

  @override
  String get providerReportPhotoHint => 'اضغط مطولًا على صورة للإبلاغ عنها.';

  @override
  String get homeOpen => 'مفتوح';

  @override
  String get homeOpenNow => 'مفتوح الآن';

  @override
  String get homeFrom => 'من';

  @override
  String get homeNearMe => 'بالقرب مني';

  @override
  String get homeGoodMorning => 'صباح الخير';

  @override
  String get homeGoodAfternoon => 'مساء الخير';

  @override
  String get homeGoodEvening => 'مساء الخير';

  @override
  String homeGreetingName(String greeting, String name) {
    return '$greeting يا $name';
  }

  @override
  String get homeHeadline => 'من سيجعلك\nتتألق الليلة؟';

  @override
  String get homeSearchHint => 'خدمة أو مقدّم خدمة';

  @override
  String get homePromoEyebrow => 'هذا الأسبوع · خصم 20%';

  @override
  String get homePromoTitle => 'موسم إطلالات العرائس';

  @override
  String get homePromoBody =>
      'أفضل فناني المكياج والرموش تقييمًا، بأسعار الباقات.';

  @override
  String get homeExplore => 'استكشف ←';

  @override
  String get homeCategories => 'الفئات';

  @override
  String get commonSeeAll => 'عرض الكل';

  @override
  String get homeAll => 'الكل';

  @override
  String get homeNobodyNearby => 'لا يوجد أحد بالقرب منك بعد';

  @override
  String get homeNobodyNearbyBody =>
      'لا يوجد مقدّمو خدمة ضمن نطاقك حاليًا. جرّب تصفّح كل الفئات.';

  @override
  String get homeBrowseAll => 'تصفّح الكل';

  @override
  String get homeTrending => 'الأكثر رواجًا بالقرب منك';

  @override
  String get homeViewMap => 'عرض الخريطة';

  @override
  String get homeAvailableNow => 'متاحون الآن';

  @override
  String get searchSortNearest => 'الأقرب';

  @override
  String get searchSortTopRated => 'الأعلى تقييمًا';

  @override
  String get searchSortPrice => 'السعر';

  @override
  String get searchNotifyToast => 'سنُعلمك.';

  @override
  String get searchEyebrow => 'اكتشف شخصًا جديدًا';

  @override
  String get searchTitle => 'اكتشف';

  @override
  String get searchHint => 'ابحث عن مقدّمي خدمة أو خدمات أو أماكن';

  @override
  String searchMinRatingChip(String rating) {
    return '★ $rating+ ×';
  }

  @override
  String searchUnderPriceChip(String price) {
    return 'أقل من $price ×';
  }

  @override
  String get searchSort => 'ترتيب';

  @override
  String searchFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نتيجة',
      many: '$count نتيجة',
      few: '$count نتائج',
      two: 'نتيجتان',
      one: 'نتيجة واحدة',
      zero: 'لا نتائج',
    );
    return '$_temp0';
  }

  @override
  String searchNoMatch(String query) {
    return 'لا نتائج لـ«$query»';
  }

  @override
  String get searchNothingInCategory => 'لا شيء في هذه الفئة بالقرب منك';

  @override
  String get searchNoMatchBody =>
      'جرّب تهجئة مختلفة، أو تصفّح حسب الفئة بدلًا من ذلك.';

  @override
  String get searchNoFilterMatchBody =>
      'لا يوجد مقدّمو خدمة ضمن نطاقك يطابقون هذه الفلاتر بعد.';

  @override
  String get searchClearAll => 'مسح البحث والفلاتر';

  @override
  String get searchWiden => 'وسّع نطاق البحث';

  @override
  String get searchNotifyMe => 'أعلمني عند انضمام أحد';

  @override
  String searchInRange(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مقدّم خدمة ضمن النطاق',
      many: '$count مقدّم خدمة ضمن النطاق',
      few: '$count مقدّمي خدمة ضمن النطاق',
      two: 'مقدّما خدمة ضمن النطاق',
      one: 'مقدّم خدمة واحد ضمن النطاق',
      zero: 'لا يوجد مقدّمو خدمة ضمن النطاق',
    );
    return '$_temp0';
  }

  @override
  String get searchFilters => 'الفلاتر';

  @override
  String get searchReset => 'إعادة تعيين';

  @override
  String get searchMinRating => 'أدنى تقييم';

  @override
  String get searchAny => 'أي تقييم';

  @override
  String get searchMaxPrice => 'أقصى سعر';

  @override
  String searchShowProviders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'عرض $count مقدّم خدمة',
      many: 'عرض $count مقدّم خدمة',
      few: 'عرض $count مقدّمي خدمة',
      two: 'عرض مقدّمَي خدمة',
      one: 'عرض مقدّم خدمة واحد',
      zero: 'لا يوجد مقدّمو خدمة',
    );
    return '$_temp0';
  }

  @override
  String get tabToday => 'اليوم';

  @override
  String get tabBookings => 'الحجوزات';

  @override
  String get tabServices => 'الخدمات';

  @override
  String get tabSchedule => 'المواعيد';

  @override
  String get tabProfile => 'الملف';

  @override
  String get dashNewRequests => 'طلبات جديدة';

  @override
  String dashPendingCount(int count) {
    return '$count قيد الانتظار';
  }

  @override
  String get dashConfirmedToday => 'المؤكدة اليوم';

  @override
  String get dashNothingElse => 'لا شيء آخر في جدول اليوم.';

  @override
  String dashHelloName(String name) {
    return 'مرحبًا يا $name';
  }

  @override
  String get dashHello => 'مرحبًا';

  @override
  String get dashTodaysSchedule => 'جدول اليوم.';

  @override
  String get dashStatToday => 'اليوم';

  @override
  String get dashStatEgpToday => 'ج.م اليوم';

  @override
  String get dashStatRating => 'التقييم';

  @override
  String dashNewRequestsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count طلب حجز جديد',
      many: '$count طلب حجز جديدًا',
      few: '$count طلبات حجز جديدة',
      two: 'طلبا حجز جديدان',
      one: 'طلب حجز جديد واحد',
      zero: 'لا توجد طلبات حجز جديدة',
    );
    return '$_temp0';
  }

  @override
  String get dashReplyWithin => 'ردّ خلال 30 دقيقة لتحافظ على تقييمك المرتفع.';

  @override
  String get commonCustomer => 'العميل';

  @override
  String get commonAccept => 'قبول';

  @override
  String get provBookingsEyebrow => 'الإدارة';

  @override
  String get provTabPending => 'قيد الانتظار';

  @override
  String get provTabUpcoming => 'القادمة';

  @override
  String get provTabPast => 'السابقة';

  @override
  String get provNothingHere => 'لا شيء هنا بعد.';

  @override
  String get closeTheCustomer => 'العميل';

  @override
  String get closeDisputedToast => 'تم وضع علامة نزاع وإبلاغ الإدارة.';

  @override
  String get closeEyebrow => 'إنهاء هذه المهمة';

  @override
  String closeDidPay(String name) {
    return 'هل دفع $name نقدًا؟';
  }

  @override
  String get closeCashReceived => 'نعم، استلمت المبلغ نقدًا';

  @override
  String get closeMarkDisputed => 'تحديد كغير مدفوع أو متنازع عليه';

  @override
  String get closeJobClosed => 'تم استلام المبلغ · أُغلقت المهمة';

  @override
  String closeReceiptSentTo(String name) {
    return 'أُرسل الإيصال إلى $name';
  }

  @override
  String closeRate(String name) {
    return 'قيّم $name';
  }

  @override
  String get closeSubmitDisputed => 'إرسال كمتنازع عليه';

  @override
  String get rateTagOnTime => 'في الموعد';

  @override
  String get rateTagRespectful => 'محترم';

  @override
  String get rateTagClear => 'واضح في طلباته';

  @override
  String get rateTagPaid => 'دفع كامل المبلغ';

  @override
  String get rateTagLate => 'متأخر';

  @override
  String get rateTagHardToReach => 'يصعب التواصل معه';

  @override
  String get rateSubmitted =>
      'تم إرسال التقييم. أصبح الموعد متاحًا وأُبلغ الحجز التالي.';

  @override
  String get rateCustomerFallback => 'العميل';

  @override
  String get rateSubmit => 'إرسال التقييم';

  @override
  String get rateEyebrow => 'تقييم متبادل';

  @override
  String rateStars(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n نجمة',
      many: '$n نجمة',
      few: '$n نجوم',
      two: 'نجمتان',
      one: 'نجمة واحدة',
      zero: 'بلا نجوم',
    );
    return '$_temp0';
  }

  @override
  String get rateQuickTags => 'وسوم سريعة';

  @override
  String get pbdAltTimeSent => 'أُرسل موعد بديل إلى العميل.';

  @override
  String get pbdCancelEyebrow => 'الإلغاء بعد القبول';

  @override
  String get pbdCancelTitle => 'سيُطبَّق على ذلك غرامة';

  @override
  String get pbdCancelWarning =>
      'إلغاء حجز مقبول يؤثر على درجة موثوقيتك ويضيف غرامة صغيرة إلى سجلك.';

  @override
  String get pbdReasonEmergency => 'طارئ / غير متاح';

  @override
  String get pbdReasonSick => 'الموظف مريض';

  @override
  String get pbdReasonOverbooked => 'حجز زائد بالخطأ';

  @override
  String get pbdReasonUnreachable => 'تعذّر الوصول إلى العميل';

  @override
  String get pbdCancelConfirm => 'إلغاء وقبول الغرامة';

  @override
  String get pbdCancelledToast => 'تم إلغاء الحجز وتطبيق الغرامة على سجلك.';

  @override
  String get pbdNoShow => 'لم يحضر العميل';

  @override
  String get pbdNoShowTitle => 'تسجيل هذا الحجز كعدم حضور؟';

  @override
  String get pbdNoShowBody =>
      'استخدم هذا فقط إذا لم يحضر العميل ولم تتمكن من الوصول إليه. يُغلق الحجز دون مخالفة عليك ويُسجَّل على العميل.';

  @override
  String get pbdNoShowToast => 'تم تسجيل عدم الحضور.';

  @override
  String get pbdEyebrow => 'طلب حجز';

  @override
  String get pbdTitle => 'راجِع وردّ';

  @override
  String pbdPriorBookings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حجز سابق',
      many: '$count حجزًا سابقًا',
      few: '$count حجوزات سابقة',
      two: 'حجزان سابقان',
      one: 'حجز سابق واحد',
      zero: 'لا حجوزات سابقة',
    );
    return '$_temp0';
  }

  @override
  String get pbdHomeAddress => 'عنوان الخدمة المنزلية';

  @override
  String get pbdNoAddress => 'لا يوجد عنوان مرفق';

  @override
  String get pbdNoAddressBody =>
      'طلب الخدمة المنزلية هذا بلا عنوان، لذا لا يمكن تسعير رسوم الانتقال. لا يزال بإمكانك القبول أو الرفض كالمعتاد.';

  @override
  String pbdQuoteSent(String amount) {
    return 'أُرسل عرض رسوم الانتقال · $amount';
  }

  @override
  String get pbdQuoteSentBody =>
      'بانتظار قبول العميل أو رفضه. إذا قبل، يتأكد الحجز تلقائيًا — دون أي خطوة إضافية منك.';

  @override
  String get pbdFeeAccepted => 'تم قبول رسوم الانتقال';

  @override
  String get pbdFeeAcceptedBody =>
      'تم تثبيتها وإضافتها إلى الإجمالي. رسوم الانتقال تذهب إليك كاملة — لا تأخذ AIWA عليها عمولة.';

  @override
  String get pbdCustomerNote => 'ملاحظة العميل';

  @override
  String get pbdQuoteInstead => 'اقترح رسوم انتقال بدلًا من ذلك';

  @override
  String get pbdProposeInstead => 'اقترح موعدًا مختلفًا بدلًا من ذلك';

  @override
  String get pbdOnMyWay => 'في طريقي';

  @override
  String get pbdOnMyWayNote => 'يصل إشعار للعميل ويبدأ التتبّع المباشر.';

  @override
  String get pbdArrived => 'وصلت';

  @override
  String get pbdArrivedNote => 'سيُبلَّغ العميل بأنك عند الباب.';

  @override
  String get pbdStartService => 'بدء الخدمة';

  @override
  String get pbdStartNote => 'يبدأ المؤقت ويبقى تسجيل الأمان مفعّلًا.';

  @override
  String get pbdStartVenueNote => 'اضغط بعد وصول العميل إلى مكانك.';

  @override
  String get pbdFinishNote => 'أنهِ المهمة ثم أكّد المبلغ النقدي الذي استلمته.';

  @override
  String get pbdMarkCompleted => 'تحديد كمكتمل';

  @override
  String get pbdJobProgress => 'تقدّم المهمة';

  @override
  String get pbdDuration => 'المدة';

  @override
  String get pbdRequested => 'الموعد المطلوب';

  @override
  String get pbdServicePrice => 'سعر الخدمة';

  @override
  String get pbdTravelFeePending => 'رسوم الانتقال (قيد الانتظار)';

  @override
  String get pbdTravelFee => 'رسوم الانتقال';

  @override
  String get pbdQuoteEyebrow => 'اقتراح رسوم انتقال';

  @override
  String pbdQuoteTitle(String name) {
    return 'كم تكلفة الوصول إلى عنوان $name؟';
  }

  @override
  String pbdQuotePassThrough(String amount) {
    return 'هذه الرسوم تذهب إليك كاملة — لا تأخذ AIWA عمولة على رسوم الانتقال، بل على سعر الخدمة البالغ $amount فقط.';
  }

  @override
  String get currencyEgp => 'ج.م';

  @override
  String get pbdSendQuote => 'إرسال العرض';

  @override
  String get svcEyebrow => 'قائمة خدماتك';

  @override
  String get svcNew => 'جديد';

  @override
  String get svcEmpty => 'لا توجد خدمات بعد';

  @override
  String get svcEmptyBody => 'أضف ما تقدّمه ليتمكن العملاء من حجزه.';

  @override
  String get svcStartsAt => 'يبدأ من';

  @override
  String get svcFixedPrice => 'سعر ثابت';

  @override
  String get svcHidden => 'مخفية';

  @override
  String get svcNewService => 'خدمة جديدة';

  @override
  String get svcEditService => 'تعديل الخدمة';

  @override
  String get svcName => 'الاسم';

  @override
  String get svcPrice => 'السعر (ج.م)';

  @override
  String get svcDuration => 'المدة (بالدقائق)';

  @override
  String get svcHide => 'إخفاء';

  @override
  String get svcHiddenToast => 'تم إخفاء الخدمة.';

  @override
  String get commonSave => 'حفظ';

  @override
  String get svcSavedToast => 'تم حفظ الخدمة.';

  @override
  String get schedEyebrow => 'التوفّر الأسبوعي';

  @override
  String schedTip(String tip) {
    return '$tip اضغط على أي يوم لإضافة فترات متعددة أو استراحات أو تغييرات لمرة واحدة في التوفّر.';
  }

  @override
  String get schedTipLabel => 'نصيحة:';

  @override
  String get schedClosed => 'مغلق';

  @override
  String get schedDecrease => 'تقليل الفاصل';

  @override
  String get schedIncrease => 'زيادة الفاصل';

  @override
  String get schedBufferTitle => 'فاصل الانتقال بين الحجوزات';

  @override
  String get schedBufferBody =>
      'يمنع المواعيد المتقاربة جدًا في الزيارات المنزلية.';

  @override
  String staffNameSchedule(String name) {
    return 'مواعيد $name';
  }

  @override
  String get staffShopPlan => 'باقة المحل';

  @override
  String get staffTitle => 'الموظفون والتوفّر';

  @override
  String get commonAdd => 'إضافة';

  @override
  String get staffEmpty => 'لا يوجد موظفون بعد';

  @override
  String get staffEmptyBody => 'أضف الأشخاص الذين يستقبلون الحجوزات في محلك.';

  @override
  String get staffSkills => 'المهارات';

  @override
  String get staffOff => 'إجازة';

  @override
  String staffEditSchedule(String name) {
    return 'تعديل مواعيد $name';
  }

  @override
  String get staffAdded => 'تمت إضافة الموظف.';

  @override
  String get staffRole => 'المسمّى الوظيفي';

  @override
  String get staffSkillsHint => 'افصل بينها بفواصل.';

  @override
  String get walletEyebrow => 'العمولة والتسوية';

  @override
  String walletSettleTitle(String amount) {
    return 'الإبلاغ عن سداد $amount؟';
  }

  @override
  String get walletSettleBalance => 'لقد سدّدت';

  @override
  String get walletSettled =>
      'تم الإبلاغ عن السداد. سيؤكده فريق المالية في AIWA قريبًا.';

  @override
  String get walletPaymentReported =>
      'تم الإبلاغ عن السداد — بانتظار تأكيد فريق المالية في AIWA.';

  @override
  String get walletTitle => 'المحفظة';

  @override
  String get walletOwed => 'الرصيد المستحق لـ AIWA';

  @override
  String walletLimit(String amount) {
    return 'الحد السالب $amount — سدّد أسبوعيًا لتواصل استقبال الحجوزات.';
  }

  @override
  String get walletBlocked => 'موقوف عن الحجوزات الجديدة';

  @override
  String get walletBlockedBody =>
      'لا يزال بإمكانك إنهاء أي مهمة قبلتها — إتمامها وتسوية هذا الرصيد يرفع الإيقاف بعد تأكيد فريق المالية للسداد.';

  @override
  String get walletNextSettlement => 'التسوية القادمة';

  @override
  String get walletStatus => 'الحالة';

  @override
  String get walletLedger => 'السجل';

  @override
  String get walletNoCommission => 'لا توجد عمولات بعد';

  @override
  String get walletNoCommissionBody => 'تظهر الحجوزات المكتملة هنا.';

  @override
  String get walletSettleNow => 'لقد سدّدت هذا الرصيد';

  @override
  String get walletCommission => 'عمولة';

  @override
  String walletCommissionBooking(String id) {
    return 'عمولة · الحجز رقم $id';
  }

  @override
  String get walletSettledTag => 'مُسدَّدة';

  @override
  String get walletOverdue => 'متأخرة';

  @override
  String get revFilterAll => 'الكل';

  @override
  String get revFilterNeedsReply => 'بحاجة إلى رد';

  @override
  String revFilterStars(int n) {
    return '$n نجوم';
  }

  @override
  String get revEyebrow => 'مقدّم الخدمة';

  @override
  String get revTitle => 'التقييمات';

  @override
  String get revEmptyBody => 'تظهر هنا تقييمات الحجوزات المكتملة.';

  @override
  String get revNothingHere => 'لا شيء هنا';

  @override
  String get revNoMatch => 'لا توجد تقييمات تطابق هذا الفلتر.';

  @override
  String revTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تقييم إجمالًا',
      many: '$count تقييمًا إجمالًا',
      few: '$count تقييمات إجمالًا',
      two: 'تقييمان إجمالًا',
      one: 'تقييم واحد إجمالًا',
      zero: 'لا تقييمات',
    );
    return '$_temp0';
  }

  @override
  String revCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تقييم',
      many: '$count تقييمًا',
      few: '$count تقييمات',
      two: 'تقييمان',
      one: 'تقييم واحد',
      zero: 'لا تقييمات',
    );
    return '$_temp0';
  }

  @override
  String get revYourReply => 'ردّك';

  @override
  String get revReplyPublicly => 'ردّ علنًا';

  @override
  String get revReplyHint => 'اشكره، أو وضّح ما حدث…';

  @override
  String get revPostReply => 'نشر الرد';

  @override
  String get galEyebrow => 'المعرض';

  @override
  String get galDeleteTitle => 'حذف هذه الصورة؟';

  @override
  String get galDeleteBody =>
      'ستُزال من ملفك العام فورًا، ولا يمكن التراجع عن ذلك.';

  @override
  String get commonDelete => 'حذف';

  @override
  String get galIntro =>
      'أفضل أعمالك، معروضة في ملفك العام. اسحب لإعادة الترتيب — الصورة الأولى هي الغلاف.';

  @override
  String get galEmptyBody =>
      'الملفات التي تحتوي على صور تحصل على حجوزات أكثر بشكل ملحوظ. أضف بعض النماذج من أعمالك.';

  @override
  String get galUploadFirst => 'ارفع أول صورة';

  @override
  String get galOneHidden => 'هناك صورة مخفية';

  @override
  String get galOneHiddenBody =>
      'أخفى فريقنا صورة لا تتوافق مع خدماتك. استبدلها أو تواصل مع الدعم إذا كنت لا توافق.';

  @override
  String get galUploading => 'جارٍ رفع الصورة…';

  @override
  String get galCancelUpload => 'إلغاء الرفع';

  @override
  String get galHiddenByMod => 'أخفتها الإدارة';

  @override
  String get galCover => 'الغلاف';

  @override
  String get galDeletePhoto => 'حذف الصورة';

  @override
  String get ppAccount => 'حساب مقدّم الخدمة';

  @override
  String get ppSignOutTitle => 'تسجيل الخروج من AIWA؟';

  @override
  String get ppSignOutBody =>
      'ستبقى حجوزاتك كما هي تمامًا. ستحتاج إلى رقمك ورمز تحقق لتسجيل الدخول مجددًا.';

  @override
  String get commonSignOut => 'تسجيل الخروج';

  @override
  String get commonSignedOut => 'تم تسجيل الخروج.';

  @override
  String get ppVacation => 'وضع الإجازة / عدم الاتصال';

  @override
  String get ppVacationOn => 'أنت مخفي من نتائج البحث.';

  @override
  String get ppVacationOff => 'أوقف الحجوزات الجديدة مؤقتًا.';

  @override
  String get ppVerified => 'مقدّم خدمة موثّق';

  @override
  String get ppApproved => 'معتمد من AIWA.';

  @override
  String ppApprovedOn(String date) {
    return 'اعتمدته AIWA في $date.';
  }

  @override
  String get ppBusinessInfo => 'معلومات النشاط';

  @override
  String ppPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صورة',
      many: '$count صورة',
      few: '$count صور',
      two: 'صورتان',
      one: 'صورة واحدة',
      zero: 'لا صور',
    );
    return '$_temp0';
  }

  @override
  String get ppWallet => 'المحفظة والتسوية';

  @override
  String get ppNotifications => 'الإشعارات';

  @override
  String get ppSafety => 'الأمان والسياسات';

  @override
  String get ppWhatsApp => 'الدعم عبر واتساب';

  @override
  String get biNameRequired => 'اسم النشاط مطلوب.';

  @override
  String get biAddressRequired => 'أضف المنطقة ليتمكن العملاء من العثور عليك.';

  @override
  String get biSaved => 'تم حفظ معلومات النشاط.';

  @override
  String get biBioHint => 'تظهر أعلى ملفك العام.';

  @override
  String get biBaseAddress => 'العنوان الأساسي';

  @override
  String get biServiceRadius => 'نطاق الخدمة';

  @override
  String get biSurcharge => 'رسوم الزيارة المنزلية (ج.م)';

  @override
  String get biSurchargeHint =>
      'تُضاف إلى سعر الخدمة في الحجوزات بعنوان العميل.';

  @override
  String get biVerifiedStudio => 'صالون موثّق';

  @override
  String get biReReview =>
      'تغيير اسم نشاطك أو عنوانه يرسل ملفك لمراجعة سريعة من جديد.';

  @override
  String get commonSaveChanges => 'حفظ التغييرات';

  @override
  String get tabHome => 'الرئيسية';

  @override
  String get tabDiscover => 'اكتشف';

  @override
  String get tabSaved => 'المحفوظة';

  @override
  String get profGuestTitle => 'ملفك الشخصي';

  @override
  String get profGuestBody => 'سجّل الدخول لإدارة حسابك وعناوينك وإشعاراتك.';

  @override
  String get profPersonalInfo => 'المعلومات الشخصية';

  @override
  String get profSavedAddresses => 'العناوين المحفوظة';

  @override
  String get profTrustedContacts => 'جهات الاتصال الموثوقة';

  @override
  String profTrustedSaved(int count) {
    return '$count محفوظة';
  }

  @override
  String get profNotificationPrefs => 'تفضيلات الإشعارات';

  @override
  String get profLanguage => 'اللغة';

  @override
  String get profDeleteAccount => 'حذف الحساب';

  @override
  String get profYourAccount => 'حسابك';

  @override
  String get profSignOutBody =>
      'تبقى حجوزاتك ومقدّمو الخدمة المحفوظون وعناوينك في أمان. ستحتاج إلى رمز لتسجيل الدخول مجددًا.';

  @override
  String get profAccountDeleted => 'تم حذف الحساب. يؤسفنا رحيلك.';

  @override
  String get profStatBookings => 'الحجوزات';

  @override
  String get profStatFavorites => 'المفضّلة';

  @override
  String get profStatReviews => 'التقييمات';

  @override
  String get editNameError => 'أدخل اسمك الكامل.';

  @override
  String get editPhoneError => 'أدخل رقم هاتف مصريًا صالحًا.';

  @override
  String get editEmailError => 'يبدو أن البريد الإلكتروني غير صحيح.';

  @override
  String get editProfileUpdated => 'تم تحديث الملف الشخصي.';

  @override
  String get editAccount => 'الحساب';

  @override
  String get editChangePhoto => 'تغيير الصورة';

  @override
  String get editPhotoHint => 'JPG أو PNG · بحد أقصى 5 ميجابايت';

  @override
  String get editYourName => 'اسمك';

  @override
  String get editMobile => 'رقم الهاتف المحمول';

  @override
  String get editMobileHint => 'تغيير الرقم يرسل رمز تحقق إلى الرقم الجديد.';

  @override
  String get editTheme => 'المظهر';

  @override
  String get editThemeMauve => 'بنفسجي';

  @override
  String get editThemeCharcoal => 'فحمي';

  @override
  String get editSaving => 'جارٍ الحفظ…';

  @override
  String get addrHome => 'المنزل';

  @override
  String get addrWork => 'العمل';

  @override
  String get addrOther => 'آخر';

  @override
  String get addrEmpty => 'لا توجد عناوين محفوظة';

  @override
  String get addrEmptyBody =>
      'أضف عنوان منزلك أو عملك ليصبح حجز الزيارة المنزلية بلمسة واحدة.';

  @override
  String get addrStreetError =>
      'أضف الشارع والمنطقة ليتمكن مقدّم الخدمة من العثور عليك.';

  @override
  String get addrBuildingError => 'رقم المبنى أو اسمه مطلوب.';

  @override
  String addrFloorN(String n) {
    return 'الطابق $n';
  }

  @override
  String addrAptN(String n) {
    return 'شقة $n';
  }

  @override
  String get addrUpdated => 'تم تحديث العنوان.';

  @override
  String get addrAdded => 'تمت إضافة العنوان.';

  @override
  String get addrRemove => 'إزالة العنوان';

  @override
  String addrDeleteTitle(String label) {
    return 'حذف «$label»؟';
  }

  @override
  String get addrDeleteBody =>
      'تحتفظ الحجوزات السابقة على هذا العنوان بتفاصيلها. يمكنك إضافته مجددًا في أي وقت.';

  @override
  String get addrDeleted => 'تم حذف العنوان.';

  @override
  String get addrEditTitle => 'تعديل العنوان';

  @override
  String get addrNewTitle => 'عنوان جديد';

  @override
  String get addrLabel => 'التسمية';

  @override
  String get addrStreet => 'الشارع والمنطقة';

  @override
  String get addrStreetPlaceholder => 'مثال: شارع 9، المعادي';

  @override
  String get addrBuilding => 'المبنى';

  @override
  String get addrFloor => 'الطابق';

  @override
  String get addrApt => 'الشقة';

  @override
  String get addrLandmark => 'أقرب معلم';

  @override
  String get addrLandmarkPlaceholder => 'مثال: أمام الساقية';

  @override
  String get addrLandmarkHint =>
      'يساعد مقدّمي الخدمة على العثور عليك أسرع في الزيارة الأولى.';

  @override
  String get addrNotes => 'ملاحظات لمقدّم الخدمة';

  @override
  String get addrNotesPlaceholder => 'رمز البوابة، مكان الانتظار، أي جرس تضغط…';

  @override
  String get addrDefault => 'العنوان الافتراضي';

  @override
  String get addrDefaultSub => 'يُختار تلقائيًا في كل حجز منزلي';

  @override
  String get addrDeleteThis => 'حذف هذا العنوان';

  @override
  String get addrSave => 'حفظ العنوان';

  @override
  String get addrAdd => 'إضافة العنوان';

  @override
  String get addrPinDropped => 'تم تحديد الموقع';

  @override
  String get addrDropPin => 'حدّد الموقع';

  @override
  String get tcContactDefault => 'جهة اتصال';

  @override
  String get tcSafety => 'الأمان';

  @override
  String get tcRemoveTitle => 'إزالة جهة الاتصال هذه؟';

  @override
  String get tcRemoveBody =>
      'لن يتم تنبيهها بعد الآن إذا ضغطت زر الطوارئ أثناء خدمة منزلية.';

  @override
  String get tcRemove => 'إزالة';

  @override
  String get tcBannerTitle => 'يتم تنبيههم لحظة ضغطك زر الطوارئ';

  @override
  String get tcBannerBody =>
      'يستلمون موقعك المباشر برسالة نصية، ولا نشارك معهم أي شيء في أي وقت آخر.';

  @override
  String get tcEmpty => 'لا توجد جهة اتصال موثوقة بعد';

  @override
  String get tcEmptyBody =>
      'أضف شخصًا تودّ تنبيهه إذا شعرت بعدم الأمان أثناء خدمة منزلية.';

  @override
  String get tcAddContact => 'إضافة جهة اتصال';

  @override
  String get tcNew => 'جهة اتصال موثوقة جديدة';

  @override
  String get tcNameError => 'أدخل الاسم.';

  @override
  String get tcNamePlaceholder => 'الاسم الكامل';

  @override
  String get tcPhoneError => 'أدخل رقم هاتف صالحًا.';

  @override
  String get tcRelationship => 'صلة القرابة';

  @override
  String get tcRelationshipPlaceholder => 'أخت، صديق، شريك…';

  @override
  String get tcAdd => 'إضافة جهة الاتصال';

  @override
  String get tcAddAnother => 'إضافة جهة اتصال أخرى';

  @override
  String get supOpening => 'جارٍ فتح واتساب…';

  @override
  String get supNumber => 'رقم واتساب';

  @override
  String get supHours => 'ساعات الدعم';

  @override
  String get supEmail => 'البريد الإلكتروني البديل';

  @override
  String get supLanguages => 'اللغات';

  @override
  String get supEyebrow => 'الدعم';

  @override
  String get supTitle => 'تحدّث إلى AIWA';

  @override
  String get supHero => 'تحدّث مع شخص حقيقي عبر واتساب.';

  @override
  String get supHeroBody =>
      'نردّ بالعربية أو الإنجليزية، عادةً خلال دقائق في ساعات الدعم.';

  @override
  String get supOpenWhatsApp => 'افتح واتساب';

  @override
  String get supCommonQuestions => 'أسئلة شائعة';

  @override
  String get supQCancel => 'كيف ألغي حجزًا؟';

  @override
  String get supQPaid => 'متى يحصل مقدّم الخدمة على أجره؟';

  @override
  String get supQNoShow => 'لم يحضر مقدّم الخدمة';

  @override
  String get supQBecome => 'كيف أصبح مقدّم خدمة؟';

  @override
  String get polTerms => 'شروط الخدمة';

  @override
  String get polSafety => 'سياسة الأمان';

  @override
  String get polSafetySub => 'الزيارات المنزلية، التحقق من الهوية، الطوارئ';

  @override
  String get polCancel => 'سياسة الإلغاء';

  @override
  String get polCancelSub => 'المواعيد النهائية، الغرامات، عدم الحضور';

  @override
  String get polPrivacy => 'سياسة الخصوصية';

  @override
  String get polPrivacySub => 'ما نخزّنه ولأي مدة';

  @override
  String get polConduct => 'قواعد السلوك';

  @override
  String get polConductSub => 'ما نتوقعه من الجميع';

  @override
  String get polUpToDate => 'أنت على اطلاع بآخر التحديثات';

  @override
  String polUpToDateBody(Object version) {
    return 'لقد وافقت على الشروط الحالية (الإصدار $version). سنُعلمك إذا تغيّر أي شيء.';
  }

  @override
  String get polUpdated => 'شروط محدّثة بانتظار مراجعتك';

  @override
  String get polReview => 'مراجعة';

  @override
  String polAccepted(Object version) {
    return 'الإصدار $version · تمت الموافقة';
  }

  @override
  String get polNotAccepted => 'لم تتم الموافقة بعد';

  @override
  String polPlaceholder(String doc) {
    return 'هذا هو النص الكامل لـ«$doc»، ويُعرض بلغة العميل. يبقى متاحًا للقراءة دون اتصال ويسجّل الإصدار الذي وافقت عليه، لذا لن نطلب موافقتك مجددًا إلا عند حدوث تغيير جوهري.';
  }

  @override
  String get polSafetyTools => 'أدوات الأمان';

  @override
  String get polTrustedSub => 'يتم تنبيههم عند ضغطك زر الطوارئ';

  @override
  String get polHowSos => 'كيف يعمل زر الطوارئ';

  @override
  String get polHowSosSub => 'ماذا يحدث عند الضغط عليه';

  @override
  String get polDownloadPdf => 'تنزيل PDF';

  @override
  String get notifInbox => 'صندوق الوارد';

  @override
  String notifNewSuffix(int count) {
    return '· $count جديدة';
  }

  @override
  String get notifMarkAllRead => 'تحديد الكل كمقروء';

  @override
  String get notifCaughtUp => 'لا جديد لديك';

  @override
  String get notifCaughtUpBody =>
      'ستظهر هنا تحديثات الحجوزات والتقييمات وأخبار AIWA.';

  @override
  String get notifEarlier => 'سابقًا';

  @override
  String get notifJustNow => 'الآن';

  @override
  String notifMinAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'منذ $n دقيقة',
      many: 'منذ $n دقيقة',
      few: 'منذ $n دقائق',
      two: 'منذ دقيقتين',
      one: 'منذ دقيقة',
      zero: 'الآن',
    );
    return '$_temp0';
  }

  @override
  String notifHrAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'منذ $n ساعة',
      many: 'منذ $n ساعة',
      few: 'منذ $n ساعات',
      two: 'منذ ساعتين',
      one: 'منذ ساعة',
      zero: 'الآن',
    );
    return '$_temp0';
  }

  @override
  String get npPush => 'الإشعارات الفورية';

  @override
  String get npSms => 'الرسائل النصية';

  @override
  String get npChannels => 'القنوات';

  @override
  String get npQuietHours => 'ساعات الهدوء';

  @override
  String get npMute => 'كتم الإشعارات غير العاجلة';

  @override
  String get npFrom => 'من';

  @override
  String get npTo => 'إلى';

  @override
  String get tagPunctual => 'ملتزم بالمواعيد';

  @override
  String get tagSkilled => 'ماهر';

  @override
  String get tagFriendly => 'ودود';

  @override
  String get tagCleanStudio => 'مكان نظيف';

  @override
  String get tagWorthPrice => 'يستحق السعر';

  @override
  String get tagGreatHair => 'بارع في الشعر';

  @override
  String get reviewTapStar => 'اضغط على نجمة';

  @override
  String get reviewDisappointing => 'مخيّب للآمال';

  @override
  String get reviewBelow => 'أقل من المتوقع';

  @override
  String get reviewGood => 'جيد';

  @override
  String get reviewGreat => 'رائع';

  @override
  String get reviewOutstanding => 'ممتاز';

  @override
  String get reviewThanks => 'شكرًا — تقييمك منشور الآن.';

  @override
  String get reviewEyebrow => 'اكتب تقييمًا';

  @override
  String get reviewTitle => 'كيف كانت التجربة؟';

  @override
  String get reviewQuickTags => 'وسوم سريعة (اختياري)';

  @override
  String get reviewStoodOut => 'أخبر الآخرين بما لفت انتباهك';

  @override
  String get reviewHint => 'اختياري — سيظهر تقييمك للعامة في ملف مقدّم الخدمة.';

  @override
  String get reviewSubmit => 'إرسال التقييم';

  @override
  String get savedGuestTitle => 'احفظ مفضّلاتك';

  @override
  String get savedGuestBody =>
      'سجّل الدخول لحفظ مقدّمي الخدمة المفضّلين لديك وحجزهم أسرع في المرة القادمة.';

  @override
  String get savedEyebrow => 'مفضّلاتك';

  @override
  String get savedEmpty => 'لا توجد مفضّلات بعد';

  @override
  String get savedEmptyBody =>
      'اضغط على القلب في أي مقدّم خدمة لحفظه هنا والحجز مجددًا بلمسة واحدة.';

  @override
  String get savedBrowse => 'تصفّح مقدّمي الخدمة';

  @override
  String get savedBookAgain => 'احجز مجددًا';

  @override
  String get permLocEyebrow => 'إذن واحد سريع';

  @override
  String get permLocTitle => 'اعثر على خبراء الجمال بالقرب منك.';

  @override
  String get permLocBody =>
      'تستخدم AIWA موقعك لعرض مقدّمي الخدمة ضمن النطاق الذي تختاره ولمشاركة تحديثات الوصول المباشرة أثناء الزيارة المنزلية.';

  @override
  String get permLocP1 => 'يُستخدم فقط أثناء فتح التطبيق';

  @override
  String get permLocP2 => 'لا يُشارك أبدًا مع عملاء آخرين';

  @override
  String get permLocP3 => 'يمكنك اختيار منطقة يدويًا بدلًا من ذلك';

  @override
  String get permLocAllow => 'السماح بالوصول إلى الموقع';

  @override
  String get permLocDeny => 'اختيار منطقتي يدويًا';

  @override
  String get permNotifEyebrow => 'ابقَ على اطلاع';

  @override
  String get permNotifTitle => 'اعرف فور تأكيد حجزك.';

  @override
  String get permNotifBody =>
      'سنُعلمك عندما يقبل مقدّم الخدمة، وعندما يكون في الطريق، وعندما يحين موعدك.';

  @override
  String get permNotifP1 => 'تحديثات الحجز فقط افتراضيًا';

  @override
  String get permNotifP2 => 'حدّد ساعات الهدوء في أي وقت';

  @override
  String get permNotifP3 => 'أوقف قنوات بعينها من الإعدادات';

  @override
  String get permNotifAllow => 'تفعيل الإشعارات';

  @override
  String get permNotNow => 'ليس الآن';

  @override
  String get permCamEyebrow => 'خطوة التحقق';

  @override
  String get permCamTitle => 'نحتاج إلى الكاميرا.';

  @override
  String get permCamBody =>
      'للتحقق من مقدّمي الخدمة نلتقط صورة بطاقة الرقم القومي وسيلفي حيّة. هذا يحافظ على أمان كل عميل.';

  @override
  String get permCamP1 => 'المستندات مشفّرة وخاصة';

  @override
  String get permCamP2 => 'يراجعها فريق التحقق لدينا فقط';

  @override
  String get permCamP3 => 'لا تظهر أبدًا في ملفك العام';

  @override
  String get permCamAllow => 'افتح الكاميرا';

  @override
  String get permCamDeny => 'ارفع من الملفات بدلًا من ذلك';

  @override
  String get permDeniedCamTitle => 'الوصول إلى الكاميرا متوقف.';

  @override
  String get permDeniedCamBody =>
      'يتطلب التحقق صورة سيلفي حيّة. فعّل الكاميرا من الإعدادات، أو ارفع صورًا من ملفاتك.';

  @override
  String get permDeniedCamFallback => 'ارفع من الملفات';

  @override
  String get permDeniedNotifTitle => 'الإشعارات متوقفة.';

  @override
  String get permDeniedNotifBody =>
      'ستظل ترى كل التحديثات في صندوق الوارد داخل التطبيق، لكن لن نتمكن من تنبيهك عندما يكون مقدّم الخدمة في الطريق.';

  @override
  String get permDeniedNotifFallback => 'استخدم صندوق الوارد في التطبيق';

  @override
  String get permDeniedLocTitle => 'الموقع متوقف.';

  @override
  String get permDeniedLocBody =>
      'فعّله من الإعدادات، أو اختر منطقتك يدويًا وسنبحث منها.';

  @override
  String get permDeniedLocFallback => 'اختر منطقتي يدويًا';

  @override
  String get permNeeded => 'الإذن مطلوب';

  @override
  String get permOpenSettings => 'افتح الإعدادات';

  @override
  String get commonDone => 'تم';

  @override
  String get delCantUndo => 'لا يمكن التراجع عن هذا';

  @override
  String get delTitle => 'حذف حسابك؟';

  @override
  String delBody(String phrase) {
    return 'ستُجهَّل بياناتك وتُلغى أي حجوزات نشطة. اكتب $phrase للتأكيد.';
  }

  @override
  String get delPhrase => 'حذف';

  @override
  String get errLoadTitle => 'تعذّر تحميل هذا المحتوى';

  @override
  String get errLoadBody => 'حدث خطأ من جهتنا. حاول مرة أخرى.';

  @override
  String get commonTryAgain => 'حاول مجددًا';

  @override
  String get guestTitle => 'سجّل الدخول للمتابعة';

  @override
  String get guestBrowsing => 'تتصفّح كضيف';

  @override
  String get guestSignIn => 'سجّل الدخول أو أنشئ حسابًا';

  @override
  String get offlineBanner => 'لا يوجد اتصال — نعرض البيانات المحفوظة';

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get reasonNotePlaceholder => 'أخبرنا بما حدث (اختياري)';

  @override
  String get reasonKeepBooking => 'الإبقاء على الحجز';

  @override
  String get endOfList => 'هذا كل شيء';

  @override
  String get slotJustTaken => 'حُجز للتو';

  @override
  String get slotTitle => 'حجز شخص آخر هذا الموعد.';

  @override
  String slotBody(String name) {
    return 'حُجز في اللحظة الأخيرة. إليك ما زال متاحًا لدى $name اليوم.';
  }

  @override
  String get slotPickAnotherDay => 'اختر يومًا آخر';

  @override
  String get slotBook => 'احجز الموعد';

  @override
  String slotBookTime(String time) {
    return 'احجز $time';
  }

  @override
  String get sysSignedOut => 'تم تسجيل الخروج';

  @override
  String get sysSessionTitle => 'انتهت صلاحية جلستك.';

  @override
  String get sysSessionBody =>
      'حفاظًا على أمانك نسجّل خروجك بعد فترة من عدم النشاط. حجوزاتك ومقدّمو الخدمة المحفوظون ما زالوا هنا.';

  @override
  String get sysSignInAgain => 'سجّل الدخول مجددًا';

  @override
  String get sysLocked => 'الحساب مقفل';

  @override
  String get sysLockedTitle => 'هذا الحساب مقفل.';

  @override
  String get sysLockedBody =>
      'علّق فريقنا حسابك. يمكن لفريق الدعم توضيح السبب والخطوات التالية.';

  @override
  String get sysContactSupport => 'تواصل مع الدعم';

  @override
  String get sysBackToSignIn => 'العودة لتسجيل الدخول';

  @override
  String get sysNoAccess => 'لا تملك صلاحية';

  @override
  String get sysNoAccessTitle => 'لا يمكنك فتح هذه الصفحة.';

  @override
  String get sysNoAccessBody =>
      'هذا القسم مخصص لنوع مختلف من الحسابات. إذا كنت تعتقد أن هذا خطأ، تواصل مع الدعم.';

  @override
  String get sysGoBack => 'رجوع';

  @override
  String get sysNotFound => 'غير موجود';

  @override
  String get sysNotFoundTitle => 'هذه الصفحة غير متاحة.';

  @override
  String get sysNotFoundBody => 'ربما أُلغيت أو أُزيلت، أو أن الرابط قديم.';

  @override
  String get trackReschedule => 'تغيير الموعد';

  @override
  String get rescheduleTitle => 'اختر موعدًا جديدًا.';

  @override
  String rescheduleBody(String name, String date) {
    return '$name متاح في هذه الأوقات يوم $date.';
  }

  @override
  String get rescheduleNoSlots =>
      'لا توجد أوقات متاحة في ذلك اليوم. جرّب تاريخًا آخر.';

  @override
  String rescheduledToast(String time) {
    return 'تم النقل إلى $time';
  }

  @override
  String get reportsTitle => 'بلاغاتي';

  @override
  String get reportsEmpty => 'لم تقدّم أي بلاغ.';

  @override
  String reportsResolution(String note) {
    return 'ردّ AIWA: $note';
  }

  @override
  String get reportStatusOpen => 'تم الاستلام';

  @override
  String get reportStatusReview => 'قيد المراجعة';

  @override
  String get reportStatusResolved => 'تم الحل';

  @override
  String get staffEditDetails => 'تعديل البيانات';

  @override
  String get staffServicesHint => 'تقدّم هذه الخدمات (بدون اختيار = الكل)';

  @override
  String get staffSaved => 'تم تحديث بيانات الموظف.';

  @override
  String get staffDeactivate => 'إيقاف استقبال الحجوزات';

  @override
  String get staffDeactivated => 'تم إيقاف الموظف.';
}
