# Booking creation: booking type, Book Now check, booking screen variants, slot conflict, confirmed

Generated from the AIWA prototype-fidelity audit. Paths: prototype = `C:/Users/alyar/Desktop/AIWA Design System (2)/design_handoff_aiwa_app/`, Flutter = `Android/aiwa_app/`.


## Entries

### Booking type choice (Now or later) — `BOOK-01` (screen, missing)
- How the user reaches it: Home -> provider card -> Provider profile -> service '+' or 'Book now' (individual provider; shops go via Staff picker, guests via Auth gate) -> Booking type
- Prototype source: ui_kits/aiwa-app/flow-screens.jsx:162-221; prototype.jsx:686-691
- Flutter files: none yet
- Key elements: Back IconBtn arrow-left; Eyebrow 'How do you want to book'; h1 'Now, or later?' DM Serif 30 plum900 (male #2E2A26 / female #6B3A3A); Body '{providerName} accepts both same-day requests and scheduled bookings.'; Book now card: plum700 bg, radius 22, radial glow, Eyebrow rose300 'Book now', 'Get someone on the way' 26px, clock 'Est. arrival 25-40 min', map-pin 'Comes to you'; Schedule card: paper, 1.5px divider border, 'Pick a date & time slot', calendar 'Up to 14 days out', check-circle 'Provider confirms slot'; Cream info note (info icon): 'Either way, payment is cash on visit. Online payment is coming in a future version.'; Now -> BookNowCheckSheet; Schedule -> BookingScreen (scheduled)
- To build: Create features/bookings/presentation/pages/booking_type_page.dart with route '/booking-type/:providerId?serviceId=' in app_router.dart. Change provider_detail_page.dart _book() (lines 62-68) to push this page instead of '/booking/:id'. Build two tappable cards: a plum700 card with AiwaGlow (screen_chrome.dart) and a paper card with a 1.5px divider border. Add the cream note Container. Scheduled pushes '/booking/:id?mode=scheduled'; Now opens BookNowCheckSheet (BOOK-02). Backend already accepts BookingRequest.bookingType SCHEDULED|BOOK_NOW, and BookingDto.estimatedArrivalMinutes can feed the ETA. Reuse AiwaIconButton, EyebrowLabel, AppTextStyles.h1.copyWith(fontSize: 30, height: 1.05).

### Book Now availability check - checking state (and AVAILABLE pass-through) — `BOOK-02` (sheet, missing)
- How the user reaches it: Booking type -> tap 'Book now' card
- Prototype source: ui_kits/aiwa-app/system-screens.jsx:228-260; prototype.jsx:763-768
- Flutter files: none yet
- Key elements: Bottom sheet: bone bg, top radius 24, 40x4 handle, scrim rgba(42,19,32,.48), not dismissable while checking; 46px plum100 circle, 'radar' icon plum700 with aiwa-pulse 1.1s; 'Checking availability...' DM Serif 19 plum900; 'Confirming {providerName} can take this right now.' 12.5 ink3; After 850ms with no block reason: sheet closes, bookingMode='now', push BookingScreen
- To build: Use showModalBottomSheet(isDismissible: false while checking) backed by a small Cubit that resolves availability. aiwa-backend has no GET /bookings/book-now/availability endpoint (none in BookingController). Either add one, or derive the result from ProviderSummaryDto.offlineMode/vacationMode/settlementPaused (ApiResponse.java:106-108) plus a busy check. Reuse AppTheme.sheetDecoration, EyebrowLabel and an AnimationController pulse. On AVAILABLE, push BookingPage with mode=now (BOOK-09).

### Book Now blocked - OFFLINE — `BOOK-03` (sheet, missing)
- How the user reaches it: Maadi Hammam (bookNowStatus OFFLINE) -> Staff picker -> Booking type -> Book now; or Preview states 'Book Now - offline'
- Prototype source: ui_kits/aiwa-app/system-screens.jsx:221, 261-273; screens.jsx:13
- Flutter files: none yet
- Key elements: 46px warn100 circle, wifi-off icon warn700 21px; Eyebrow warn700 'Not online'; h2 DM Serif 23 '{n} is offline right now.'; Body 13.5 ink2: 'They'll show as available again the moment they come back online. You can try Book Now later, or pick a scheduled time now.'; 'Choose a scheduled time' primary lg icon calendar -> BookingScreen (scheduled); 'See other providers nearby' secondary lg icon search -> Discover tab
- To build: Add a blocked-reason body to the BOOK-02 sheet, driven by a map like BOOK_NOW_BLOCKS: {icon, eyebrow, title(name), body}. Buttons: AiwaButton(lg, icon Icons.calendar_today) goes to '/booking/:id?mode=scheduled'; AiwaButton(secondary, lg, icon Icons.search) goes to context.go(AppRoutes.search). Needs provider offline status from the backend (ProviderSummaryDto.offlineMode).

### Book Now blocked - BUSY — `BOOK-04` (sheet, missing)
- How the user reaches it: Omar - Barbier (bookNowStatus BUSY) -> Booking type -> Book now; or Preview states 'Book Now - busy'
- Prototype source: ui_kits/aiwa-app/system-screens.jsx:222, 261-273; screens.jsx:17
- Flutter files: none yet
- Key elements: clock icon on warn100 circle; Eyebrow 'Fully booked'; Title '{n} is busy with another client.'; Body 'Every Book Now slot is taken for the next stretch. A scheduled slot later today is usually faster than waiting.'; Same two CTAs as OFFLINE
- To build: Same sheet as BOOK-03 with the BUSY copy. The backend has no busy flag in ProviderSummaryDto; it needs an availability endpoint (see BOOK-02).

### Book Now blocked - VACATION — `BOOK-05` (sheet, missing)
- How the user reaches it: Mariam Lashes (vacationMode, bookNowStatus VACATION) -> Booking type -> Book now; or Preview states 'Book Now - vacation'
- Prototype source: ui_kits/aiwa-app/system-screens.jsx:223, 261-273; screens.jsx:18
- Flutter files: none yet
- Key elements: palmtree icon; Eyebrow 'On vacation'; Title '{n} is on vacation.'; Body 'They've paused all bookings for now. We'll show them again as soon as they're back.'; Same two CTAs
- To build: Same sheet as BOOK-03. Drive it from ProviderSummaryDto.vacationMode (ApiResponse.java:106).

### Book Now blocked - SETTLEMENT_PAUSED — `BOOK-06` (sheet, missing)
- How the user reaches it: Preview states 'Book Now - provider paused' only (no seed provider uses it)
- Prototype source: ui_kits/aiwa-app/system-screens.jsx:224, 261-273; prototype.jsx:787
- Flutter files: none yet
- Key elements: banknote icon; Eyebrow 'Temporarily paused'; Title '{n} can't take new bookings right now.'; Body 'They're settling an outstanding balance with AIWA. This clears automatically once that's paid - try again soon.'; Same two CTAs
- To build: Same sheet as BOOK-03. Drive it from ProviderSummaryDto.settlementPaused (ApiResponse.java:108).

### Book Now blocked - NOT_APPROVED (defined, not reachable in prototype) — `BOOK-07` (sheet, missing)
- How the user reaches it: Not reachable. Defined in BOOK_NOW_BLOCKS, but no seed provider or Preview state uses it
- Prototype source: ui_kits/aiwa-app/system-screens.jsx:225
- Flutter files: none yet
- Key elements: shield-alert icon; Eyebrow 'Unavailable'; Title '{n} isn't taking bookings.'; Body 'This provider, staff member, or service is temporarily inactive. Try another provider nearby.'
- To build: Include it in the same reason map as BOOK-03 so the backend's inactive-provider/service result has a designed surface.

### Booking screen - scheduled (date & slot picker + CTA) — `BOOK-08` (screen, deviates)
- How the user reaches it: Provider profile -> Booking type -> 'Pick a date & time slot' (or Book Now sheet -> 'Choose a scheduled time')
- Prototype source: ui_kits/aiwa-app/screens.jsx:329-465; prototype.jsx:692
- Flutter files: Android/aiwa_app/lib/features/bookings/presentation/pages/booking_page.dart, Android/aiwa_app/lib/features/bookings/presentation/bloc/booking_bloc.dart, Android/aiwa_app/lib/features/bookings/data/datasources/booking_remote_datasource.dart, Android/aiwa_app/lib/features/providers/presentation/pages/provider_detail_page.dart
- Key elements: Header: back IconBtn, Eyebrow 'Book a service', h2 'Pick a time' 22; Summary card: Avatar 44 (provider palette, verified), name DM Serif 17, '{service} · {duration}' 12 ink3, price DM Serif 18; Eyebrow 'Date · May 2026' + 5 equal day chips (Mon 18-Fri 22); Eyebrow 'Available slots' + 4-col grid, unavailable slots struck through; Where section (BOOK-10/11); Payment cash card (BOOK-12); Sticky CTA: 'Total · cash' 13 ink3 + 'EGP 350' DM Serif 22 + 'Confirm booking' primary lg -> toast + ConfirmedScreen
- Findings:
  - **[CRITICAL · interaction] Create-booking request uses field names the backend rejects** `BOOK-08-F1`
    - Prototype: Confirm creates the booking: onConfirm={() => { setActiveStatus(...); setToast(...); push('confirmed'); }} (prototype.jsx:692)
    - Flutter now: 'scheduledDate': scheduledDate, 'scheduledTime': scheduledTime, 'customerNote': customerNote (Android/aiwa_app/lib/features/bookings/data/datasources/booking_remote_datasource.dart:47-49). Backend BookingRequest expects bookingDate / startTime / notes / bookingType / homeService / savedAddressId (aiwa-backend/.../dto/request/BookingRequest.java:20-36), and BookingServiceImpl throws when a SCHEDULED request has a null bookingDate/startTime (~line 160). Result: 'Confirm booking' always ends in the error SnackBar
    - Fix: In booking_remote_datasource.dart createBooking send: data: {'providerId': providerId, 'serviceId': serviceId, 'bookingDate': scheduledDate, 'startTime': scheduledTime, 'bookingType': isNow ? 'BOOK_NOW' : 'SCHEDULED', 'homeService': homeService, if (addressId != null) 'savedAddressId': addressId, 'paymentMethod': 'CASH', if (customerNote != null) 'notes': customerNote}. Add an Idempotency-Key header (a UUID per tap).
  - **[CRITICAL · interaction] Flow skips the Booking type (Now/Schedule) step** `BOOK-08-F2`
    - Prototype: Provider onBook: else { push('booking-type'); } (prototype.jsx:661-666); booking-type passes bookingMode to 'booking' (686-692)
    - Flutter now: _book(): context.push('/booking/${widget.providerId}$query') (provider_detail_page.dart:62-68); BookingPage has no bookingMode parameter (booking_page.dart:24-32)
    - Fix: Push BookingTypePage (BOOK-01) from _book(). Add `final String mode;` to BookingPage and read it from state.uri.queryParameters['mode'] in app_router.dart:187-196.
  - **[MAJOR · layout] 'Where' section (home vs salon + saved addresses) missing** `BOOK-08-F3`
    - Prototype: <Eyebrow>Where</Eyebrow> with the toggle and address list between Slots and Payment (screens.jsx:403-440)
    - Flutter now: The slot grid is followed directly by const EyebrowLabel('Payment') (booking_page.dart:270-272)
    - Fix: Insert a Where block after the slots: SizedBox(height: 22), EyebrowLabel('Where'), the toggle (BOOK-10), then the address list (BOOK-11) when home service is selected.
  - **[MAJOR · states] Unavailable slots are hidden instead of shown disabled** `BOOK-08-F5`
    - Prototype: All slots render; unavailable ones use background: aiwa.cream, color: aiwa.ink4, textDecoration: 'line-through', cursor: 'not-allowed' (screens.jsx:390-397)
    - Flutter now: Only free `times` are rendered (booking_page.dart:178-186, 261-269). _SlotChip has no disabled style (541-580)
    - Fix: Keep the full day grid with an `available` flag. In _SlotChip, when !available: color AppColors.cream, text AppColors.ink4, TextStyle(decoration: TextDecoration.lineThrough), onTap: null.
  - **[MAJOR · states] Slot-taken conflict shown as a raw SnackBar** `BOOK-08-F6`
    - Prototype: SlotConflictSheet 'Someone booked that slot.' with alternative times (system-screens.jsx:150-186; prototype.jsx:760-762)
    - Flutter now: else if (state is BookingError) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message))); } (booking_page.dart:114-118). The backend reports a taken slot as HTTP 400 'This time slot is already booked. Please choose another time' via BusinessException('booking.error.conflict') (BookingServiceImpl.java:175; GlobalExceptionHandler.java:31-39). It never returns 409, and the Failure carries only a message.
    - Fix: Backend: return 409 (or an errorCode 'booking.error.conflict') for slot conflicts. Flutter: carry statusCode/errorCode on ServerFailure/BookingError. In booking_page.dart's BlocListener, open SlotConflictSheet (BOOK-13) when it matches, and fall back to the toast for other errors.
  - **[CRITICAL · interaction] Slots come from the weekly-hours endpoint, so the slot grid is always empty** `BOOK-08-V1`
    - Prototype: 'Available slots' 4-col grid with 12 time buttons for the chosen day (screens.jsx:341-346, 386-399)
    - Flutter now: ProviderRemoteDataSource.getAvailableSlots GETs ApiConstants.providerAvailability(id) = '/providers/$id/availability?date=' (provider_remote_datasource.dart:54-62). The backend returns weekly AvailabilityDto {dayOfWeek, startTime, endTime, slotDurationMinutes, available} and ignores date (AvailabilityController.java:27-32; ApiResponse.java:191-199). ProviderRepositoryImpl reads e['date'] and e['times'] (provider_repository_impl.dart:53-58), which never exist, so times is always empty. The page therefore always shows 'No free slots on this day — try another date.' (booking_page.dart:238-251), and the CTA stays disabled on 'Choose a time'. ApiConstants.availableSlots '/bookings/slots' (api_constants.dart:45) is unused, and GetAvailableSlotsUseCase is a no-op (get_available_slots_usecase.dart:13-15).
    - Fix: Implement GetAvailableSlotsUseCase against GET /bookings/slots?providerId=&serviceId=&date= (BookingController.java:209-215), which returns TimeSlotDto {startTime, endTime, booked}. Reload when the selected service or date changes, because serviceId is required. Map booked == true to the disabled/struck-through chip (resolves BOOK-08-F5), e.g. _SlotChip(time: s.startTime, available: !s.booked).

