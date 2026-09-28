# Live booking: tracking, safety/SOS, chat, payment, proposed time, rejected, expired, complaint, review, bookings list

Generated from the AIWA prototype-fidelity audit. Paths: prototype = `C:/Users/alyar/Desktop/AIWA Design System (2)/design_handoff_aiwa_app/`, Flutter = `Android/aiwa_app/`.

## Targeted findings

- **[MAJOR · components] Toasts implemented with Material SnackBar instead of the kit Toast** `BOOK-C1`
  - Prototype: Single <Toast> at top: 56 with a success check badge, 2800ms (prototype.jsx:20-39)
  - Flutter now: snackBarTheme floating SnackBar (app_theme.dart:185-193); ScaffoldMessenger.showSnackBar called directly in my_bookings_page.dart:127, review_page.dart:91-97, booking_page.dart:115
  - Fix: Add shared/widgets/aiwa_toast.dart (OverlayEntry-based showAiwaToast). Replace every showSnackBar call so all toasts share one component.

- **[MINOR · components] Material Icons used instead of the Lucide set** `BOOK-C2`
  - Prototype: All icons are Lucide names via <Icon name=...> (components.jsx:21-41), e.g. banknote, calendar-plus, x-circle
  - Flutter now: Icons.* throughout (e.g. Icons.payments_outlined booking_page.dart:291, Icons.calendar_month_outlined my_bookings_page.dart:187); pubspec.yaml has no Lucide package
  - Fix: Add lucide_icons_flutter and map kit names 1:1 (LucideIcons.banknote, LucideIcons.calendarPlus, ...).

- **[MINOR · tokens] Sheet scrim and shadow derived from theme colours instead of the kit literals** `BOOK-C3`
  - Prototype: Scrim rgba(42,19,32,.45-.48); shadow rgba(0,0,0,.18) / rgba(42,19,32,.2) (flow-screens.jsx:505-512; states.jsx:234-240)
  - Flutter now: AppColors.plum900.withOpacity(0.48) (confirm_sheet.dart:27); AppTheme.sheetDecoration plum700 @0.14 (app_theme.dart:41-51)
  - Fix: Add AppColors.scrim = Color(0x7A2A1320) and AppTheme.sheetShadow = BoxShadow(color: Color(0x332A1320), blurRadius: 32, offset: Offset(0, -12)). Use them in every bottom sheet.

- **[MINOR · tokens] Serif heading styles bake in tracking that screens then inherit** `BOOK-C4`
  - Prototype: letterSpacing is set per heading only where needed (e.g. BookingType h1 -0.02em at flow-screens.jsx:168; Confirmed h1 none at screens.jsx:477)
  - Flutter now: AppTextStyles.h1/h2/h3 always carry -0.02em / -0.01em (app_text_styles.dart:16-35) and are reused with copyWith(fontSize: ...), so tracking is computed from the base size
  - Fix: Compute letterSpacing from the final size, e.g. static TextStyle serif(double size, {double tracking = 0}) => _serif(fontSize: size, letterSpacing: tracking * size, ...).

- **[MINOR · components] No shared reason-picker sheet; the generic ConfirmSheet is used instead** `BOOK-C5`
  - Prototype: CancelSheet and FlagProviderSheet share one pattern: handle, eyebrow, h2, selectable reason rows, 'other' textarea, secondary + danger buttons (flow-screens.jsx:490-549; customer-extras.jsx:432-491)
  - Flutter now: Only showConfirmSheet exists (confirm_sheet.dart:12-138); cancel uses it without reasons (my_bookings_page.dart:95-106)
  - Fix: Create shared/widgets/reason_sheet.dart (showReasonSheet(context, eyebrow, title, reasons, otherLabel, confirmLabel)). Reuse it for Cancel, Flag provider and the Complaint categories.


## Entries

### Tracking - Pending — `BOOK-15` (state, missing)
- How the user reaches it: Booking confirmed (scheduled) -> 'View my bookings' -> Tracking; or Bookings -> Upcoming -> tap b2 'Gel Manicure' (pending) / 'Track'
- Prototype source: ui_kits/aiwa-app/flow-screens.jsx:226-233, 235-485 (pending branches 250-256, 262, 442-469, 479); prototype.jsx:692, 694
- Flutter files: none yet
- Key elements: Gradient header linear-gradient(160deg, plum700, plum900), glass back IconBtn, Eyebrow rose300 'Tracking', title 'Pending' DM Serif 22; Live status card (rgba(255,255,255,.10), blur, radius 18): 54px bone circle, hourglass icon, 'Pending', hint 'Waiting for the provider to confirm.' rose300; Radio line 'Waiting for the provider to accept'; Dashed prototype-only 'simulate provider's next tap'; Provider card (BOOK-21); 6-step timeline (28px dots, 2px connectors, active plum700/bone, done plum100/check); 'Demo: provider quotes a travel fee' (BOOK-27); Footer: 'Cancel booking' secondary icon x -> CancelSheet; 'Demo: provider proposes new time' ghost calendar-clock -> Proposed time; 'Report a problem' ghost flag -> Complaint
- To build: Create features/bookings/presentation/pages/tracking_page.dart with route '/booking/:id/track' in app_router.dart. Load the booking with the existing BookingRemoteDataSource.getBookingDetail (GET /bookings/{id}) through a new TrackingCubit. Refresh by polling or push; pubspec.yaml has no firebase_messaging or web socket package. Map backend PENDING/ACCEPTED/ON_THE_WAY/ARRIVED/IN_PROGRESS/COMPLETED to STATUS_STEPS {icon, label, hint} and WAITING_ON copy. Header: Container with a LinearGradient(plum700 -> plum900) plus AiwaGlow, AiwaIconButton(variant: glass). Build the timeline as a Column of Rows with a 28px circle and a 2px connector. Reuse AiwaAvatar, AiwaButton, EyebrowLabel, StatusPill. Wire: my_bookings card tap and 'Track' (BOOK-41), Confirmed CTA (BOOK-14), notifications_page onTap. Omit the prototype-only dashed demo buttons in production.

### Tracking - Accepted (confirmed) — `BOOK-16` (state, missing)
- How the user reaches it: Bookings -> Upcoming -> b1 'Haircut & Style' (confirmed, home) -> Tracking; also after Book Now booking or Proposed time 'Accept new time'
- Prototype source: ui_kits/aiwa-app/flow-screens.jsx:228, 252, 262, 378-389; prototype.jsx:513, 634, 700-704
- Flutter files: none yet
- Key elements: Title/card 'Accepted', check-circle icon, hint 'Your booking is confirmed.'; Waiting line 'Updates when the provider heads out'; Timeline step 2 active, step 1 done (check); 'Cancel booking' still available (canCancel = pending|confirmed); Venue check-in card when location is 'venue' (BOOK-26); Report a problem
- To build: A state of TrackingPage (BOOK-15). Show 'Cancel booking' when BookingEntity.canCancel (PENDING/ACCEPTED, already defined at booking_entity.dart:40-41). The backend topology comment says venue bookings go ACCEPTED -> IN_PROGRESS; the prototype always shows 6 steps.

