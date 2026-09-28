# Provider app: tab shell, today, bookings, booking detail, cancel/penalty, payment confirm, rate customer, notifications

Generated from the AIWA prototype-fidelity audit. Paths: prototype = `C:/Users/alyar/Desktop/AIWA Design System (2)/design_handoff_aiwa_app/`, Flutter = `Android/aiwa_app/`.

## Targeted findings

- **[MAJOR · components] No shared toast matching the kit Toast; the 6 ProviderApp toasts and 2 provider auth toasts are unimplemented** `PROV-C1`
  - Prototype: prototype.jsx:20-39 Toast: `position: 'absolute', top: 56, left: 16, right: 16`, `background: 'rgba(42,19,32,.96)'`, radius 14, padding 12px 16px, 26px success500 check chip, 13/500 text, 2800ms auto-dismiss. ProviderApp toasts: 'Business info saved.' (:443), 'Marked as disputed. Admin has been notified.' (:452), 'Rating submitted. Slot freed — next booking notified.' (:453), 'Alternative time sent to customer.' (:458), 'Booking cancelled. Penalty applied to your ledger.' (:488), 'Signed out.' (:491). Provider auth toasts: 'Account created. Verification in review.' (:601), 'Welcome back, Layla.' (:621).
  - Flutter now: Only SnackBarThemeData exists (app_theme.dart:185-193: floating at the bottom, no icon), and lib/shared/widgets has no toast helper.
  - Fix: Add shared/widgets/aiwa_toast.dart: `void showAiwaToast(BuildContext c, String msg)` inserts an OverlayEntry at `top: MediaQuery.paddingOf(c).top + 8, left: 16, right: 16`. It holds a Container(color: AppColors.plum900.withOpacity(.96), radius 14, padding 12/16) with a 26px AppColors.success500 circle + Icons.check 15 and a 13/500 bone label. Slide/fade over 320ms with AppTheme.easeSoft and remove after 2800ms.

- **[MAJOR · content] BookingModel JSON keys do not match the backend BookingDto used by every provider booking view** `PROV-C2`
  - Prototype: Provider views show customer name, 'Today · 12:30 PM', duration, price and customer note (provider-screens.jsx:4-11,96-105,332-336).
  - Flutter now: booking_model.dart:30-49 reads provider.fullName, scheduledDate, scheduledTime, customerNote and service.price. Backend BookingDto (ApiResponse.java) exposes customer, bookingDate, startTime, notes, totalPrice, travelFee and homeService.
  - Fix: Map `customerName: json['customer']?['fullName']`, `scheduledDate: json['bookingDate']`, `scheduledTime: json['startTime']`, `customerNote: json['notes']`, `totalPrice`, `travelFee`, `homeService` with fallbacks to the old keys so customer screens keep working.

- **[CRITICAL · interaction] Provider data layer targets endpoints and parameters the backend does not expose** `PROV-C3`
  - Prototype: All provider flows assume working data (ProviderApp, prototype.jsx:404-496).
  - Flutter now: api_constants.dart:30 '/provider/stats' (backend has /provider/dashboard); dashboard_remote_datasource.dart:60 sends status (ignored by BookingController.java:68-76); :80-83 sends the reject reason as a body (backend `@RequestParam String reason`); bookingComplete never passes cashCollected. The settlement, provider mode, staff and propose-time endpoints are absent from ApiConstants.
  - Fix: Align ApiConstants with the backend controllers (ProviderController, BookingController, SettlementController, ProviderModeController, StaffController, GalleryController) and add a contract test per datasource method using recorded backend JSON.

- **[MINOR · components] Tab bar is private to the customer shell and cannot be reused for the provider shell** `PROV-C4`
  - Prototype: TabBar (components.jsx:203-237) and ProviderTabBar (provider-screens.jsx:562-596) share one visual spec.
  - Flutter now: shell_page.dart:36-158 `_TabBar` / `_TabItem` are private, with customer routes hard-coded.
  - Fix: Extract to shared/widgets/aiwa_tab_bar.dart with a `List<AiwaTab>` parameter and optional badge; use it in both ShellPage and the new ProviderShellPage.

- **[MINOR · components] Missing shared primitives the provider screens need: Toggle, Tag, stepper** `PROV-C5`
  - Prototype: states.jsx:209-224 Toggle (42x24, knob 18, warn tone); states.jsx:397-410 Tag (3px 9px, radius 999, 11/700, eight tones); schedule/profile inline 40x22 toggles; travel-buffer stepper (provider-screens.jsx:468-470).
  - Flutter now: lib/shared/widgets has no toggle, tag or stepper widget (class list: AiwaAvatar, AiwaButton, AiwaChip, AiwaIconButton, AiwaTextField, EmptyState, ErrorState, EyebrowLabel, GuestLockedView, Shimmer*, ScreenHeader, PageTitle, StickyBar, SettingsRow, InlineBanner, EndOfList, MetaDot, AiwaGlow, AiwaWordmark, SectionHeader, StarRating, StatusPill).
  - Fix: Add AiwaToggle({value, onChanged, tone}) and AiwaTag({label, tone}) with the kit sizes before building PROV-26..PROV-47.