### Booking screen - Book Now mode variant — `BOOK-09` (state, missing)
- How the user reaches it: Booking type -> Book now -> availability AVAILABLE -> Booking screen (bookingMode 'now')
- Prototype source: ui_kits/aiwa-app/screens.jsx:336, 405-408, 420; prototype.jsx:692, 766
- Flutter files: none yet
- Key elements: Where: plum100 banner with house icon, 12.5 plum700 w600: 'Book Now always comes to your address - confirm which one below.'; Address list always shown (no salon option); On confirm: toast 'Provider is on the way.' and activeStatus 'confirmed'
- To build: Add a mode param to BookingPage. When mode == now: replace the toggle with InlineBanner(tone: BannerTone.plum, icon: Icons.home_outlined, body: ...), force homeService = true and send bookingType 'BOOK_NOW'. The backend picks today plus the next slot and computes the ETA (BookingServiceImpl ~152-178), so the day/slot pickers could be hidden. On success, show the toast from BOOK-54.

### Booking screen - 'Where' home vs salon toggle — `BOOK-10` (component, missing)
- How the user reaches it: Booking screen (scheduled) -> Where section
- Prototype source: ui_kits/aiwa-app/screens.jsx:403-419
- Flutter files: none yet
- Key elements: Eyebrow 'Where'; Two flex buttons: 'At my address' (house) / 'At the salon' (store); padding 12/10, radius 14, 13px w600; Selected: plum700 bg, #fff text/icon, transparent border. Unselected: #fff bg, ink text, plum700 icon, divider border
- To build: In booking_page.dart add `bool _homeService = true;` and a Row of two Expanded AnimatedContainer toggles (AppTheme.dur2, easeSoft). Send BookingRequest.homeService (the field exists in the backend). When 'At the salon' is selected, hide the address list.