### Tracking - On the way — `BOOK-17` (state, missing)
- How the user reaches it: Notifications -> 'Nadia is on the way' (opens Tracking with status onway); or Tracking -> provider taps on-the-way
- Prototype source: ui_kits/aiwa-app/flow-screens.jsx:229, 253, 339-356; prototype.jsx:713
- Flutter files: none yet
- Key elements: 'On the way', navigation icon, hint 'Provider is heading to your address.'; Waiting line 'Updates when the provider arrives'; Home-service safety card with SOS (BOOK-22); Cancel hidden; Report a problem visible
- To build: A state of TrackingPage (BOOK-15). Needs BookingEntity.homeService (BookingDto.homeService) to decide whether to show the safety card. notifications_page.dart onTap (lines 134-140) should push the tracking route for booking notifications.

### Tracking - Arrived — `BOOK-18` (state, missing)
- How the user reaches it: Tracking (on the way) -> provider marks arrived
- Prototype source: ui_kits/aiwa-app/flow-screens.jsx:230, 254, 339
- Flutter files: none yet
- Key elements: 'Arrived', map-pin icon, hint 'Provider has arrived at your door.'; Waiting line 'Updates when the provider starts the service'; Safety card + SOS still shown for home service
- To build: A state of TrackingPage (BOOK-15). Backend status ARRIVED.

### Tracking - In progress — `BOOK-19` (state, missing)
- How the user reaches it: Tracking (arrived) -> provider starts service
- Prototype source: ui_kits/aiwa-app/flow-screens.jsx:231, 255, 305
- Flutter files: none yet
- Key elements: 'In progress', sparkles icon in a 54px circle pulsing (aiwa-pulse 1.6s); Hint 'Service is underway.'; Waiting line 'Updates when the provider marks it complete'; Safety card + SOS for home service
- To build: A state of TrackingPage (BOOK-15). Pulse: AnimationController(duration: 1600ms)..repeat(reverse: true) driving ScaleTransition 1.0->1.05.

### Tracking - Completed (confirm cash payment + review) — `BOOK-20` (state, missing)
- How the user reaches it: Tracking (in progress) -> provider marks complete
- Prototype source: ui_kits/aiwa-app/flow-screens.jsx:232, 263, 317, 427-439, 480; prototype.jsx:694
- Flutter files: none yet
- Key elements: 'Completed', badge-check icon, hint 'Service done. Pay cash and rate.'; 'Updates automatically'; demo button hidden; Payment row: plum100 bg, radius 14, 36px paper tile banknote plum700, 'Confirm your cash payment' 14 w600 plum900, 'EGP 350 due to {p.name}' 12 ink3, Btn secondary sm 'Confirm' -> Payment confirm; 'Leave a review' primary icon star -> Review; 'Report a problem' ghost flag
- To build: A state of TrackingPage (BOOK-15). 'Confirm' pushes '/booking/:id/payment' (BOOK-38). 'Leave a review' pushes '/review/:id' with extra: booking (the route exists in app_router.dart:211-222). Hide the payment row when BookingDto.paymentStatus is already confirmed, and hide review when BookingDto.reviewed is true.

### Tracking - provider contact card (call + chat entry) — `BOOK-21` (component, missing)
- How the user reaches it: Any Tracking state
- Prototype source: ui_kits/aiwa-app/flow-screens.jsx:329-337; prototype.jsx:694 (onChat -> push('chat'))
- Flutter files: none yet
- Key elements: Card overlaps header: margin '-20px 22px 0', paper, radius 18, padding 14; Avatar 48 (palette, verified); Name DM Serif 17 plum900; '{service} · {when}' 12 ink3; phone IconBtn 36 (no handler in prototype); message-circle IconBtn 36 -> ChatScreen
- To build: Part of TrackingPage. Use Transform.translate(offset: Offset(0, -20)) or a Stack over the header. AiwaIconButton(size: 36, icon: Icons.phone_outlined) could launch a masked-number tel: link (backend masking not visible). AiwaIconButton(Icons.chat_bubble_outline) pushes '/booking/:id/chat' (BOOK-36).

### Tracking - home-service safety card (live location + ID, SOS button) — `BOOK-22` (component, missing)
- How the user reaches it: Tracking in On the way / Arrived / In progress for a home (non-venue) booking
- Prototype source: ui_kits/aiwa-app/flow-screens.jsx:339-356
- Flutter files: none yet
- Key elements: Paper card radius 16 padding 14; 34px success100 tile, shield-check success700; 'Live location + ID shared' 13.5 w600 ink; 'Identity confirmed both ways. A trusted contact can follow along too.' 11.5 ink3; Full-width SOS button: danger100 bg, danger700 13.5 w700, radius 12, siren icon, 'SOS - alert a trusted contact & AIWA'
- To build: Part of TrackingPage. Show it when booking.homeService and the status is ON_THE_WAY/ARRIVED/IN_PROGRESS. SOS calls the backend SafetyController POST /bookings/{bookingId}/safety (SafetyController.java:21, 39) and moves through SOS stages 1-3 (BOOK-23..25) in a SafetyCubit. Trusted contacts come from the account partition.

### Tracking - SOS stage 1: alerting — `BOOK-23` (banner, missing)
- How the user reaches it: Tracking (home service, on the way/arrived/in progress) -> SOS button
- Prototype source: ui_kits/aiwa-app/flow-screens.jsx:357-363
- Flutter files: none yet
- Key elements: danger100 bg, 1px danger500 @40% border, radius 14; loader icon danger700 18; 'Alerting your trusted contact and AIWA support...' 12.5 danger700; 'Simulate sent' pill (prototype-only)
- To build: SafetyCubit state 'alerting' while POST /bookings/{id}/safety is in flight. The design rule is no spinners, so pulse the loader icon.

### Tracking - SOS stage 2: support notified — `BOOK-24` (banner, missing)
- How the user reaches it: SOS alerting -> request succeeds
- Prototype source: ui_kits/aiwa-app/flow-screens.jsx:364-370
- Flutter files: none yet
- Key elements: warn100 bg, warn500 @40% border, shield-alert warn700; '**Support has been notified.** A trusted contact was alerted with your live location. Stay safe - a specialist may call shortly.'; 'I'm safe' text button warn700 11.5 w700 -> stage 3
- To build: SafetyCubit 'notified' state. 'I'm safe' resolves the incident (endpoint not visible; SafetyController exposes GET/POST only).

### Tracking - SOS stage 3: incident logged — `BOOK-25` (banner, missing)
- How the user reaches it: SOS notified -> 'I'm safe'
- Prototype source: ui_kits/aiwa-app/flow-screens.jsx:371-376
- Flutter files: none yet
- Key elements: plum100 bg, divider border, radius 14; file-check icon plum700; 'Incident logged for admin review. Our trust & safety team will follow up within 24h.' 12.5 plum700
- To build: SafetyCubit 'logged' state rendered with InlineBanner(tone: plum, icon: Icons.fact_check_outlined).

### Tracking - venue check-in card — `BOOK-26` (component, missing)
- How the user reaches it: Tracking for a venue booking (e.g. b2 Gel Manicure) in Accepted / On the way / Arrived
- Prototype source: ui_kits/aiwa-app/flow-screens.jsx:378-389
- Flutter files: none yet
- Key elements: Paper card radius 16; 34px plum100 tile, map-pin-check plum700; 'On-site service - check in when you arrive' 13.5 w600; 'Tap in at the venue to let {p.name} know you're there.' 11.5 ink3; Btn secondary sm 'Check in' (no handler in prototype)
- To build: Show it when !booking.homeService and the status is in ACCEPTED/ON_THE_WAY/ARRIVED. 'Check in' calls PATCH /bookings/{id}/check-in (BookingController.java:189); add ApiConstants.bookingCheckIn. After success, show 'Checked in' from BookingDto.checkedInAt.