- **[MINOR · tokens] Hard-coded rgba literals in the prototype are mapped to theme tokens in Flutter** `PROV-C6`
  - Prototype: provider-screens.jsx:45,56,498 and provider-extras.jsx:31 use literal rgba(231,186,182,.3/.4) and rgba(250,245,238,.12), identical in both palettes.
  - Flutter now: dashboard_page.dart:207-211,353 use AppColors.rose300 / AppColors.bone opacity, which change per gender (male #B5A898 vs the prototype's pink).
  - Fix: Keep the token approach (more consistent), but document it as an intentional deviation in the theme README. If exact parity is required, add `static const heroGlow = Color(0xFFE7BAB6);` to AppColors.


## Entries

### ProviderTabBar (Today / Bookings / Services / Schedule / Profile) — `PROV-01` (component, missing)
- How the user reaches it: Provider app -> visible on every tab root (today, bookings, services, schedule, profile); hidden on pushed screens
- Prototype source: ui_kits/aiwa-app/provider-screens.jsx:562-596; ui_kits/aiwa-app/prototype.jsx:465-471,485
- Flutter files: Android/aiwa_app/lib/core/router/app_router.dart, Android/aiwa_app/lib/features/shell/shell_page.dart
- Key elements: 5 tabs: layout-dashboard 'Today', calendar-check 'Bookings' (8px rose500 badge dot, 2px #fff border), list 'Services', clock 'Schedule', user 'Profile'; Bar: rgba(255,255,255,.94) + backdropFilter blur(20px), top border divider, padding 8px 4px 26px, zIndex 30; Active item: plum100 pill, radius 14, padding 6px 10px, maxWidth 76; icon 22 + label 11/600 plum700; inactive ink3; Tab change = reset(t) with fade transition
- To build: Add a provider ShellRoute (/provider/today, /provider/bookings, /provider/services, /provider/schedule, /provider/profile) wrapped by a ProviderShellPage. Extract the private _TabBar/_TabItem from shell_page.dart into shared/widgets/aiwa_tab_bar.dart taking a list of (icon, activeIcon, label, route, showBadge) so both shells reuse it. For the provider variant use item maxWidth 76 and horizontal padding 10 (customer uses 80/12). Icons: Icons.dashboard_outlined, Icons.event_available_outlined (+8px AppColors.rose500 dot with a 2px paper border when pendingBookings > 0), Icons.list_rounded, Icons.schedule_rounded, Icons.person_outline_rounded. Use NoTransitionPage or a fade for tab roots. Point the sign-in/splash provider redirects at /provider/today.

### Provider post-sign-in / session-restore routing — `PROV-02` (state, deviates)
- How the user reaches it: Splash -> English -> I'm a provider -> Sign in -> (submit) -> provider-pending; approved provider = ProviderApp 'today'
- Prototype source: ui_kits/aiwa-app/prototype.jsx:619-626,651
- Flutter files: Android/aiwa_app/lib/features/auth/presentation/pages/sign_in_page.dart, Android/aiwa_app/lib/features/auth/presentation/pages/splash_page.dart, Android/aiwa_app/lib/features/auth/presentation/pages/provider_pending_page.dart, Android/aiwa_app/lib/core/router/app_router.dart
- Key elements: Sign-in as PROVIDER: setToast('Welcome back, Layla.') then reset('provider-pending'); ProviderPending 'continue' -> reset('home') (customer home); Approved provider lands on ProviderApp tab 'today'
- Findings:
  - **[CRITICAL · interaction] Unapproved providers skip the pending-verification gate on sign-in and on session restore** `PROV-02-F1`
    - Prototype: prototype.jsx:622 `if (signup.role === 'PROVIDER') { reset('provider-pending'); }`. The provider walkthrough (prototype.jsx:922-929) shows the Today app only after admin approval.
    - Flutter now: sign_in_page.dart:66-70 and splash_page.dart:71-75 call `context.go(state.user.isProvider ? AppRoutes.providerDashboard : AppRoutes.home)` with no verification check. The approval flag is also unusable. user_model.dart:36-39 reads `json['providerProfile']`, but the backend login and /auth/me UserDto (AuthServiceImpl.java:246-261, AuthController.java:343-358) never sets providerProfile, providerProfileId or providerStatus. user.providerProfile is therefore always null, and `isApproved` (user_entity.dart:66) is always false.
    - Fix: Backend: in both toUserDto builders set `.providerProfileId(p.getId()).providerStatus(p.getVerificationStatus())` for PROVIDER users. Flutter UserModel.fromJson: `providerProfile: json['providerStatus'] != null ? ProviderProfileSummaryModel(id: json['providerProfileId'] as int? ?? 0, businessName: '', verificationStatus: json['providerStatus'] as String) : null`. Then in both listeners: `final u = state.user; context.go(!u.isProvider ? AppRoutes.home : (u.providerProfile?.isApproved ?? false) ? AppRoutes.providerDashboard : AppRoutes.providerPending);`. Add a GoRouter redirect on the provider routes as well. Without the mapping, this fix sends every provider to /provider-pending.

### Provider Today dashboard (hero header + stat tiles + section structure) — `PROV-03` (screen, deviates)
- How the user reaches it: Provider app -> Today tab (default tab)
- Prototype source: ui_kits/aiwa-app/provider-screens.jsx:35-139; ui_kits/aiwa-app/prototype.jsx:437
- Flutter files: Android/aiwa_app/lib/features/provider_dashboard/presentation/pages/dashboard_page.dart, Android/aiwa_app/lib/features/provider_dashboard/presentation/bloc/dashboard_bloc.dart, Android/aiwa_app/lib/features/provider_dashboard/data/datasources/dashboard_remote_datasource.dart, Android/aiwa_app/lib/core/constants/api_constants.dart
- Key elements: Hero: linear-gradient(160deg, plum700, plum900) + radial rgba(231,186,182,.3) at 80% 20%; padding 68px 22px 26px; Eyebrow 'Hello, Nadia' rose300; h1 'Today's schedule.' DM Serif 26 / lh 1.1 / -0.01em bone; Avatar rose 44 verified on the right; 3 glass stat tiles rgba(250,245,238,.12) blur(8px) radius 14 padding 12px 14px: '3' TODAY, '1,730' EGP TODAY, star 4.9 / 312 REVIEWS (value DM Serif 24, label 11/600 .08em uppercase rose300); Then pending callout -> SectionHeader 'New requests' ('N pending') -> request cards -> SectionHeader 'Confirmed today' -> today rows; paddingBottom 100 for the tab bar
- Findings:
  - **[CRITICAL · states] Dashboard stats call hits a non-existent endpoint, so the page never leaves the loading skeleton** `PROV-03-F1`
    - Prototype: provider-screens.jsx:35-139: ProviderDashboard always renders the hero stats and the request lists.
    - Flutter now: dashboard_remote_datasource.dart:37 calls `_api.get(ApiConstants.providerStats)`, which is '/provider/stats' (api_constants.dart:30). The backend only maps GET /provider/dashboard (ProviderController.java:89; DashboardDto has todayBookings and no totalReviews). _ErrorInterceptor turns the 404 into a thrown ServerException (api_client.dart:138-160). Dio 5.9.2 wraps errors thrown inside interceptors in a DioException (dio_mixin.dart:516-523, assureDioException), so the `on ServerException` in DashboardRepositoryImpl.getStats (dashboard_repository_impl.dart:18-22) never matches. The DioException escapes _onLoad after `emit(DashboardLoading())` (dashboard_bloc.dart:29-30). dashboard_page.dart:109-120 keeps showing ShimmerBox and SkeletonList, and the ErrorState branch (103-108) is never reached. This comes from static reading of the Dio source; the app was not run.
    - Fix: api_constants.dart: add `static const String providerDashboard = '/provider/dashboard';` and parse DashboardDto in getStats(), including todayBookings and confirmedBookings. totalReviews needs a backend field. Also fix the error plumbing so failures reach the UI. In _ErrorInterceptor, call `handler.reject(DioException(requestOptions: err.requestOptions, response: err.response, error: ServerException(message: ..., statusCode: ...)))` instead of throwing. In the repositories, add `on DioException catch (e) { final x = e.error; return Left(x is ServerException ? ServerFailure(x.message) : NetworkFailure(e.message ?? 'Network error')); }`.
  - **[MAJOR · layout] Section structure replaced by a status filter row** `PROV-03-F2`
    - Prototype: provider-screens.jsx:88-137: `<SectionHeader title="New requests" action={pending.length + ' pending'} />` + pending cards, then `<SectionHeader title="Confirmed today" />` + today rows.
    - Flutter now: dashboard_page.dart:126-183: hero -> _PendingCallout -> `_buildFilter(state.filterStatus)` (Pending/Upcoming/Done/Cancelled) -> one SliverList of _RequestCard.
    - Fix: Rebuild the slivers as [header, callout, SectionHeader(title: 'New requests', action: '${pending.length} pending'), pending _RequestCards, SectionHeader(title: 'Confirmed today'), _TodayRow list (PROV-06)]. Move the filter tabs to a new ProviderBookingsPage (PROV-08). SectionHeader already exists in shared/widgets/section_header.dart.
  - **[MAJOR · content] Stat tiles show pending count and lifetime compact revenue instead of today's count and today's EGP** `PROV-03-F3`
    - Prototype: provider-screens.jsx:57-69: `{today.length}` 'Today'; '1,730' 'EGP today'; star '4.9' / '312 reviews'.
    - Flutter now: dashboard_page.dart:262-272: `value: '${stats.pendingBookings}', label: 'Pending'` and `NumberFormat.compact(locale: 'en').format(stats.totalRevenue)` (e.g. '1.7K'), `label: 'EGP earned'`.
    - Fix: `_StatTile(value: '${stats.todayBookings.length}', label: 'Today')` and `_StatTile(value: NumberFormat.decimalPattern('en').format(todayRevenue), label: 'EGP today')`, where todayRevenue sums totalPrice of today's bookings (or comes from a new backend field).
  - **[MAJOR · states] Accept/decline/advance failures are swallowed, and every action reloads to a full-screen skeleton and resets the filter** `PROV-03-F6`
    - Prototype: provider-screens.jsx:344 Accept updates in place (`onClick={() => setSt('confirmed')}`); errors are surfaced through toasts elsewhere in the kit.
    - Flutter now: dashboard_bloc.dart:63-68 `await _repository.acceptBooking(event.bookingId); add(DashboardLoadEvent());` discards the Either (same at :70-106). _onLoad emits `DashboardLoading()` (:29), so dashboard_page.dart:109-120 swaps to ShimmerBox/SkeletonList, and filterStatus is forced back to 'PENDING' (:41).
    - Fix: `final r = await _repository.acceptBooking(id); r.fold((f) => emit(current.copyWith(error: f.message)), (_) {});` and then refresh without emitting DashboardLoading (a silent reload that keeps filterStatus). Show failures with the shared toast.
  - **[CRITICAL · interaction] Today is a dead-end route with no navigation to the other provider tabs** `PROV-03-F7`
    - Prototype: prototype.jsx:471,485: `showTabBar = ['today','bookings','services','schedule','profile'].includes(current.name)` renders ProviderTabBar on Today.
    - Flutter now: app_router.dart:223-226 `GoRoute(path: AppRoutes.providerDashboard, builder: (_, __) => const DashboardPage())` has no ShellRoute or bottomNavigationBar. The DashboardPage Scaffold (dashboard_page.dart:98-100) has only a body.
    - Fix: Host DashboardPage inside a provider ShellRoute (PROV-01). app_router.dart:180-186 already declares `GoRoute(path: '/provider/:id')` for the customer ProviderDetailPage, and go_router uses the first matching route. Paths like '/provider/today' or '/provider/bookings' would therefore open ProviderDetailPage(id: 'today') unless the new ShellRoute is declared before that route. A distinct prefix is safer, e.g. '/pro/today', '/pro/bookings', '/pro/services', '/pro/schedule', '/pro/profile' (and '/pro/bookings/:id' for detail).

### Pending booking requests callout — `PROV-04` (banner, implemented)
- How the user reaches it: Provider app -> Today tab (shown only when pending > 0)
- Prototype source: ui_kits/aiwa-app/provider-screens.jsx:74-86
- Flutter files: Android/aiwa_app/lib/features/provider_dashboard/presentation/pages/dashboard_page.dart
- Key elements: warn100 card, 1px warn500@20% border, radius 16, padding 14, margin 16px 22px 0; 36px warn500 circle with alarm-clock icon 18 #fff; '{n} new booking requests' 14/600 warn700; 'Reply within 30 minutes to keep your top rating.' 12 warn700 @.85; chevron-right 18 warn700

### 'New requests' section and booking request card (Decline / Accept) — `PROV-05` (component, deviates)
- How the user reaches it: Provider app -> Today tab -> New requests list
- Prototype source: ui_kits/aiwa-app/provider-screens.jsx:88-113
- Flutter files: Android/aiwa_app/lib/features/provider_dashboard/presentation/pages/dashboard_page.dart, Android/aiwa_app/lib/features/bookings/data/models/booking_model.dart, Android/aiwa_app/lib/features/provider_dashboard/data/datasources/dashboard_remote_datasource.dart
- Key elements: SectionHeader 'New requests' with action '{n} pending'; Card #fff radius 18 padding 14 border divider shadow 0 1px 2px rgba(74,31,56,.04); whole card tappable -> booking-detail; Avatar plum 42; customer 15/600 ink; 'service · duration' 12 ink3; StatusPill pending; Divider row: calendar 13 ink3 + 'Today · 12:30 PM' 12 ink2; 'EGP 350' DM Serif 18 plum900; Decline (secondary sm) + Accept (primary sm, check icon), flex 1 each, gap 8
- Findings:
  - **[CRITICAL · interaction] Request card is not tappable, so there is no way into the booking detail** `PROV-05-F1`
    - Prototype: provider-screens.jsx:92 `onClick={() => onBooking(b.id)}` -> prototype.jsx:437 `push('booking-detail')`.
    - Flutter now: dashboard_page.dart:514-590: _RequestCard returns a bare Container with no GestureDetector/InkWell, and no provider booking-detail route exists in app_router.dart.
    - Fix: Wrap the card: `InkWell(borderRadius: BorderRadius.circular(18), onTap: () => context.push('/provider/bookings/${b.id}'), child: ...)` and add that route (PROV-13).
  - **[CRITICAL · interaction] Decline sends the reason in the body, but the backend requires a query parameter, so every decline fails silently** `PROV-05-F2`
    - Prototype: provider-screens.jsx:343 Decline -> prototype.jsx:459 `else { pop(); }` (request declined).
    - Flutter now: dashboard_remote_datasource.dart:80-83 `_api.patch(ApiConstants.bookingReject(bookingId), data: {'reason': reason})`. The backend declares `@RequestParam String reason` (required) (aiwa-backend BookingController.java:102-110), so the call returns 400. dashboard_bloc.dart:73-74 ignores the Left and reloads with the booking still pending. The sheet also labels the reason 'optional' (dashboard_page.dart:62) even though the backend requires it.
    - Fix: `_api.patch(ApiConstants.bookingReject(id), queryParameters: {'reason': reason.isEmpty ? 'Declined by provider' : reason})` (add queryParameters to ApiClient.patch if it lacks it). Parse `data['booking']`, because the response is BookingWithAlternativesDto. Surface failures.
  - **[MAJOR · content] Request card shows the placeholder 'Customer' instead of the customer's name** `PROV-05-F3`
    - Prototype: provider-screens.jsx:94-96 `<Avatar name={b.customer} palette="plum" size={42} />` and `{b.customer}` (e.g. 'Hana K.').
    - Flutter now: dashboard_page.dart:513 `final customer = b.providerName.isEmpty ? 'Customer' : b.providerName;` with booking_model.dart:33 `providerName: provider['fullName']`. Backend BookingDto.provider is a ProviderSummaryDto (ApiResponse.java:91-109: businessName and ownerName, no fullName), so providerName is always '' and every card renders 'Customer' with a 'C' avatar. The real name sits in BookingDto.customer.fullName (ApiResponse.java:234, UserDto), which BookingModel never reads.
    - Fix: Add `final String customerName;` (and optionally customerImageUrl) to BookingEntity and map it in BookingModel.fromJson: `customerName: (json['customer'] as Map<String, dynamic>?)?['fullName'] as String? ?? ''`. Use b.customerName for the text and the AiwaAvatar name in _RequestCard.
  - **[MAJOR · content] Date/time line renders empty because of wrong JSON keys; time is 24h instead of 12h** `PROV-05-F4`
    - Prototype: provider-screens.jsx:103 `{b.when}`, e.g. 'Today · 12:30 PM'.
    - Flutter now: booking_model.dart:41-42 reads `json['scheduledDate']` / `json['scheduledTime']`, but the backend BookingDto fields are `bookingDate` / `startTime`, so _when (dashboard_page.dart:495-508) yields ' · '. Even with data it prints `scheduledTime.substring(0, 5)` ('12:30').
    - Fix: `scheduledDate: json['bookingDate'] ?? json['scheduledDate'] ?? ''`, `scheduledTime: json['startTime'] ?? json['scheduledTime'] ?? ''`. Format with `DateFormat('h:mm a')`.
  - **[MAJOR · layout] 'New requests' section header with the pending count is missing** `PROV-05-F5`
    - Prototype: provider-screens.jsx:89 `<SectionHeader title="New requests" action={pending.length + ' pending'} />`.
    - Flutter now: dashboard_page.dart:136 inserts `_buildFilter(...)` instead; there is no SectionHeader in DashboardPage.
    - Fix: `SliverToBoxAdapter(child: SectionHeader(title: 'New requests', action: '${pending.length} pending'))` above the pending list.
  - **[MAJOR · interaction] Inline Accept/Decline act immediately instead of opening the booking detail** `PROV-05-V1`
    - Prototype: provider-screens.jsx:108-109 `<Btn variant="secondary" size="sm" style={{ flex: 1 }}>Decline</Btn>` and `<Btn variant="primary" size="sm" ... icon="check">Accept</Btn>` have no onClick. The tap bubbles to the card's `onClick={() => onBooking(b.id)}` (:92), which pushes 'booking-detail' (prototype.jsx:437). The real accept/decline happens in the detail bar (provider-screens.jsx:340-348), after the provider has seen the address, the travel-fee option and the customer note.
    - Flutter now: dashboard_page.dart:619-634: Accept calls onAccept, which sends DashboardAcceptBookingEvent and PATCHes /accept immediately (dashboard_bloc.dart:63-68). Decline opens the Flutter-only reason sheet (dashboard_page.dart:52-67) and rejects from the list.
    - Fix: Once ProviderBookingDetailPage exists, point both inline buttons at it: `onPressed: () => context.push('/pro/bookings/${b.id}')`. Keep them as direct quick actions only if product explicitly approves skipping the detail review.

### 'Confirmed today' section (today's confirmed bookings) — `PROV-06` (component, missing)
- How the user reaches it: Provider app -> Today tab -> below New requests
- Prototype source: ui_kits/aiwa-app/provider-screens.jsx:115-131
- Flutter files: none yet
- Key elements: SectionHeader 'Confirmed today'; Row card #fff radius 16 padding 14 border divider; 4px info500 left stripe (radius 4, stretches full height); Avatar rose 40; name 14/600 ink; service 12 ink3; Right: time JetBrains Mono 14/600 plum900 ('12:30 PM', 'Today · ' stripped); duration 11 ink3; Not tappable
- To build: Use DashboardDto.todayBookings from GET /provider/dashboard (see PROV-03-F1). Add `SectionHeader(title: 'Confirmed today')` and a private _TodayRow: `Container(padding: EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)), child: IntrinsicHeight(child: Row(children: [Container(width: 4, decoration: BoxDecoration(color: AppColors.info500, borderRadius: BorderRadius.circular(4))), SizedBox(width: 12), AiwaAvatar(palette: AvatarPalette.rose, size: 40), ... , Column(crossAxisAlignment: end, children: [Text(time, style: AppTextStyles.mono.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.plum900)), Text(duration, style: AppTextStyles.micro)])])))`. Filter out PENDING.

### 'Confirmed today' empty state — `PROV-07` (state, missing)
- How the user reaches it: Provider app -> Today tab (no non-pending bookings today)
- Prototype source: ui_kits/aiwa-app/provider-screens.jsx:132-136
- Flutter files: none yet
- Key elements: Centered text 'Nothing else on the books for today.' 13px ink3, padding 24
- To build: Inside the PROV-06 sliver: when today's non-pending list is empty, render `Padding(padding: EdgeInsets.all(24), child: Text('Nothing else on the books for today.', textAlign: TextAlign.center, style: AppTextStyles.meta.copyWith(color: AppColors.ink3)))`. Plain text, not EmptyState.

### Provider Bookings screen (header + Pending/Upcoming/Past tab row + list) — `PROV-08` (screen, deviates)
- How the user reaches it: Provider app -> Bookings tab
- Prototype source: ui_kits/aiwa-app/provider-screens.jsx:145-190; ui_kits/aiwa-app/prototype.jsx:438
- Flutter files: Android/aiwa_app/lib/features/provider_dashboard/presentation/pages/dashboard_page.dart, Android/aiwa_app/lib/features/provider_dashboard/presentation/bloc/dashboard_bloc.dart, Android/aiwa_app/lib/features/provider_dashboard/data/datasources/dashboard_remote_datasource.dart
- Key elements: Header padding 68px 22px 8px: Eyebrow 'Manage', h1 'Bookings' DM Serif 28 plum900 lh 1.05; Underline tab row gap 18, padding 14px 22px 0, border-bottom divider; tab 14/600, active plum700 + 2px plum700 underline, inactive ink3; List padding 14px 22px 0, gap 10; compact rows open booking-detail
- Findings:
  - **[CRITICAL · interaction] Status tabs are dead: the backend ignores the status parameter, so every tab lists the same bookings** `PROV-08-F1`
    - Prototype: provider-screens.jsx:147-151 filters pending / confirmed / completed per tab.
    - Flutter now: dashboard_remote_datasource.dart:57-61 sends `'status': status`, but aiwa-backend BookingController.java:68-76 `providerBookings(@RequestParam page, @RequestParam size)` has no status parameter, and BookingServiceImpl.java:254 calls `findByProviderIdOrderByBookingDateAscStartTimeAsc`, which is unfiltered.
    - Fix: Backend: add `@RequestParam(required = false) List<BookingStatus> status` and a repository `findByProviderIdAndStatusIn...`. Flutter: send `'status': 'ACCEPTED,ON_THE_WAY,ARRIVED,IN_PROGRESS'` for Upcoming.
  - **[MAJOR · layout] No standalone Bookings tab screen with its 'Manage / Bookings' header** `PROV-08-F2`
    - Prototype: provider-screens.jsx:154-157 `<Eyebrow>Manage</Eyebrow><h1 ... fontSize: 28 ...>Bookings</h1>`, reached via the Bookings tab.
    - Flutter now: The tab row is rendered at dashboard_page.dart:136 below the Today hero; there is no page title.
    - Fix: Create features/provider_dashboard/presentation/pages/provider_bookings_page.dart: `PageTitle(eyebrow: 'Manage', title: 'Bookings', bottom: 8)` (screen_chrome.dart:85 already renders h1 28 / lh 1.05), then move `_buildFilter` and the list there, mounted at /provider/bookings.
  - **[MAJOR · components] List rows reuse the big action card instead of the compact booking row** `PROV-08-F3`
    - Prototype: provider-screens.jsx:172-185: row radius 16, avatar plum 42, name 14/600, service 12, calendar line 12 ink2, right column `<StatusPill>` over 'EGP' DM Serif 16. No buttons.
    - Flutter now: dashboard_page.dart:162-177 renders `_RequestCard` (radius 18, price 18, inline Decline/Accept/On my way/etc. buttons) for every tab.
    - Fix: Add a _BookingRow widget with that spec for the Bookings tab and keep _RequestCard only for Today's 'New requests'.
  - **[MAJOR · states] Tab switch failures are silently ignored and no loading feedback is shown** `PROV-08-F5`
    - Prototype: provider-screens.jsx:160 setTab switches the list instantly.
    - Flutter now: dashboard_bloc.dart:51-60 `result.fold((_) {}, ...)`: on error the underline stays on the old tab and nothing happens; there is no pending indicator while the request runs.
    - Fix: Emit `current.copyWith(filterStatus: s, loadingList: true)` first and on failure emit an error flag rendered as ErrorState(compact: true, onRetry: ...).

### Bookings tab: Pending — `PROV-09` (tab, deviates)
- How the user reaches it: Provider app -> Bookings tab -> Pending (default)
- Prototype source: ui_kits/aiwa-app/provider-screens.jsx:147-148,171-186
- Flutter files: Android/aiwa_app/lib/features/provider_dashboard/presentation/pages/dashboard_page.dart
- Key elements: Rows with status 'pending' only; Compact row + StatusPill 'Pending' + price; tap -> booking-detail
- Findings:
  - **[MAJOR · components] Pending rows carry inline Decline/Accept buttons instead of the compact row** `PROV-09-F1`
    - Prototype: provider-screens.jsx:172-185: compact row, no buttons.
    - Flutter now: dashboard_page.dart:617-635: a Decline/Accept pair on every PENDING card in this list.
    - Fix: Render _BookingRow (see PROV-08-F3) in the Bookings tab.
  - **[MAJOR · content] Rows show the placeholder 'Customer' and an empty date (same root cause as PROV-05-F3/F4)** `PROV-09-F2`
    - Prototype: provider-screens.jsx:175,178 `{b.customer}`, `{b.when}`.
    - Flutter now: booking_model.dart:33 maps provider['fullName'], which ProviderSummaryDto (ApiResponse.java:91-109) does not have, so dashboard_page.dart:513 falls back to 'Customer'. booking_model.dart:41-42 read scheduledDate/scheduledTime instead of bookingDate/startTime, so the date line renders ' · '.
    - Fix: Apply the BookingModel mapping from PROV-05-F3/F4: customerName from json['customer']['fullName'], plus bookingDate and startTime.
  - **[CRITICAL · interaction] Rows do not open booking detail, and the tab does not actually filter** `PROV-09-F3`
    - Prototype: provider-screens.jsx:172 `onClick={() => onBooking(b.id)}`; :148 `filter(b => b.status === 'pending')`.
    - Flutter now: _RequestCard has no tap (dashboard_page.dart:514); the backend ignores status (PROV-08-F1).
    - Fix: See PROV-05-F1 and PROV-08-F1.

### Bookings tab: Upcoming — `PROV-10` (tab, deviates)
- How the user reaches it: Provider app -> Bookings tab -> Upcoming
- Prototype source: ui_kits/aiwa-app/provider-screens.jsx:149-150,171-186
- Flutter files: Android/aiwa_app/lib/features/provider_dashboard/presentation/pages/dashboard_page.dart
- Key elements: Rows with status 'confirmed'; StatusPill 'Confirmed' (info palette); tap -> booking-detail (job progress)
- Findings:
  - **[MAJOR · states] In-flight jobs (ON_THE_WAY / ARRIVED / IN_PROGRESS) belong to no tab once filtering works** `PROV-10-F1`
    - Prototype: provider-screens.jsx:149-150 'upcoming' = confirmed jobs; job progress is then handled in booking detail (provider-screens.jsx:199-209).
    - Flutter now: dashboard_page.dart:38-43 filters are exactly PENDING, ACCEPTED, COMPLETED, CANCELLED. After 'On my way' (dashboard_page.dart:638-642) the booking becomes ON_THE_WAY and would drop out of every tab. It currently still shows only because the backend ignores the filter (PROV-08-F1).
    - Fix: Make Upcoming query ACCEPTED + ON_THE_WAY + ARRIVED + IN_PROGRESS (a multi-status param).
  - **[MAJOR · components] Upcoming rows embed status-advance buttons instead of the compact row** `PROV-10-F2`
    - Prototype: provider-screens.jsx:172-185: no buttons; actions live in the detail's bottom bar (provider-screens.jsx:350-360).
    - Flutter now: dashboard_page.dart:636-659: 'On my way' / "I've arrived" / 'Start service' buttons inside each card.
    - Fix: Use _BookingRow in the list and move the advance actions to the booking detail sticky bar (PROV-13/PROV-14).
  - **[MAJOR · content] Wrong name and empty date (BookingModel mapping)** `PROV-10-F3`
    - Prototype: provider-screens.jsx:175,178.
    - Flutter now: booking_model.dart:33,41-42.
    - Fix: See PROV-05-F3/F4.
  - **[CRITICAL · interaction] Rows do not open booking detail** `PROV-10-F4`
    - Prototype: provider-screens.jsx:172 onBooking -> prototype.jsx:438 push('booking-detail').
    - Flutter now: dashboard_page.dart:514: not tappable.
    - Fix: See PROV-05-F1.

### Bookings tab: Past — `PROV-11` (tab, deviates)
- How the user reaches it: Provider app -> Bookings tab -> Past
- Prototype source: ui_kits/aiwa-app/provider-screens.jsx:151,159,171-186
- Flutter files: Android/aiwa_app/lib/features/provider_dashboard/presentation/pages/dashboard_page.dart
- Key elements: Rows with status 'completed'; StatusPill 'Completed' (success palette); tap -> booking-detail
- Findings:
  - **[MAJOR · components] Past rows use the large request card (price 18, radius 18) instead of the compact row with the pill on the right** `PROV-11-F2`
    - Prototype: provider-screens.jsx:181-184 right column: StatusPill + 'EGP' DM Serif 16.
    - Flutter now: dashboard_page.dart:162-177 _RequestCard with the StatusPill in the header row and price 18 (dashboard_page.dart:554,580-583).
    - Fix: Use _BookingRow (PROV-08-F3).
  - **[CRITICAL · interaction] Past rows do not open booking detail** `PROV-11-F3`
    - Prototype: provider-screens.jsx:172 onBooking.
    - Flutter now: dashboard_page.dart:514: no tap.
    - Fix: See PROV-05-F1.

### Bookings list empty state — `PROV-12` (state, deviates)
- How the user reaches it: Provider app -> Bookings tab -> any tab with no bookings
- Prototype source: ui_kits/aiwa-app/provider-screens.jsx:170
- Flutter files: Android/aiwa_app/lib/features/provider_dashboard/presentation/pages/dashboard_page.dart, Android/aiwa_app/lib/shared/widgets/empty_state.dart
- Key elements: Plain centered text 'Nothing here yet.' 13px ink3, padding 40

### Booking request detail — Review & respond (pending) — `PROV-13` (sub-screen, missing)
- How the user reaches it: Provider app -> Today (New requests card) or Bookings (any row) -> Booking detail
- Prototype source: ui_kits/aiwa-app/provider-screens.jsx:195-349; ui_kits/aiwa-app/prototype.jsx:454-460
- Flutter files: none yet
- Key elements: Header: back IconBtn, Eyebrow 'Booking request', h2 'Review & respond' DM Serif 22, StatusPill(st); Customer card: Avatar plum 54, name DM Serif 20, badge-check gold500 'Verified' · '4 prior bookings', message-circle IconBtn; Home-service address card: map-pin tile plum100/plum700 34, 'HOME SERVICE ADDRESS' 11/600 uppercase, address 13.5 (or 'No address attached'); Details card: Service / Duration / Requested / Service price / Travel fee (pending) gold700 / 'Total · cash' DM Serif 22; Customer note cream card with Eyebrow 'Customer note'; Pending action bar (absolute bottom, #fff, top border, padding 14px 22px 32px): Decline secondary lg + Accept primary lg check (both dimmed while a quote is pending), ghost sm 'Quote a travel fee instead' (car), ghost sm 'Propose a different time instead' (calendar-clock); Accept -> in-place st='confirmed' (job progress); Decline -> pop
- To build: Add route /provider/bookings/:id -> ProviderBookingDetailPage, pushed from _RequestCard and _BookingRow. Load with GET /bookings/{id} (ApiConstants.bookingById exists). Extend BookingEntity/BookingModel with customerName, customerVerified, homeService, savedAddress (label/line), notes, travelFee, totalPrice, proposedDate/proposedStartTime (all present in backend BookingDto). Create a ProviderBookingDetailBloc with Accept (PATCH /accept), Decline (PATCH /reject?reason=), ProposeTime (PATCH /bookings/{id}/propose-time, backend BookingController.java:168), Cancel (PATCH /bookings/{id}/cancel?reason=) and the Advance events (existing repository methods). Reuse ScreenHeader, AiwaAvatar, StatusPill, InlineBanner, AiwaButton (lg), StickyBar and AiwaIconButton. The chat icon needs a chat feature, which does not exist in Flutter. Total = service price + travel fee.

### Booking detail — job progress stepper and status-advance action bar — `PROV-14` (state, deviates)
- How the user reaches it: Provider app -> Booking detail -> after Accept (or opening a confirmed booking)
- Prototype source: ui_kits/aiwa-app/provider-screens.jsx:199-209,233-245,350-360
- Flutter files: Android/aiwa_app/lib/features/provider_dashboard/presentation/pages/dashboard_page.dart, Android/aiwa_app/lib/features/provider_dashboard/presentation/bloc/dashboard_bloc.dart
- Key elements: 'Job progress' card: home = Accepted / On the way / Arrived / In progress; venue = Accepted / In progress; 4px bars plum700 vs divider; labels 11px (current 700); Bottom bar note: 'Customer gets a push + live tracking starts.' / 'Customer is told you are at the door.' / 'Timer starts. Safety check-in stays on.' / 'Tap once the customer has arrived at your venue.' / 'Finish the job, then confirm the cash you received.'; Cancel (secondary lg, x icon; hidden once in progress) -> ProviderCancelSheet; Primary lg next action: 'On my way' (navigation), "I've arrived" (map-pin), 'Start service' (play); finally 'Mark completed' (check-check) -> payment-confirm
- Findings:
  - **[CRITICAL · interaction] 'Mark completed' completes the booking directly and skips the cash-confirmation / dispute step and the customer rating** `PROV-14-F1`
    - Prototype: provider-screens.jsx:357 `onClick={() => onAct('complete')}` -> prototype.jsx:457 `push('payment-confirm')` -> :451 `push('rate-customer')`.
    - Flutter now: dashboard_page.dart:670-676 `onPressed: () => onComplete(b.id)` -> dashboard_bloc.dart:77-82 `_repository.completeBooking(...)` = PATCH /bookings/{id}/complete with the default cashCollected=true (backend BookingController.java:139-147).
    - Fix: Replace onComplete with `context.push('/provider/bookings/${b.id}/payment')` (PROV-20) and call PATCH /complete?cashCollected=true|false from there.
  - **[CRITICAL · interaction] Provider cannot cancel an accepted booking (the penalty flow is missing)** `PROV-14-F2`
    - Prototype: provider-screens.jsx:354 `{st !== 'progress' && <Btn variant="secondary" ... icon="x" onClick={() => onAct('cancel')}>Cancel</Btn>}` -> prototype.jsx:456 opens ProviderCancelSheet.
    - Flutter now: dashboard_page.dart:636-659: ACCEPTED/ON_THE_WAY/ARRIVED render only the single advance button; no cancel exists anywhere in lib/features/provider_dashboard.
    - Fix: Add a Cancel secondary lg button beside the next action for every non-IN_PROGRESS status, opening the ProviderCancelSheet (PROV-18) and calling PATCH /bookings/{id}/cancel?reason=.
  - **[MAJOR · interaction] Venue (non-home) bookings are wrongly offered 'On my way'** `PROV-14-F3`
    - Prototype: provider-screens.jsx:208 non-home: `{ confirmed: { to: 'progress', label: 'Start service', icon: 'play', note: 'Tap once the customer has arrived at your venue.' } }`.
    - Flutter now: dashboard_page.dart:636-643: ACCEPTED always shows 'On my way'. BookingEntity has no homeService field (booking_entity.dart:3-18), although backend BookingDto has `boolean homeService`.
    - Fix: Map `homeService: json['homeService'] as bool? ?? false`. For ACCEPTED: `b.homeService ? single('On my way', ...) : single('Start service', Icons.play_arrow_rounded, () => onInProgress(b.id))`.
  - **[MAJOR · layout] Actions are inline in list cards instead of a sticky bottom action bar on the detail screen** `PROV-14-F4`
    - Prototype: provider-screens.jsx:351 `position: 'absolute', left: 0, right: 0, bottom: 0, background: '#fff', borderTop: ..., padding: '12px 22px 32px'` with the note above the buttons.
    - Flutter now: dashboard_page.dart:605-614 `single(...)` = sm AiwaButton inside each card, with 12px top padding.
    - Fix: On ProviderBookingDetailPage use `bottomNavigationBar: StickyBar(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(note, style: AppTextStyles.micro.copyWith(fontSize: 12)), SizedBox(height: 8), Row(children: [cancelBtn, SizedBox(width: 10), Expanded(child: nextBtn)])]))`.
  - **[MAJOR · components] 'Job progress' stepper card is missing** `PROV-14-F5`
    - Prototype: provider-screens.jsx:233-245: #fff card radius 18, Eyebrow 'Job progress' 10px, grid of 4px bars (plum700 when done, else divider), labels 11px (700 current / 500 others).
    - Flutter now: No stepper anywhere in dashboard_page.dart; only the StatusPill in each card (dashboard_page.dart:554).
    - Fix: Add a _JobProgress widget: `Row(children: steps.mapIndexed((i, s) => Expanded(child: Column(children: [Container(height: 4, decoration: BoxDecoration(color: i <= idx ? AppColors.plum700 : AppColors.divider, borderRadius: BorderRadius.circular(2))), SizedBox(height: 6), Text(s, style: AppTextStyles.micro.copyWith(fontSize: 11, fontWeight: i == idx ? FontWeight.w700 : FontWeight.w500, color: i <= idx ? AppColors.plum900 : AppColors.ink3))]))).toList())`.
  - **[MAJOR · states] Advance-step failures (e.g. invalid transition) are silently ignored** `PROV-14-F8`
    - Prototype: provider-screens.jsx:356: the step advances immediately via setSt(next.to).
    - Flutter now: dashboard_bloc.dart:90-106 `await _repository.bookingOnTheWay(...)` etc. discard the Either and reload.
    - Fix: Fold the result and show a toast on Left (see PROV-03-F6).

### Quote a travel fee sheet — `PROV-15` (sheet, missing)
- How the user reaches it: Provider app -> Booking detail (pending, home service with address, no fee yet) -> 'Quote a travel fee instead'
- Prototype source: ui_kits/aiwa-app/provider-screens.jsx:210-220,362-393
- Flutter files: none yet
- Key elements: Scrim rgba(42,19,32,.48); bone sheet radius 24, padding 18px 22px 34px, 40x4 handle; 46px gold100 circle with car icon gold700; Eyebrow gold700 'Quote a travel fee'; h2 DM Serif 23: "How much to reach {first name}'s address?"; address 13 ink2; pass-through note 12.5 ink3; Preset buttons EGP 80 / 120 / 180 (selected plum700 bg + #fff text; else #fff with 1.5px divider border; radius 12, 13.5/600); 'EGP' prefix + numeric input JetBrains Mono 18/600 in a 1.5px divider box radius 14 (default '120'); Cancel secondary lg + 'Send quote' primary lg (send icon); rejects values <= 0
- To build: Backend has no per-booking travel-fee quote endpoint, only a flat provider fee (PATCH /provider/mode/travel-fee, aiwa-backend ProviderModeController.java:40-57). Add something like PATCH /bookings/{id}/travel-fee-quote?amount=, plus the customer accept/decline flow. UI: showModalBottomSheet(backgroundColor: Colors.transparent, barrierColor: AppColors.plum900.withOpacity(.48)) with AppTheme.sheetDecoration. Build 3 preset buttons and a TextField(keyboardType: TextInputType.number, style: AppTextStyles.mono.copyWith(fontSize: 18, fontWeight: FontWeight.w600)) with a prefix 'EGP'. On send, set proposedFee state in ProviderBookingDetailBloc.

### Travel-fee state banners (no address / quote sent / fee accepted) — `PROV-16` (banner, missing)
- How the user reaches it: Provider app -> Booking detail (home service)
- Prototype source: ui_kits/aiwa-app/provider-screens.jsx:295-329
- Flutter files: none yet
- Key elements: warn InlineBanner triangle-alert 'No address attached' (home service, no address, pending); gold InlineBanner car 'Travel fee quote sent · EGP {n}' — 'Waiting on the customer to accept or decline...'; success InlineBanner check 'Travel fee accepted' — 'Locked in and added to the total...'; Details card gains a 'Travel fee (pending)' row in gold700 and an updated 'Total · cash'
- To build: InlineBanner already supports BannerTone.warn/gold/success (screen_chrome.dart:260-375). Drive the banners from booking.homeService, savedAddress == null, a proposed quote and booking.travelFee (BookingDto.travelFee exists). Needs the quote endpoint from PROV-15. Margin 14/22/0.

### Propose a different time + toast 'Alternative time sent to customer.' — `PROV-17` (toast, missing)
- How the user reaches it: Provider app -> Booking detail (pending, no quote pending) -> 'Propose a different time instead' -> toast + back
- Prototype source: ui_kits/aiwa-app/provider-screens.jsx:347; ui_kits/aiwa-app/prototype.jsx:458
- Flutter files: none yet
- Key elements: Ghost sm button with calendar-clock icon; Toast (top, dark, green check) 'Alternative time sent to customer.' then pop()
- To build: Backend PATCH /bookings/{id}/propose-time with RescheduleRequest exists (aiwa-backend BookingController.java:168-176); add ApiConstants.bookingProposeTime. The prototype sends immediately with no picker. A real build needs a date/slot choice (reuse GET /bookings/slots via the existing booking feature). Show the shared top toast (PROV-C1) and context.pop().

### ProviderCancelSheet — cancelling after accepting (penalty warning) — `PROV-18` (sheet, missing)
- How the user reaches it: Provider app -> Booking detail (accepted / on the way / arrived) -> Cancel
- Prototype source: ui_kits/aiwa-app/provider-extras.jsx:124-164; ui_kits/aiwa-app/prototype.jsx:486-490
- Flutter files: none yet
- Key elements: Scrim rgba(42,19,32,.45); bone sheet radius 24, padding 18px 22px 36px, shadow 0 -12px 32px rgba(0,0,0,.18); slide-in 320ms; Eyebrow danger700 'Cancelling after accepting'; h2 DM Serif 22 'This applies a penalty'; danger100 note 12.5 danger700 with alert-triangle: 'Cancelling an accepted booking affects your reliability score and adds a small penalty fee to your ledger.'; Reason list: Emergency / unavailable; Staff called in sick; Overbooked by mistake; Customer unreachable; Other (selected = plum100 bg + 1.5px plum700 border + check icon); 'Keep booking' secondary + 'Cancel + accept penalty' danger (no-op until a reason is picked)
- To build: Create shared/widgets/reason_sheet.dart (or reuse the customer CancelSheet if one is built) via showModalBottomSheet returning the reason String. Call PATCH /bookings/{id}/cancel?reason= (ApiConstants.bookingCancel exists at api_constants.dart:48; backend BookingController.java:89-98; BookingDto.penaltyApplied reflects the penalty). On success: toast (PROV-19) + pop to the list.

### Toast 'Booking cancelled. Penalty applied to your ledger.' — `PROV-19` (toast, missing)
- How the user reaches it: Provider app -> Booking detail -> Cancel -> pick reason -> 'Cancel + accept penalty'
- Prototype source: ui_kits/aiwa-app/prototype.jsx:486-490
- Flutter files: none yet
- Key elements: Top toast, then pop() back to the list
- To build: Show via the shared top toast (PROV-C1) after a successful PATCH /cancel, then context.pop().

### PaymentConfirmScreen (provider role) — 'Did {customer} pay in cash?' — `PROV-20` (screen, missing)
- How the user reaches it: Provider app -> Booking detail (in progress) -> Mark completed -> Payment confirm
- Prototype source: ui_kits/aiwa-app/flow-additions-v4.jsx:82-106; ui_kits/aiwa-app/prototype.jsx:448-452
- Flutter files: none yet
- Key elements: Back IconBtn; Eyebrow 'Close out this job'; h1 DM Serif 26 'Did {customer} pay in cash?'; 'Total due · EGP {amount}' 14 ink2 with plum900 strong; Primary full lg check 'Yes, cash received'; secondary full lg alert-triangle 'Mark unpaid or disputed'; Padding 70px 24px 120px
- To build: Route /provider/bookings/:id/payment -> ProviderPaymentConfirmPage with a local outcome state (null | confirmed | dispute). API: PATCH /bookings/{id}/complete?cashCollected=true|false (backend BookingController.java:139-147; Flutter bookingComplete exists but sends no param). Reuse AiwaIconButton, EyebrowLabel, AiwaButton lg full.

### PaymentConfirm — 'Cash received · job closed' state — `PROV-21` (state, missing)
- How the user reaches it: Provider app -> Payment confirm -> 'Yes, cash received'
- Prototype source: ui_kits/aiwa-app/flow-additions-v4.jsx:108-140
- Flutter files: none yet
- Key elements: Paper card radius 20 padding 20; 44px success100 circle with check success700; 'Cash received · job closed' 16/700; 'Receipt sent to {customer}' 12.5 ink3; Rows: Cash collected EGP {amount}; 'AIWA commission (15%) · added to ledger' gold700 EGP {15%}; Booking status 'Completed' success700; Primary full lg star 'Rate {customer}' -> rate-customer; ghost 'Undo — I tapped by mistake' -> back to the question
- To build: Show after a successful PATCH /complete?cashCollected=true. Commission comes from BookingDto.commissionAmount (backend) rather than a hard-coded 15%. The backend has no endpoint to undo a completion, so either defer the API call until 'Rate' is tapped or add a revert endpoint. 'Rate {name}' pushes /provider/bookings/:id/rate-customer.

### PaymentConfirm — dispute form state — `PROV-22` (state, missing)
- How the user reaches it: Provider app -> Payment confirm -> 'Mark unpaid or disputed'
- Prototype source: ui_kits/aiwa-app/flow-additions-v4.jsx:142-160
- Flutter files: none yet
- Key elements: Eyebrow 'What happened?'; textarea placeholder 'Explain the payment issue…' (100px, radius 14, 1.5px divider, paper); Danger full lg 'Submit as disputed' (opacity .45 until text entered); ghost 'Back'
- To build: Call PATCH /bookings/{id}/complete?cashCollected=false (backend marks it DISPUTED). The backend does not accept the explanation text, so add a reason param or file it via POST /complaints (ApiConstants.complaints). Reuse AiwaTextField multiline if supported (not verified) or a TextField with AppTheme.inputBorder.

### Toast 'Marked as disputed. Admin has been notified.' — `PROV-23` (toast, missing)
- How the user reaches it: Provider app -> Payment confirm -> dispute -> 'Submit as disputed' -> Bookings tab
- Prototype source: ui_kits/aiwa-app/prototype.jsx:452
- Flutter files: none yet
- Key elements: Toast then setTab('bookings') + reset('bookings')
- To build: After a successful disputed completion: shared top toast + context.go('/provider/bookings').

### RateCustomerScreen (two-way rating) — `PROV-24` (screen, missing)
- How the user reaches it: Provider app -> Payment confirm -> 'Cash received' -> 'Rate {customer}'
- Prototype source: ui_kits/aiwa-app/provider-extras.jsx:84-122; ui_kits/aiwa-app/prototype.jsx:453
- Flutter files: none yet
- Key elements: Header back IconBtn, Eyebrow 'Two-way rating', h2 'Rate {customer}' DM Serif 22; Paper card radius 18 padding 20px 18px: Avatar plum 64 centered; 5 tappable 36px stars (gold500 fill / ink4 stroke 1.8); Eyebrow 'Quick tags' + chips: On time, Respectful, Clear about needs, Paid in full, Late, Difficult to reach (multi-select); Sticky paper bar: primary full lg 'Submit rating' (opacity .45 until rating > 0)
- To build: Route /provider/bookings/:id/rate-customer. POST /reviews with ReviewRequest {bookingId, rating, comment, quickTags} (backend ReviewController.java:29; ReviewDirection has PROVIDER_TO_CUSTOMER). Verify the backend infers the direction from the caller's role. Reuse the features/reviews bloc/usecase (submit_review_usecase.dart) if its payload matches, plus AiwaChip, StickyBar, AiwaAvatar; build 36px tappable stars (StarRating is display-only, star_rating.dart). On success: toast (PROV-25) + go to Bookings.

### Toast 'Rating submitted. Slot freed — next booking notified.' — `PROV-25` (toast, missing)
- How the user reaches it: Provider app -> Rate customer -> Submit rating -> Bookings tab
- Prototype source: ui_kits/aiwa-app/prototype.jsx:453
- Flutter files: none yet
- Key elements: Toast then setTab('bookings') + reset('bookings')
- To build: Shared top toast + context.go('/provider/bookings').

### Booking detail — travel-fee quote pending (action bar locked) — `PROV-V01` (state, missing)
- How the user reaches it: Provider app -> Booking detail (pending home-service booking with an address) -> 'Quote a travel fee instead' -> Send quote
- Prototype source: ui_kits/aiwa-app/provider-screens.jsx:198,213,215-220,295-307,318-323,340-348
- Flutter files: none yet
- Key elements: After 'Send quote', proposedFee is set and the sheet closes (provider-screens.jsx:215-220); Accept primary lg is dimmed with `opacity: .45, pointerEvents: 'none'` (:344); Decline receives `disabled={proposedFee !== null}` (:343), but Btn (components.jsx:44) ignores `disabled`, so Decline stays fully visible and tappable; 'Quote a travel fee instead' is hidden (canQuote false, :213/:346) and 'Propose a different time instead' is hidden (`!proposedFee`, :347); Details card gains a 'Travel fee (pending)' row in gold700 (male #2E2A26 / female #6B3A3A) and 'Total · cash' = price + quote (:295-307); gold InlineBanner car 'Travel fee quote sent · EGP {n}' (:318-323)
- To build: In ProviderBookingDetailPage (PROV-13), derive quotePending from the booking payload. The backend has no per-booking quote endpoint or field yet (see PROV-15). Render Accept as `AiwaButton(label: 'Accept', icon: Icons.check_rounded, size: AiwaButtonSize.lg, onPressed: quotePending ? null : _accept)`; AiwaButton already renders 0.45 opacity when onPressed is null (aiwa_button.dart AnimatedOpacity). Keep Decline enabled to mirror the prototype literally, or disable both if product prefers. Hide both ghost links while quotePending. Reuse InlineBanner(tone: BannerTone.gold, icon: Icons.directions_car_outlined).

### Booking detail — read-only state for completed / past bookings — `PROV-V02` (state, missing)
- How the user reaches it: Provider app -> Bookings tab -> Past -> tap a completed row
- Prototype source: ui_kits/aiwa-app/provider-screens.jsx:196-203,224-231,233,340,350; ui_kits/aiwa-app/prototype.jsx:438
- Flutter files: none yet
- Key elements: st = 'completed' is not in STEPS, so stepIdx = -1: no 'Job progress' card (:233) and no bottom action bar (neither `st === 'pending'` (:340) nor `stepIdx >= 0` (:350)); The header still reads Eyebrow 'Booking request' / h2 'Review & respond' (DM Serif 22, plum900), with StatusPill 'Completed' (success100/success700); Only the customer card, the address card (home service), the details card (Service / Duration / Requested / Service price / Total · cash) and the cream customer-note card are shown; Back IconBtn pops to Bookings
- To build: ProviderBookingDetailPage must handle terminal statuses (COMPLETED, CANCELLED, REJECTED, NO_SHOW, EXPIRED, disputed) by hiding _JobProgress and the StickyBar while keeping the info cards. StatusPill (status_pill.dart) already maps completed/cancelled/rejected/no_show/expired/disputed. Load via GET /bookings/{id} (ApiConstants.bookingById).

### Provider notifications inbox (PROVIDER_NOTIFICATIONS) — `PROV-48` (sub-screen, deviates)
- How the user reaches it: Provider app -> Profile tab -> Notifications
- Prototype source: ui_kits/aiwa-app/customer-extras.jsx:110-172,501-508; ui_kits/aiwa-app/prototype.jsx:441,447
- Flutter files: Android/aiwa_app/lib/features/notifications/presentation/pages/notifications_page.dart, Android/aiwa_app/lib/core/router/app_router.dart
- Key elements: Header back IconBtn, Eyebrow 'Inbox', 'Notifications' DM Serif 24 + '· {n} new' 13/600 rose500, 'Mark all read' 13/600 plum700; Groups 'Today' / 'Earlier'; Rows padding 14px 22px, unread plum100 bg, divider; 38px paper icon tile radius 12; title 14 (700 unread / 600); time 11 ink3; body 12.5 ink2 lh 1.45; 8px rose500 unread dot; Seed: Settlement overdue (banknote), Gallery image hidden (image-off), Payment disputed (alert-triangle), New booking request (calendar-check), New review (star), Verification approved (badge-check); Tap marks read; onOpen is a no-op for providers
- Findings:
  - **[CRITICAL · interaction] Provider notifications inbox is unreachable from the provider app** `PROV-48-F1`
    - Prototype: provider-screens.jsx:489 `{ icon: 'bell', label: 'Notifications', onTap: onNotifications }` -> prototype.jsx:441 `push('provider-notifications')` -> :447 `<NotificationsScreen items={window.PROVIDER_NOTIFICATIONS} ...>`.
    - Flutter now: app_router.dart:207-210 registers /notifications, but DashboardPage (the only provider screen) has no bell or profile row that pushes it.
    - Fix: Add a 'Notifications' SettingsRow on ProviderProfilePage (PROV-29): `onTap: () => context.push(AppRoutes.notifications)`. Optionally add a bell AiwaIconButton with an unread dot in the Today hero.