### Booking screen - saved address selector (Home / Work / Add new address) — `BOOK-11` (component, missing)
- How the user reaches it: Booking screen -> Where -> 'At my address' (or always in Book Now mode)
- Prototype source: ui_kits/aiwa-app/screens.jsx:335, 420-438; customer-extras-2.jsx:179-182
- Flutter files: none yet
- Key elements: Address rows: 32px plum700 tile with house / briefcase icon #fff, label 13.5 w600, address 11.5 ink3; Selected: plum100 bg, 1.5px plum700 border, check icon plum700; Seed: Home '14 Road 9, Maadi, Cairo'; Work 'Smart Village, 6th of October'; Dashed 1.5px divider button '+ Add new address' plum700 12.5 w600 (no handler in prototype)
- To build: Flutter has no saved-addresses feature or endpoint in api_constants.dart. The backend supports BookingRequest.savedAddressId and BookingDto.savedAddress. Build an addresses datasource/cubit (shared with the account partition's Addresses screen), a SavedAddressRow widget, and wire 'Add new address' to the address form route. Send savedAddressId in the create payload.

### Booking screen - Cash on visit payment card — `BOOK-12` (component, deviates)
- How the user reaches it: Booking screen -> Payment section
- Prototype source: ui_kits/aiwa-app/screens.jsx:443-453
- Flutter files: Android/aiwa_app/lib/features/bookings/presentation/pages/booking_page.dart
- Key elements: Eyebrow 'Payment'; Card #fff radius 14 padding 14 divider border; 36px gold100 tile, banknote icon gold700; 'Cash on visit' 14 w600 / 'Pay the provider directly after your service' 12 ink3; check icon success500 18

### Slot conflict sheet ('Someone booked that slot.') — `BOOK-13` (sheet, missing)
- How the user reaches it: Booking screen -> Confirm booking when the slot was just taken (409); or Preview states 'Slot just taken'
- Prototype source: ui_kits/aiwa-app/system-screens.jsx:150-186; prototype.jsx:760-762, 783
- Flutter files: none yet
- Key elements: Bone sheet, radius 24, handle, scrim rgba(42,19,32,.48); 46px warn100 circle, calendar-x warn700; Eyebrow warn700 'Just taken'; h2 23 'Someone booked that slot.'; Body 'It went in the last moment. Here's what {providerName} still has free today.'; Alternative chips '1:30 PM' '3:00 PM' '5:30 PM' (selected plum700/#fff, radius 13); 'Pick another day' secondary lg / 'Book slot' -> 'Book {t}' primary lg, disabled .45 until picked; Toast 'Rebooked for {t}.'
- To build: Create shared/widgets/slot_conflict_sheet.dart (showModalBottomSheet with AppTheme.sheetDecoration). Open it from the booking_page.dart BlocListener when BookingError carries a 409. Feed it the remaining times from ProviderLoaded.slots for _selectedDate. On pick, set _selectedTime, re-dispatch BookingCreateEvent and show the toast from BOOK-61. 'Pick another day' closes the sheet and scrolls to the day picker.

### Booking confirmed ('You said aiwa. We told Nadia.') — `BOOK-14` (screen, deviates)
- How the user reaches it: Booking screen -> Confirm booking
- Prototype source: ui_kits/aiwa-app/screens.jsx:470-494; prototype.jsx:692-693
- Flutter files: Android/aiwa_app/lib/features/bookings/presentation/pages/booking_confirmed_page.dart, Android/aiwa_app/lib/core/router/app_router.dart
- Key elements: 96px success100 circle, check 48 success700; Eyebrow rose700 'Booking placed'; h1 30: 'You said *aiwa*. We told Nadia.' (italic rose700 'aiwa'); Body 'Tuesday, May 19 at 12:30 PM. We'll ping you the moment she confirms - usually within 30 minutes.'; Summary card: Provider / Service / When / Total (DM Serif 20); 'View my bookings' primary lg -> Tracking; 'Add to calendar' ghost
- Findings:
  - **[CRITICAL · interaction] 'View my bookings' goes to the list instead of Tracking** `BOOK-14-F1`
    - Prototype: <ConfirmedScreen onDone={() => { setActiveBookingId('b1'); reset('tracking'); }} /> (prototype.jsx:693)
    - Flutter now: onPressed: () => context.go(AppRoutes.myBookings) (booking_confirmed_page.dart:119-124)
    - Fix: Once TrackingPage exists (BOOK-15): context.go('/booking/${booking.id}/track', extra: booking). The prototype label says 'View my bookings' but its target is Tracking; keep the label and change the target.
  - **[MAJOR · components] 'Add to calendar' button missing (replaced by 'Back to home')** `BOOK-14-F2`
    - Prototype: <Btn variant="ghost" full>Add to calendar</Btn> (screens.jsx:490)
    - Flutter now: AiwaButton(label: 'Back to home', onPressed: () => context.go(AppRoutes.home), variant: AiwaButtonVariant.ghost) (booking_confirmed_page.dart:126-131)
    - Fix: Replace it with AiwaButton(label: 'Add to calendar', variant: ghost, fullWidth: true, onPressed: _addToCalendar). Use the add_2_calendar package, or url_launcher with a Google Calendar template URL.
  - **[MAJOR · content] Headline and summary render blank provider/date from the data mapping** `BOOK-14-F3`
    - Prototype: 'We told Nadia.' and 'Provider: Nadia Studio', 'When: Tue, May 19 · 12:30 PM' (screens.jsx:477-484)
    - Flutter now: '. We told $provider.' where provider = booking.displayProviderName (booking_confirmed_page.dart:31, 73). BookingModel reads provider['fullName'] and providerProfile['businessName'], json['scheduledDate'] and json['scheduledTime'] (booking_model.dart:33-34, 41-42). The backend BookingDto sends provider.businessName/ownerName, bookingDate and startTime (ApiResponse.java:91-101, 232-239), so the page reads 'We told .' and When ' · '
    - Fix: Fix BookingModel.fromJson (see BOOK-50-F1).
  - **[MAJOR · states] 'Booking placed. Waiting to confirm.' toast not shown** `BOOK-14-F6`
    - Prototype: setToast(bookingMode === 'now' ? 'Provider is on the way.' : 'Booking placed. Waiting to confirm.') before push('confirmed') (prototype.jsx:692)
    - Flutter now: if (state is BookingCreated) { context.go('/booking-confirmed/${state.booking.id}', extra: state.booking); } with no toast (booking_page.dart:109-113)
    - Fix: After context.go, call showAiwaToast(context, 'Booking placed. Waiting to confirm.') (see BOOK-52 / BOOK-53).

### Slot conflict sheet - alternative selected — `BOOK-V02` (state, missing)
- How the user reaches it: Booking -> Confirm booking (slot taken) -> Slot conflict sheet -> tap an alternative chip
- Prototype source: ui_kits/aiwa-app/system-screens.jsx:151, 170-181
- Flutter files: none yet
- Key elements: Picked chip: plum700 bg (male #2E2A26 / female #6B3A3A), '#fff' text, transparent 1.5px border, radius 13, padding 11/16, 14px w600; Unpicked chips: paper bg, ink text, 1.5px divider border; Primary lg CTA label changes 'Book slot' -> 'Book {t}' and opacity .45 -> 1 (pointerEvents none until picked); Tap -> toast 'Rebooked for {t}.' and the sheet closes
- To build: Part of the SlotConflictSheet (BOOK-13). Keep `String? picked` in a StatefulBuilder. AiwaButton(label: picked == null ? 'Book slot' : 'Book $picked', onPressed: picked == null ? null : ...) already renders the .45 disabled opacity (aiwa_button.dart:111-112). Alternatives should come from GET /bookings/slots with booked=false (see BOOK-08-V1).

### Toast - 'Booking placed. Waiting to confirm.' — `BOOK-53` (toast, missing)
- How the user reaches it: Booking screen (scheduled) -> Confirm booking
- Prototype source: ui_kits/aiwa-app/prototype.jsx:692
- Flutter files: none yet
- Key elements: Success toast over ConfirmedScreen
- To build: In booking_page.dart:109-113, after context.go('/booking-confirmed/...'), call showAiwaToast(context, 'Booking placed. Waiting to confirm.') (BOOK-52 helper).

### Toast - 'Provider is on the way.' — `BOOK-54` (toast, missing)
- How the user reaches it: Book Now -> Booking screen -> Confirm booking
- Prototype source: ui_kits/aiwa-app/prototype.jsx:692
- Flutter files: none yet
- Key elements: Success toast after a Book Now booking
- To build: Depends on the Book Now mode (BOOK-09). Show it when mode == now on BookingCreated.

### Toast - 'Rebooked for {time}.' — `BOOK-61` (toast, missing)
- How the user reaches it: Slot conflict sheet -> pick alternative -> Book {time}
- Prototype source: ui_kits/aiwa-app/prototype.jsx:760-762
- Flutter files: none yet
- Key elements: Success toast after picking an alternative slot
- To build: Show it after the re-dispatched BookingCreateEvent succeeds from the SlotConflictSheet (BOOK-13).