### Tracking - travel fee quote (accept / decline) + total row — `BOOK-27` (state, missing)
- How the user reaches it: Tracking (pending) -> provider quotes a travel fee (prototype demo button)
- Prototype source: ui_kits/aiwa-app/flow-screens.jsx:442-475
- Flutter files: none yet
- Key elements: Card: paper, 1.5px gold500 border, radius 18, padding 16; 40px gold100 tile, car icon gold700; '{p.name} wants EGP 120 for travel' 14.5 w700; 'Total will be EGP 350 + EGP 120 = EGP 470.'; 'Decline' secondary sm / 'Accept & confirm' primary sm check -> status confirmed; Total row: cream, 'Service EGP 350 + travel EGP 120' ink3 / 'Total EGP 470' w700 plum900
- To build: Needs BookingEntity.travelFee (BookingDto.travelFee exists). The customer accept/decline endpoint is not visible in aiwa-backend: only provider-side PATCH /travel-fee in ProviderModeController.java:40. Render it when status PENDING and travelFee != null with no customer decision yet.

### Tracking - travel fee declined ('No problem - no fee applied.') — `BOOK-28` (state, missing)
- How the user reaches it: Tracking (pending) -> travel fee card -> Decline
- Prototype source: ui_kits/aiwa-app/flow-screens.jsx:265-281
- Flutter files: none yet
- Key elements: Centred layout, 68px cream circle, calendar-x ink3; Eyebrow 'Booking cancelled'; h1 26 'No problem - no fee applied.'; 'You declined the EGP 120 travel fee, so this request was cancelled cleanly. Neither of you is penalized.'; 'Find another provider' primary lg icon search -> back to Bookings
- To build: A full-screen state inside TrackingPage after the decline API succeeds. Reuse a SystemScreen-style layout (Spacer / icon / eyebrow / title / body / Spacer / button). The prototype's onBack returns to the Bookings tab.

### Cancel booking sheet (with reasons) — `BOOK-29` (sheet, deviates)
- How the user reaches it: Tracking (Pending/Accepted) -> 'Cancel booking'
- Prototype source: ui_kits/aiwa-app/flow-screens.jsx:490-549; prototype.jsx:694, 737-741
- Flutter files: Android/aiwa_app/lib/features/bookings/presentation/pages/my_bookings_page.dart, Android/aiwa_app/lib/shared/widgets/confirm_sheet.dart, Android/aiwa_app/lib/features/bookings/data/datasources/booking_remote_datasource.dart, Android/aiwa_app/lib/features/bookings/presentation/bloc/booking_event.dart
- Key elements: Scrim rgba(42,19,32,.45) + blur(2px); bone sheet radius 24, padding '18px 22px 36px', shadow '0 -12px 32px rgba(0,0,0,.18)'; Eyebrow 'Cancel your booking'; h2 22 'Why are you cancelling?'; 6 reason rows: 'Changed my mind', 'Found another provider', 'Wrong service / time', 'Price is too high', 'Provider not responsive', 'Something else' (selected plum100 bg, 1.5 plum700 border, check); 'Something else' -> textarea 'Tell us what happened (optional)' h70; 'Keep booking' secondary / 'Cancel' danger (md); confirm requires a reason; On confirm: toast 'Booking cancelled. Reason: {reason}' -> Bookings tab
- Findings:
  - **[CRITICAL · components] Cancellation reasons not collected** `BOOK-29-F1`
    - Prototype: const REASONS = ["Changed my mind", "Found another provider", "Wrong service / time", "Price is too high", "Provider not responsive", "Something else"] rendered as selectable rows; onClick={() => reason && onConfirm({ reason, note })} (flow-screens.jsx:493-531, 542)
    - Flutter now: showConfirmSheet(context, eyebrow: 'Cancel booking', title: 'Cancel ${b.serviceName}?', ...) with no reason UI; then _bloc.add(BookingCancelEvent(b.id)) (my_bookings_page.dart:95-106). BookingCancelEvent has only bookingId (booking_event.dart:38-43)
    - Fix: Create shared/widgets/reason_sheet.dart returning `({String reason, String? note})?`. Use AnimatedContainer rows: padding 13/14, radius 12, selected AppColors.plum100 bg with a 1.5 plum700 border and Icons.check. Add `final String reason;` to BookingCancelEvent.
  - **[MAJOR · interaction] Reason not sent to the cancel endpoint** `BOOK-29-F2`
    - Prototype: onConfirm({ reason, note }) -> setToast('Booking cancelled. Reason: ' + reason) (prototype.jsx:737-741)
    - Flutter now: await _api.patch(ApiConstants.bookingCancel(bookingId)) with no reason (booking_remote_datasource.dart:84-86), although the backend accepts @RequestParam(required = false) String reason (BookingController.java:89-93)
    - Fix: _api.patch(ApiConstants.bookingCancel(id), queryParameters: {'reason': reason})
  - **[MAJOR · interaction] Cancel is opened from the list card instead of Tracking** `BOOK-29-F3`
    - Prototype: Tracking footer: {canCancel && <Btn variant="secondary" full onClick={onCancel} icon="x">Cancel booking</Btn>} (flow-screens.jsx:478); Upcoming cards show only Track/Directions (screens.jsx:574-579)
    - Flutter now: AiwaButton(label: 'Cancel', variant: secondary, size: sm, onPressed: onCancel) on each cancellable card (my_bookings_page.dart:414-423)
    - Fix: Move cancel to TrackingPage (BOOK-15). On the card, replace 'Cancel' with 'Track' (BOOK-41-F2).
  - **[MAJOR · content] Copy differs from prototype** `BOOK-29-F4`
    - Prototype: Eyebrow 'Cancel your booking'; h2 'Why are you cancelling?'; buttons 'Keep booking' / 'Cancel'; no body (flow-screens.jsx:516-517, 541-544)
    - Flutter now: eyebrow 'Cancel booking', title 'Cancel ${b.serviceName}?', body '${b.displayProviderName} will be notified right away. This can't be undone.', confirmLabel 'Cancel booking', cancelLabel 'Keep it' (my_bookings_page.dart:96-104)
    - Fix: Use the prototype strings in the new reason sheet.
  - **[MAJOR · states] 'Something else' note field and reason gating missing** `BOOK-29-F5`
    - Prototype: {reason === 'Something else' && <textarea placeholder="Tell us what happened (optional)" height: 70 .../>}; 'Cancel' no-ops without a reason (flow-screens.jsx:533-539, 542)
    - Flutter now: Confirm is always enabled; the input param of showConfirmSheet is unused here (confirm_sheet.dart:87-104)
    - Fix: In the reason sheet, show a TextField(maxLines: 3) when 'Something else' is selected. Disable the danger button until reason != null.

### Proposed time - provider suggested a different time (active countdown) — `BOOK-30` (screen, missing)
- How the user reaches it: Tracking (pending) -> 'Demo: provider proposes new time' (in production: push/notification when the provider proposes)
- Prototype source: ui_kits/aiwa-app/flow-additions-v3.jsx:9-68; prototype.jsx:633-635
- Flutter files: none yet
- Key elements: Back IconBtn; Eyebrow rose700 'New time proposed'; h1 28 '{providerName} suggested a different time.'; Body 'Your original slot wasn't available. Here's what they can offer instead.'; Card: 1.5px plum700 border, radius 18; calendar-clock tile; 'Thu, May 21 · 4:00 PM' DM Serif 20; 'Instead of Tue, May 19 · 12:30 PM'; Countdown 'Respond within MM:SS or this offer expires automatically.' (JetBrains Mono 700; danger700 under 2 min), 30:00 start; 'Accept new time' primary lg check -> toast + Tracking (Accepted); 'Decline & see alternatives' secondary lg -> Rejected screen
- To build: Route '/booking/:id/proposed-time'. Needs BookingEntity.proposedDate/proposedStartTime (BookingDto.proposedDate/proposedStartTime) and PATCH /bookings/{id}/proposal-response?accept=true|false (BookingController.java:178-187); add ApiConstants.bookingProposalResponse. Drive the countdown with Stream.periodic(1s) in a Cubit; text style AppTextStyles.mono w700. Accept shows the BOOK-58 toast and goes to tracking. Decline goes to the rejected route.

### Proposed time - offer expired — `BOOK-31` (state, missing)
- How the user reaches it: Proposed time -> countdown reaches 00:00
- Prototype source: ui_kits/aiwa-app/flow-additions-v3.jsx:41-45, 54-58
- Flutter files: none yet
- Key elements: InlineBanner warn hourglass 'This offer expired' / 'You didn't respond in time, so the request was released automatically. Ask for another time or see who else is free.'; 'See alternative providers' primary lg search -> Rejected; 'Back to bookings' secondary lg -> pop
- To build: Expired state of BOOK-30. Use InlineBanner(tone: BannerTone.warn, icon: Icons.hourglass_bottom) from screen_chrome.dart.

### Booking rejected - reason + alternatives — `BOOK-32` (screen, missing)
- How the user reaches it: Bookings -> Past -> rejected card 'See alternatives'; or Proposed time -> Decline
- Prototype source: ui_kits/aiwa-app/customer-extras.jsx:343-427; prototype.jsx:635, 702, 716
- Flutter files: none yet
- Key elements: Header back, Eyebrow rose700 'Booking rejected', h2 22 '{name} couldn't take this one.'; Reason card: danger100, 32px paper tile x icon danger700, 'Reason from {first}', quoted reason 13 ink2; 'Book {first} at another time' card: calendar-clock tile, 'Next open slots for the same service', 3 slot buttons (Today 4:30 PM / Today 6:00 PM / Tomorrow 11:00 AM), 'See all times' primary icon calendar -> provider; SectionHeader 'Similar providers' / 'Other providers nearby' + provider rows (Avatar 48, rating, distance, 'Open now', 'Book' secondary sm) -> provider profile; Back -> Bookings tab
- To build: Route '/booking/:id/rejected'. Needs BookingEntity.rejectionReason (BookingDto.rejectionReason). Alternatives: BookingWithAlternativesDto is only returned to the rejecting provider (PATCH /reject), so add a customer endpoint or query /providers/search with the original category. Reuse ProviderListItem (features/home/presentation/widgets/provider_list_item.dart), SectionHeader, AiwaButton, AiwaAvatar.

### Expired booking ('No answer in time.') — `BOOK-33` (screen, missing)
- How the user reaches it: Bookings -> Past -> b8 'Russian Volume Lashes' (expired) card tap; or Preview states 'Booking expired'
- Prototype source: ui_kits/aiwa-app/system-screens.jsx:189-215; prototype.jsx:681, 703, 790
- Flutter files: none yet
- Key elements: Back IconBtn; 68px warn100 circle, hourglass warn700; Eyebrow warn700 'Request expired'; h1 27 'No answer in time.'; '{providerName} didn't respond within the booking window, so your request was released. You haven't been charged anything.'; InlineBanner plum sparkles 'Three providers nearby are free at the same time' / 'Same category, similar rating, all within your radius.'; 'See alternative providers' primary lg search -> Discover; 'Back to bookings' ghost sm
- To build: Route '/booking/:id/expired'. The backend has BookingStatus.EXPIRED; include it in the Past list (BOOK-46) and make the card tappable. Reuse InlineBanner(tone: plum), AiwaButton, EyebrowLabel. Note: the prototype uses the current providerId, not the booking's provider, for the name (prototype.jsx:681). Use the booking's provider.

### Leave a review ('How was it?') — `BOOK-34` (screen, deviates)
- How the user reaches it: Tracking (completed) -> 'Leave a review' (Flutter: Bookings -> Past -> completed card -> 'Leave a review')
- Prototype source: ui_kits/aiwa-app/customer-extras.jsx:15-95; prototype.jsx:694, 712
- Flutter files: Android/aiwa_app/lib/features/reviews/presentation/pages/review_page.dart, Android/aiwa_app/lib/features/reviews/presentation/bloc/review_bloc.dart, Android/aiwa_app/lib/shared/widgets/aiwa_text_field.dart
- Key elements: Header: Eyebrow 'Leave a review', h2 'How was it?'; Provider card: Avatar 64 (palette, verified), name DM Serif 20, 'Haircut & Style · Sun, May 17' 12 ink3; 5 star buttons 38px (gap 10 + padding 4), gold500 fill / ink4 stroke, scale .94 unselected; Adjective 'Tap a star' / Disappointing / Below expectations / Good / Great / Outstanding (DM Serif 18); Eyebrow 'Quick tags (optional)' + 6 chips; Eyebrow 'Tell others what stood out' + textarea h100 placeholder 'Optional - your review will be public on the provider's profile.'; Sticky 'Submit review' primary lg, .45 until rated -> toast + Bookings tab
- Findings:
  - **[MAJOR · interaction] Review only reachable from the bookings list** `BOOK-34-F1`
    - Prototype: Tracking completed: {isDone && <Btn variant="primary" full onClick={onReview} icon="star">Leave a review</Btn>} -> push('review') (flow-screens.jsx:480; prototype.jsx:694)
    - Flutter now: Only onReview: () => context.push('/review/${b.id}', extra: b) from a completed card (my_bookings_page.dart:222)
    - Fix: Add the Tracking 'Leave a review' entry once TrackingPage exists (BOOK-20).

### Complaint ('Open a complaint / What happened?') — `BOOK-35` (screen, missing)
- How the user reaches it: Tracking (any status) -> 'Report a problem'
- Prototype source: ui_kits/aiwa-app/customer-extras.jsx:177-258; prototype.jsx:694, 714
- Flutter files: none yet
- Key elements: Header Eyebrow 'Open a complaint', h2 'What happened?'; About card: Avatar 36, 'About {name}', 'Booking #{id}', Eyebrow rose700 'Private'; Eyebrow 'Pick a category' + 6 rows with icon tiles and hints: Provider behavior (user-x), Service quality (thumbs-down), Pricing or billing (banknote), Safety concern (shield-alert), Provider didn't show (user-x), Something else (more-horizontal); Selected: plum100 bg, 1.5 plum700 border, plum700 tile with bone icon, check; Eyebrow 'Tell us more' + textarea h120 'Walk us through what happened. The more detail, the faster we can help.'; Cream privacy note with lock: 'Your name and contact info stay private. Only the AIWA support team will see this case.'; Sticky 'Submit complaint' .45 until category -> toast + pop
- To build: Create features/complaints (datasource, cubit, page) with route '/booking/:id/complaint'. ApiConstants.complaints ('/complaints') already exists (api_constants.dart:70) but has no datasource. POST /complaints on the backend. Reuse ScreenHeader, AiwaAvatar, EyebrowLabel, StickyBar, AiwaButton, and the row style from the reason sheet (BOOK-29 fix). Show the BOOK-57 toast on success.

### Chat with provider (masked number) — `BOOK-36` (screen, missing)
- How the user reaches it: Tracking -> provider card message-circle button
- Prototype source: ui_kits/aiwa-app/customer-extras-2.jsx:100-177; prototype.jsx:673, 694
- Flutter files: none yet
- Key elements: cream bg; paper header with back, Avatar 36 verified, name 15 w600, 'Masked number · online' 11.5 success700 w600, phone IconBtn 36; InlineBanner plum eye: 'Admin can view this chat only if you submit a complaint or dispute a payment.'; Bubbles max 78%: me plum700/bone radius 16 (4 bottom-right); them paper/ink divider border (4 bottom-left); timestamp 10 @65%; 'Report' flag link under provider messages; Composer: pill input cream 1.5 divider 'Message...' + send IconBtn plum
- To build: Create features/chat with route '/booking/:id/chat'. Backend has GET/POST /bookings/{bookingId}/chat and POST /bookings/{bookingId}/chat/{messageId}/report (ChatController.java:37-75). ChatCubit polls, since there is no realtime package. Reuse AiwaAvatar, AiwaIconButton(variant: plum, icon: Icons.send_rounded), InlineBanner(tone: plum, icon: Icons.visibility_outlined).

### Chat - report message sheet + '[message removed by admin]' state — `BOOK-37` (sheet, missing)
- How the user reaches it: Chat -> 'Report' under a provider message
- Prototype source: ui_kits/aiwa-app/customer-extras-2.jsx:116-119, 137-141, 156-160, 172-174
- Flutter files: none yet
- Key elements: ConfirmSheet: eyebrow 'Report message', title 'Send this to admin review?', confirm 'Report message', icon flag, body 'Support reviews reported messages and can remove them. This doesn't notify the other person.'; Blocked bubble: cream bg, 1px dashed divider, ink4 12.5 italic, eye-off icon, '[message removed by admin]'
- To build: Reuse showConfirmSheet(context, eyebrow: 'Report message', title: 'Send this to admin review?', confirmLabel: 'Report message', icon: Icons.flag_outlined, body: ...). POST .../chat/{messageId}/report. Render the blocked style when the message DTO flags removal (field not verified).

### Payment confirm (customer) - 'Did you pay {provider} in cash?' — `BOOK-38` (screen, missing)
- How the user reaches it: Tracking (completed) -> 'Confirm your cash payment' row -> 'Confirm'
- Prototype source: ui_kits/aiwa-app/flow-additions-v4.jsx:82-106; prototype.jsx:694-697
- Flutter files: none yet
- Key elements: Back IconBtn; Eyebrow 'Confirm payment'; h1 26 'Did you pay {providerName} in cash?'; 'Total due · **EGP 350**' (plum900 bold); 'Yes, I paid - confirm' primary lg check; 'No / something's wrong' secondary lg alert-triangle
- To build: Route '/booking/:id/payment'. PATCH /bookings/{id}/confirm-payment?paid=true|false (BookingController.java:198-206); add ApiConstants.bookingConfirmPayment. A PaymentConfirmCubit handles the idle / confirmed / dispute-form states (BOOK-39, BOOK-40). The amount comes from BookingDto.totalPrice, which includes travelFee.

### Payment confirm - paid / confirmed state — `BOOK-39` (state, missing)
- How the user reaches it: Payment confirm -> 'Yes, I paid - confirm'
- Prototype source: ui_kits/aiwa-app/flow-additions-v4.jsx:108-140; prototype.jsx:696
- Flutter files: none yet
- Key elements: Card paper radius 20 padding 20; 44px success100 circle check success700; 'Payment confirmed' 16 w700; 'Receipt sent to your email' 12.5 ink3; Rows: 'Cash collected' EGP 350; 'Booking status' 'Completed' success700; 'Rate your provider' primary lg star (onConfirmed: toast 'Payment confirmed. Receipt sent.' + pop; does not open Review); 'Undo - I tapped by mistake' ghost -> back to question
- To build: Part of BOOK-38. 'Rate your provider' in the prototype only toasts and pops. In Flutter, show the BOOK-59 toast and push '/review/:id' to match the label intent (flag this to design). The prototype's Undo is local-only; decide whether to delay the API call until the user leaves the screen.

### Payment confirm - unpaid / dispute form — `BOOK-40` (state, missing)
- How the user reaches it: Payment confirm -> 'No / something's wrong'
- Prototype source: ui_kits/aiwa-app/flow-additions-v4.jsx:142-160; prototype.jsx:697
- Flutter files: none yet
- Key elements: Eyebrow 'What happened?'; textarea h100 'Explain the payment issue...'; 'Submit as unpaid' danger lg, .45 until text entered; 'Back' ghost -> question; On submit: toast 'Reported as unpaid. AIWA support has been notified.' + pop
- To build: Part of BOOK-38. Call PATCH confirm-payment?paid=false. The endpoint takes no reason text, so the reason needs a complaint/dispute POST or a backend field. Show the BOOK-60 toast.

### My Bookings - Upcoming tab — `BOOK-41` (tab, deviates)
- How the user reaches it: Tab bar -> Bookings (Upcoming is default)
- Prototype source: ui_kits/aiwa-app/screens.jsx:499-597 (upcoming 501-503, 532-579); prototype.jsx:698-705
- Flutter files: Android/aiwa_app/lib/features/bookings/presentation/pages/my_bookings_page.dart, Android/aiwa_app/lib/features/bookings/presentation/bloc/booking_bloc.dart
- Key elements: Eyebrow 'Your appointments', h1 'Bookings' DM Serif 28; Underline tabs 'Upcoming' / 'Past' (14 w600, 2px plum700 underline); Cards (#fff, radius 18, padding 16, shadow '0 1px 2px rgba(74,31,56,.04)'): Avatar 42 (palette, verified), name DM Serif 18, service 12 ink3, StatusPill; Meta: calendar 'Tue, May 19 · 12:30 PM', map-pin '1.2 km'; Whole card tappable -> Tracking; 'Track' secondary sm -> Tracking; 'Directions' primary sm icon map
- Findings:
  - **[CRITICAL · interaction] Tapping a live booking card does nothing** `BOOK-41-F1`
    - Prototype: <div onClick={() => tappable && onTrack && onTrack(b.id, b.status)} ...> where tappable = isLive || expired; onTrack pushes 'tracking' (screens.jsx:534-537; prototype.jsx:700-704)
    - Flutter now: _BookingCard returns a plain Container with no GestureDetector/InkWell (my_bookings_page.dart:327-334)
    - Fix: Wrap it in GestureDetector(onTap: _isLive(b.status) ? () => context.push('/booking/${b.id}/track', extra: b) : b.status == 'EXPIRED' ? () => context.push('/booking/${b.id}/expired', extra: b) : null).
  - **[CRITICAL · components] 'Track' button missing; 'Cancel' shown instead** `BOOK-41-F2`
    - Prototype: <Btn variant="secondary" size="sm" ... onClick={() => onTrack(b.id, b.status)}>Track</Btn><Btn variant="primary" size="sm" icon="map">Directions</Btn> on every upcoming card (screens.jsx:574-579)
    - Flutter now: if (b.canCancel) AiwaButton(label: 'Cancel', variant: secondary, size: sm) + Directions only when providerAddress is non-empty (my_bookings_page.dart:410-437)
    - Fix: Replace 'Cancel' with AiwaButton(label: 'Track', variant: AiwaButtonVariant.secondary, size: AiwaButtonSize.sm, fullWidth: true, onPressed: onTrack). Show Directions for all upcoming cards, disabled when there is no address.
  - **[MAJOR · states] Upcoming list filtered client-side from an unfiltered page** `BOOK-41-F3`
    - Prototype: MY_BOOKINGS.filter(b => ['pending','confirmed','onway','arrived','progress'].includes(b.status)) over all bookings (screens.jsx:501-503)
    - Flutter now: BookingLoadMyEvent() with no status (my_bookings_page.dart:81-87) loads page 0 with size 20 (get_my_bookings_usecase.dart:11-16 overrides the backend default of 10). The Upcoming tab keeps only _liveStatuses from that page (179-180). /bookings/my accepts only page/size (BookingController.java:58-66). Live bookings after the first 20 appear only via 'Load more'. If the first 20 hold no live booking, the 'Nothing booked yet' EmptyState replaces the list (182-196) with no 'Load more'.
    - Fix: Add a status filter to GET /bookings/my (e.g. @RequestParam(required=false) List<BookingStatus> status) and send the live set. Otherwise keep fetching pages while hasMore before deciding the list is empty.

### My Bookings - Past tab — `BOOK-42` (tab, deviates)
- How the user reaches it: Bookings -> 'Past'
- Prototype source: ui_kits/aiwa-app/screens.jsx:501-503, 552-590
- Flutter files: Android/aiwa_app/lib/features/bookings/presentation/pages/my_bookings_page.dart
- Key elements: Statuses completed / cancelled / rejected / noshow / expired; Completed: 'Re-book' ghost sm + 'Leave a review' primary sm star; Cancelled / no-show / rejected reason cards (BOOK-43..45); Expired card tappable -> Expired booking
- Findings:
  - **[MAJOR · states] Past tab shows live bookings too** `BOOK-42-F1`
    - Prototype: ['completed','cancelled','rejected','noshow','expired'].includes(b.status) (screens.jsx:503)
    - Flutter now: Requests status 'COMPLETED,CANCELLED,REJECTED,NO_SHOW' (my_bookings_page.dart:65, 85), but the backend ignores it (BookingController.java:58-66) and Flutter renders `: state.bookings` unfiltered (my_bookings_page.dart:179-181)
    - Fix: final bookings = state.bookings.where((b) => _tab == 'upcoming' ? _liveStatuses.contains(b.status) : _pastSet.contains(b.status)).toList(); with _pastSet = {'COMPLETED','CANCELLED','REJECTED','NO_SHOW','EXPIRED'}.

### Bookings - cancelled reason card (incl. provider-penalty variant) — `BOOK-43` (state, deviates)
- How the user reaches it: Bookings -> Past -> b4 (cancelled by You) / b7 (cancelled by Provider, penalty)
- Prototype source: ui_kits/aiwa-app/screens.jsx:52-53, 58-59, 552-564
- Flutter files: Android/aiwa_app/lib/features/bookings/presentation/pages/my_bookings_page.dart, Android/aiwa_app/lib/features/bookings/domain/entities/booking_entity.dart
- Key elements: danger100 box, radius 10, padding 10/12, x-circle 14 danger700; 'Cancelled by {cancelledBy || 'you'}' w600 + ' · {cancelledAt}' ink3; Quoted reason ink2, e.g. '"Changed my mind"'; Penalty line w600: 'Provider penalty applied for late cancellation.'
- Findings:
  - **[MAJOR · content] Cancelled-by, time and reason not shown** `BOOK-43-F1`
    - Prototype: <strong>{`Cancelled by ${b.cancelledBy || 'you'}`}</strong>{b.cancelledAt && <span> · {b.cancelledAt}</span>}<div>"{b.cancellationReason}"</div> (screens.jsx:556-560)
    - Flutter now: title: 'Booking cancelled', body: null for CANCELLED (my_bookings_page.dart:396-408). BookingEntity has no cancelledBy/cancelledAt/cancellationReason (booking_entity.dart:4-18), though BookingDto provides them (ApiResponse.java:252-254)
    - Fix: Add the fields to BookingEntity/BookingModel. _ReasonBox(title: 'Cancelled by ${b.cancelledBy ?? 'you'}', meta: b.cancelledAt != null ? ' · ${fmt(b.cancelledAt!)}' : null, body: b.cancellationReason != null ? '"${b.cancellationReason}"' : null).
  - **[MAJOR · states] Provider late-cancel penalty line missing** `BOOK-43-F2`
    - Prototype: {b.penaltyApplied && <div style={{ marginTop: 4, fontWeight: 600 }}>Provider penalty applied for late cancellation.</div>} (screens.jsx:561)
    - Flutter now: No penaltyApplied field or line (booking_entity.dart:4-18; my_bookings_page.dart:517-562)
    - Fix: Map BookingDto.penaltyApplied. Add an optional `footnote` to _ReasonBox rendered w600 with a 4px top gap.

### Bookings - no-show reason card — `BOOK-44` (state, deviates)
- How the user reaches it: Bookings -> Past -> b6 'Classic Pedicure' (noshow)
- Prototype source: ui_kits/aiwa-app/screens.jsx:56-57, 552-564
- Flutter files: Android/aiwa_app/lib/features/bookings/presentation/pages/my_bookings_page.dart
- Key elements: user-x icon; 'Marked no-show' + ' · Apr 14 · 7:42 PM'; Quoted reason '"Customer didn't show up"'
- Findings:
  - **[MAJOR · content] No-show time and reason not shown** `BOOK-44-F1`
    - Prototype: 'Marked no-show' · {b.cancelledAt} and "{b.cancellationReason}" (screens.jsx:557-560)
    - Flutter now: title 'Marked no-show', body null (my_bookings_page.dart:400-408)
    - Fix: Same data fields as BOOK-43-F1. Pass meta and body for NO_SHOW.

### Bookings - rejected reason card + 'See alternatives' — `BOOK-45` (state, deviates)
- How the user reaches it: Bookings -> Past -> b5 'Beard Trim' (rejected)
- Prototype source: ui_kits/aiwa-app/screens.jsx:54-55, 565-573, 586-590; prototype.jsx:702
- Flutter files: Android/aiwa_app/lib/features/bookings/presentation/pages/my_bookings_page.dart
- Key elements: x-circle 'Rejected by provider'; Quoted reason '"Fully booked for this slot - try later today or one of these."'; 'See alternatives' secondary sm -> Rejected screen
- Findings:
  - **[CRITICAL · interaction] 'See alternatives' goes to Search instead of the Rejected screen** `BOOK-45-F1`
    - Prototype: onClick={() => onTrack(b.id, 'rejected')} -> if (st === 'rejected') { push('rejected'); } (screens.jsx:588; prototype.jsx:702)
    - Flutter now: onPressed: () => context.go(AppRoutes.search) (my_bookings_page.dart:471)
    - Fix: context.push('/booking/${b.id}/rejected', extra: b) once BOOK-32 exists.
  - **[MAJOR · content] Provider's rejection reason replaced by generic text** `BOOK-45-F2`
    - Prototype: <div>"{b.rejectionReason}"</div> (screens.jsx:570)
    - Flutter now: body: 'The provider couldn't take this slot. Try another time or provider.' (my_bookings_page.dart:405-407)
    - Fix: Map BookingDto.rejectionReason to BookingEntity. body: b.rejectionReason != null ? '"${b.rejectionReason}"' : null.

### Bookings - expired card in Past (tappable) — `BOOK-46` (state, deviates)
- How the user reaches it: Bookings -> Past -> b8 'Russian Volume Lashes'
- Prototype source: ui_kits/aiwa-app/screens.jsx:60-61, 503, 535; components.jsx:158
- Flutter files: none yet
- Key elements: StatusPill 'Expired' (cream bg, ink3 text, ink4 dot); No reason box; Card tap -> Expired booking screen
- To build: StatusPill already supports 'expired' (status_pill.dart:108-114), but my_bookings_page.dart never fetches or keeps EXPIRED (line 65). Add EXPIRED to the past set and the card onTap to '/booking/:id/expired' (BOOK-33).
- Findings:
  - **[CRITICAL · interaction] Expired booking card is not tappable (no Expired booking screen)** `BOOK-46-V1`
    - Prototype: tappable = isLive || b.status === 'expired'. onClick calls onTrack(b.id, 'expired'), which pushes 'expired-booking' (screens.jsx:534-537; prototype.jsx:703)
    - Flutter now: EXPIRED bookings reach the Past list only because it is unfiltered (my_bookings_page.dart:179-181). _BookingCard is a plain Container with no onTap (327-334), and there is no expired route in app_router.dart
    - Fix: Wrap the card in GestureDetector(onTap: b.status == 'EXPIRED' ? () => context.push('/booking/${b.id}/expired', extra: b) : ...) once ExpiredBookingPage (BOOK-33) exists, and add EXPIRED to the Past set (BOOK-42-F2).

### Bookings - Upcoming empty state ('Nothing booked yet') — `BOOK-47` (state, deviates)
- How the user reaches it: Bookings -> Upcoming with no live bookings
- Prototype source: ui_kits/aiwa-app/screens.jsx:522-531; states.jsx:80-107
- Flutter files: Android/aiwa_app/lib/features/bookings/presentation/pages/my_bookings_page.dart, Android/aiwa_app/lib/shared/widgets/empty_state.dart
- Key elements: 64px plum100 circle, calendar-plus icon 27 plum700; 'Nothing booked yet' DM Serif 22; 'When you book a provider, it shows up here so you can track them on the way.' 13.5 ink3 max 270; 'Find a provider' primary (max 250)

### Bookings - Past empty state ('No past appointments') — `BOOK-48` (state, deviates)
- How the user reaches it: Bookings -> Past with no finished bookings
- Prototype source: ui_kits/aiwa-app/screens.jsx:522-531
- Flutter files: Android/aiwa_app/lib/features/bookings/presentation/pages/my_bookings_page.dart
- Key elements: history icon; 'No past appointments'; 'Once an appointment is finished it moves here, ready to re-book in a tap.'; No action

### Bookings - guest locked state — `BOOK-49` (state, deviates)
- How the user reaches it: Splash -> Continue as guest -> tab bar Bookings
- Prototype source: ui_kits/aiwa-app/customer-extras-2.jsx:11-25; prototype.jsx:698-699
- Flutter files: Android/aiwa_app/lib/features/bookings/presentation/pages/my_bookings_page.dart, Android/aiwa_app/lib/shared/widgets/guest_locked_view.dart
- Key elements: 64px plum100 circle, calendar-check plum700 28; Eyebrow 'Browsing as guest'; Title 'See your bookings' DM Serif 24; Body 'Sign in to view and track your bookings.' 13.5 ink2 max 280; 'Sign in or create account' primary lg -> Auth gate
- Findings:
  - **[CRITICAL · interaction] Guest CTA opens Role choice instead of Auth gate** `BOOK-49-F1`
    - Prototype: <GuestLockedScreen ... onSignIn={() => push('auth-gate')} /> (prototype.jsx:699)
    - Flutter now: onPressed: () => context.push(AppRoutes.roleChoice) (guest_locked_view.dart:65)
    - Fix: context.push(AppRoutes.authGate). The route exists at app_router.dart:206.

### Booking data model (MY_BOOKINGS seed fields) — `BOOK-50` (component, deviates)
- How the user reaches it: Backs Bookings list, Tracking, Confirmed, Review
- Prototype source: ui_kits/aiwa-app/screens.jsx:48-62
- Flutter files: Android/aiwa_app/lib/features/bookings/domain/entities/booking_entity.dart, Android/aiwa_app/lib/features/bookings/data/models/booking_model.dart
- Key elements: id, providerId, service, when, distance, status (pending/confirmed/onway/arrived/progress/completed/cancelled/rejected/noshow/expired); location 'home' | 'venue'; cancelledBy, cancelledAt, cancellationReason, penaltyApplied; rejectionReason
- Findings:
  - **[CRITICAL · content] fromJson reads keys the backend never sends** `BOOK-50-F1`
    - Prototype: Cards show provider name and when, e.g. 'Nadia Studio', 'Tue, May 19 · 12:30 PM' (screens.jsx:49, 542, 549)
    - Flutter now: providerName: provider['fullName'], providerBusinessName: providerProfile['businessName'], scheduledDate: json['scheduledDate'], scheduledTime: json['scheduledTime'], providerAddress: providerProfile['address'] (booking_model.dart:25-48). Backend BookingDto has bookingDate, startTime, notes and provider {businessName, ownerName, address, profileImageUrl} (ApiResponse.java:91-101, 232-262). Cards and Confirmed therefore render blank names and ' · ' dates
    - Fix: providerName: provider['ownerName'] ?? '', providerBusinessName: provider['businessName'], providerAddress: provider['address'], scheduledDate: json['bookingDate'] ?? '', scheduledTime: json['startTime'] ?? '', customerNote: json['notes'], servicePrice: (json['totalPrice'] ?? service['price']).
  - **[MAJOR · states] Lifecycle fields missing from BookingEntity** `BOOK-50-F2`
    - Prototype: location, cancelledBy, cancelledAt, cancellationReason, penaltyApplied, rejectionReason (screens.jsx:49-61)
    - Flutter now: BookingEntity has only id, provider*, service*, scheduledDate/Time, status, customerNote, createdAt, providerAddress (booking_entity.dart:4-18)
    - Fix: Add homeService, bookingType, savedAddress, travelFee, totalPrice, paymentStatus, cancelledBy, cancelledAt, cancellationReason, rejectionReason, penaltyApplied, proposedDate, proposedStartTime, estimatedArrivalMinutes, checkedInAt, reviewed, distanceKm, and map them from BookingDto.

### StatusPill (booking statuses) — `BOOK-51` (component, implemented)
- How the user reaches it: Booking cards (Bookings tab)
- Prototype source: ui_kits/aiwa-app/components.jsx:147-172
- Flutter files: Android/aiwa_app/lib/shared/widgets/status_pill.dart
- Key elements: padding 5/10, radius 999, 12 w600, 7px dot, gap 6; pending warn, confirmed info, onway/arrived plum, progress rose, completed success, cancelled/rejected/disputed danger, noshow warn, expired cream/ink3/ink4

### Toast component (success toast) — `BOOK-52` (component, deviates)
- How the user reaches it: Any customer action that calls setToast(...)
- Prototype source: ui_kits/aiwa-app/prototype.jsx:20-39, 735
- Flutter files: Android/aiwa_app/lib/core/theme/app_theme.dart
- Key elements: Absolute top: 56, left/right 16, zIndex 200; bg rgba(42,19,32,.96), bone text 13 w500, radius 14, padding 12/16; 26px success500 circle with #fff check 15; Shadow '0 12px 32px rgba(74,31,56,.3)', blur(8px), aiwa-toast slide-down 320ms; Auto-dismiss 2800ms
- Findings:
  - **[MAJOR · layout] Toast renders at the bottom as a SnackBar** `BOOK-52-F1`
    - Prototype: position: 'absolute', top: 56, left: 16, right: 16 (prototype.jsx:27)
    - Flutter now: snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, ...) used via ScaffoldMessenger.showSnackBar (app_theme.dart:185-193; my_bookings_page.dart:127-129; review_page.dart:91-93)
    - Fix: Create shared/widgets/aiwa_toast.dart: void showAiwaToast(BuildContext c, String msg) inserting an OverlayEntry Positioned(top: MediaQuery.paddingOf(c).top + 8, left: 16, right: 16) with a SlideTransition, removed after 2800ms.
  - **[MAJOR · components] Success check badge missing** `BOOK-52-F2`
    - Prototype: <span style={{ width: 26, height: 26, borderRadius: '50%', background: aiwa.success500 }}><Icon name="check" size={15} color="#fff"/></span> (prototype.jsx:33-35)
    - Flutter now: SnackBar(content: Text(...)) with text only
    - Fix: Row([Container(26x26, circle, AppColors.success500, child: Icon(Icons.check, 15, color: Colors.white)), SizedBox(width: 10), Expanded(Text(msg))])

### Proposed time - countdown under 2 minutes (urgent) — `BOOK-V01` (state, missing)
- How the user reaches it: Tracking (pending) -> provider proposes new time -> Proposed time, while secondsLeft < 120
- Prototype source: ui_kits/aiwa-app/flow-additions-v3.jsx:47-50
- Flutter files: none yet
- Key elements: Countdown row turns aiwa.danger700 (male #2E2A26 / female #6B3A3A; base #8A2230) instead of ink3 (male #7A7268 / female #8A6F71); hourglass icon 14 plus 'Respond within MM:SS or this offer expires automatically.' 12.5px; MM:SS in fontMono (JetBrains Mono) weight 700; Accept / Decline CTAs unchanged
- To build: Part of the new ProposedTimePage (BOOK-30). In the countdown Cubit, expose secondsLeft, then style the row: color: secondsLeft < 120 ? AppColors.danger700 : AppColors.ink3, and use AppTextStyles.mono.copyWith(fontWeight: FontWeight.w700, fontSize: 12.5) for the digits. It depends on BookingDto.proposedDate/proposedStartTime and an expiry timestamp from the backend (not visible in BookingDto), since a client-only 30:00 timer resets on reopen.

### Cancel sheet - 'Something else' selected with note field — `BOOK-V03` (state, missing)
- How the user reaches it: Tracking (pending/accepted) -> Cancel booking -> tap 'Something else'
- Prototype source: ui_kits/aiwa-app/flow-screens.jsx:519-539
- Flutter files: none yet
- Key elements: Selected row: plum100 bg, 1.5px plum700 border, 14px w500 plum900 text, check icon 16 plum700; Textarea below the list: marginTop 12, padding 12, radius 12, 1.5px divider border, paper bg, 13px, height 70, placeholder 'Tell us what happened (optional)'; 'Cancel' (danger md) is enabled because a reason is set
- To build: Part of the new reason sheet (BOOK-29-F1/F5). Show a TextField(maxLines: 3, minLines: 3, style: AppTextStyles.bodySm.copyWith(fontSize: 13)) with AppTheme.inputBorder(AppColors.divider) and radius 12 only when reason == 'Something else'. Return the note with the reason. The backend cancel endpoint accepts only `reason`, so send '$reason: $note' or add a notes param.

### Toast - 'Booking cancelled. Reason: {reason}' — `BOOK-55` (toast, deviates)
- How the user reaches it: Tracking -> Cancel booking -> pick reason -> Cancel
- Prototype source: ui_kits/aiwa-app/prototype.jsx:737-741
- Flutter files: Android/aiwa_app/lib/features/bookings/presentation/pages/my_bookings_page.dart
- Key elements: Success toast, then reset to Bookings tab
- Findings:
  - **[MAJOR · content] Toast omits the cancellation reason** `BOOK-55-F1`
    - Prototype: setToast('Booking cancelled. Reason: ' + reason) (prototype.jsx:739)
    - Flutter now: SnackBar(content: Text('Booking cancelled')) (my_bookings_page.dart:127-129)
    - Fix: After the reason sheet (BOOK-29): showAiwaToast(context, 'Booking cancelled. Reason: $reason').

### Toast - 'Thanks - your review is live.' — `BOOK-56` (toast, deviates)
- How the user reaches it: Review -> Submit review
- Prototype source: ui_kits/aiwa-app/prototype.jsx:712
- Flutter files: Android/aiwa_app/lib/features/reviews/presentation/pages/review_page.dart
- Key elements: Success toast, then reset to Bookings tab

### Toast - 'Complaint submitted. We will reach out via WhatsApp.' — `BOOK-57` (toast, missing)
- How the user reaches it: Tracking -> Report a problem -> Submit complaint
- Prototype source: ui_kits/aiwa-app/prototype.jsx:714
- Flutter files: none yet
- Key elements: Success toast, then pop back to Tracking
- To build: Show it on complaint submit success in the new ComplaintPage (BOOK-35).

### Toast - 'New time confirmed - your calendar and reminders are updated.' — `BOOK-58` (toast, missing)
- How the user reaches it: Proposed time -> Accept new time
- Prototype source: ui_kits/aiwa-app/prototype.jsx:634
- Flutter files: none yet
- Key elements: Success toast, then reset to Tracking (Accepted)
- To build: Show it after proposal-response?accept=true succeeds (BOOK-30).

### Toast - 'Payment confirmed. Receipt sent.' — `BOOK-59` (toast, missing)
- How the user reaches it: Payment confirm -> Yes, I paid -> Rate your provider
- Prototype source: ui_kits/aiwa-app/prototype.jsx:696
- Flutter files: none yet
- Key elements: Success toast, then pop to Tracking
- To build: Show it after confirm-payment?paid=true (BOOK-39).

### Toast - 'Reported as unpaid. AIWA support has been notified.' — `BOOK-60` (toast, missing)
- How the user reaches it: Payment confirm -> No / something's wrong -> Submit as unpaid
- Prototype source: ui_kits/aiwa-app/prototype.jsx:697
- Flutter files: none yet
- Key elements: Success toast, then pop to Tracking
- To build: Show it after confirm-payment?paid=false (BOOK-40).
