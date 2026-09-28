# Provider app: services, schedule, profile, wallet, business info, gallery, reviews, staff

Generated from the AIWA prototype-fidelity audit. Paths: prototype = `C:/Users/alyar/Desktop/AIWA Design System (2)/design_handoff_aiwa_app/`, Flutter = `Android/aiwa_app/`.


## Entries

### Provider Services tab — `PROV-26` (screen, missing)
- How the user reaches it: Provider app -> Services tab
- Prototype source: ui_kits/aiwa-app/provider-screens.jsx:401-430; ui_kits/aiwa-app/prototype.jsx:439
- Flutter files: none yet
- Key elements: Header padding 68px 22px 10px: Eyebrow 'Your menu', h1 'Services' DM Serif 28; primary sm 'New' (plus) aligned bottom-right; Rows #fff radius 16 padding 14 border divider; inactive rows opacity .55; Name 15/600 ink; meta 12 ink3: '{d} min' · 'Fixed price' | 'Starts at' · 'Hidden' (danger700 600) with 3px dots; Price 'EGP 1,200' DM Serif 18 plum900; pencil IconBtn 34
- To build: Tab route /provider/services -> ProviderServicesPage + ServicesBloc. GET /providers/{id}/services (ApiConstants.providerServices), POST /provider/services, PUT/DELETE /provider/services/{id} (api_constants.dart:31-33; backend ServiceController). ServiceDto has name, price, durationMinutes, pricingType (fixed vs starts-at), active. Reuse PageTitle(trailing: AiwaButton(size: sm, icon: Icons.add, label: 'New')), MetaDot (screen_chrome.dart:407) and AiwaIconButton(icon: Icons.edit_outlined, size: 34). The prototype has no edit/new form (buttons have no handler), so the form design is TBD.

### Provider Schedule tab (weekly availability) — `PROV-27` (screen, missing)
- How the user reaches it: Provider app -> Schedule tab
- Prototype source: ui_kits/aiwa-app/provider-screens.jsx:435-459,472-474; ui_kits/aiwa-app/prototype.jsx:440
- Flutter files: none yet
- Key elements: Eyebrow 'Weekly availability', h1 'Schedule' DM Serif 28; 7 day rows #fff radius 14 padding 14px 16px border: day 44w 13/600 uppercase .06em (plum900 open / ink4 closed); hours JetBrains Mono 14 '10:00 – 20:00' or 'Closed'; 40x22 toggle (on plum700 / off divider, 18px white knob); Tip card plum100 radius 14 12px plum700: 'Tip: Tap any day to add multiple time blocks, breaks, or one-off availability changes.'
- To build: Tab route /provider/schedule. GET /providers/{id}/availability, POST /provider/availability, DELETE /provider/availability/{id} (api_constants.dart:34-36; backend AvailabilityController). No toggle widget exists in lib/shared/widgets, so add AiwaToggle (kit Toggle states.jsx:209-224 is 42x24; this inline one is 40x22). Mono text via AppTextStyles.mono. Day-detail editing is only hinted in the tip copy.

### Travel buffer stepper — `PROV-28` (component, missing)
- How the user reaches it: Provider app -> Schedule tab -> below the week list
- Prototype source: ui_kits/aiwa-app/provider-screens.jsx:436,460-471
- Flutter files: none yet
- Key elements: Paper card radius 14 padding 14 border; car tile 36 radius 10 plum100/plum700; 'Travel buffer between bookings' 14/600; 'Blocks slots too close together for home visits.' 11.5 ink3; 28px round '−' / '+' buttons (1px divider, #fff, plum700); value JetBrains Mono 14/600 plum900 min-width 52 '{n} min'; Default 15, step 5, clamp 0–60
- To build: Persist via PUT /provider/profile with travelBufferMinutes (aiwa-backend ProviderProfileRequest.java:26; ApiConstants.myProviderProfile). Debounce saves. Pure local widget with two small circular InkWell buttons.

### Provider Profile tab — `PROV-29` (screen, missing)
- How the user reaches it: Provider app -> Profile tab
- Prototype source: ui_kits/aiwa-app/provider-screens.jsx:482-557; ui_kits/aiwa-app/prototype.jsx:441
- Flutter files: none yet
- Key elements: Hero gradient padding 68px 22px 24px + radial rgba(231,186,182,.4) at 70% 30%; Avatar rose 64 verified; 'Nadia Studio' DM Serif 24; 'Maadi · Hair · Color specialist' 13 rose300; Vacation/offline card (PROV-30) and Verified banner (PROV-31); Rows (36 tile radius 10 plum100/plum700, label 15/500, value 13 ink3, chevron 16 ink3, divider): Business info -> business-info; Gallery '12 photos' -> gallery; Staff & availability -> staff; Wallet & settlement -> wallet; Notifications -> provider-notifications; Reviews '4.9 · 312' -> reviews; Safety & policies; WhatsApp support; Sign out (danger, no chevron) -> sign-out ConfirmSheet
- To build: Tab route /provider/profile -> ProviderProfilePage. Hero: reuse AppTheme.heroGradient + AiwaGlow(opacity .4) + AiwaAvatar(rose, 64, verified: isApproved). Name/category from AuthBloc user.providerProfile (ProviderProfileSummary has only id/businessName/verificationStatus, so area/category need GET /providers/{id}); rating/count from GET /provider/dashboard; gallery count from the gallery GET. Rows: SettingsRow (screen_chrome.dart:155) matches the spec (36 tile, radius 10, gap 14, 15/500, padding 14/4, divider). Note SettingsRow hides the chevron when onTap == null (screen_chrome.dart:223), so give Safety & policies / WhatsApp support handlers (customer equivalents exist). Move the sign-out trigger here from the dashboard hero.

### Vacation / offline mode toggle — `PROV-30` (component, missing)
- How the user reaches it: Provider app -> Profile tab -> Vacation / offline card
- Prototype source: ui_kits/aiwa-app/provider-screens.jsx:483,508-522
- Flutter files: none yet
- Key elements: Paper card radius 14 padding 14 border; palmtree icon in 36 circle (off: plum100/plum700; on: warn100/warn700); 'Vacation / offline mode' 14/600; sub 11.5 ink3 toggles 'Pause new bookings temporarily.' <-> "You're hidden from search."; 40x22 toggle: on warn500, off divider; 18px white knob with shadow 0 1px 2px rgba(0,0,0,.2)
- To build: PATCH /provider/mode?vacationMode=true|false (aiwa-backend ProviderModeController.java:22-33); add ApiConstants.providerMode = '/provider/mode'. Optimistic toggle with revert and a toast on failure. The initial value needs vacationMode in the provider profile payload (verify GET /providers/{id} or /auth/me exposes it). Reuse the AiwaToggle from PROV-27 with a warn tone. Icons.beach_access_outlined as the palmtree stand-in.

### Verified provider banner — `PROV-31` (banner, missing)
- How the user reaches it: Provider app -> Profile tab
- Prototype source: ui_kits/aiwa-app/provider-screens.jsx:524-533
- Flutter files: none yet
- Key elements: success100 card, 1px success500@20% border, radius 14, padding 14; 36 circle success500 with badge-check white; 'Verified provider' 14/600 success700; 'Approved by AIWA on May 2, 2026.' 12 success700 @.85
- To build: Render when user.providerProfile.isApproved (user_entity.dart:66). The approval date is not in ProviderProfileSummary (user_entity.dart:55-66), so expose verifiedAt from the backend. Same structure as _PendingCallout (dashboard_page.dart:397-470) with success tokens and Icons.verified_rounded.

### Provider sign-out ConfirmSheet — `PROV-32` (sheet, deviates)
- How the user reaches it: Provider app -> Profile tab -> Sign out
- Prototype source: ui_kits/aiwa-app/prototype.jsx:491-493; ui_kits/aiwa-app/states.jsx:227-257; ui_kits/aiwa-app/provider-screens.jsx:493
- Flutter files: Android/aiwa_app/lib/features/provider_dashboard/presentation/pages/dashboard_page.dart, Android/aiwa_app/lib/shared/widgets/confirm_sheet.dart
- Key elements: ConfirmSheet tone 'neutral' (plum100/plum700 icon chip, primary confirm button), icon log-out; Eyebrow 'Provider account'; title 'Sign out of AIWA?'; Body: "Your bookings stay exactly as they are. You'll need your number and a code to sign back in."; Cancel secondary lg + 'Sign out' primary lg; confirm -> toast 'Signed out.'

### Toast 'Signed out.' — `PROV-33` (toast, missing)
- How the user reaches it: Provider app -> Profile -> Sign out -> Sign out
- Prototype source: ui_kits/aiwa-app/prototype.jsx:491
- Flutter files: none yet
- Key elements: Top toast after confirming sign-out
- To build: Call the shared toast (PROV-C1) from the root navigator context after context.go(AppRoutes.splash).

### Provider Wallet (commission & settlement) — `PROV-34` (sub-screen, missing)
- How the user reaches it: Provider app -> Profile tab -> Wallet & settlement
- Prototype source: ui_kits/aiwa-app/provider-extras.jsx:8-82; ui_kits/aiwa-app/prototype.jsx:442
- Flutter files: none yet
- Key elements: Header back IconBtn, Eyebrow 'Commission & settlement', h2 'Wallet' DM Serif 22; Hero card gradient radius 20 padding 20 + radial overlay: Eyebrow rose300 'Wallet balance owed to AIWA', 'EGP 128.40' DM Serif 38; 6px progress bar (track rgba(255,255,255,.18), fill rose300) = balance/limit; 'Negative limit EGP 500 — settle weekly to keep taking bookings.' 12 rose300; Two paper tiles: 'Next settlement' 'Sun, May 24' DM Serif 18 | 'Status' StatusPill (confirmed); SectionHeader 'Ledger'; rows paper radius 14 padding 12: 34 tile (settlement success100/success700 check, else plum100/plum700 banknote), label 13.5/600, when 11.5 ink3, amount DM Serif 15 ('+' success700 / '−' plum900); Primary full lg banknote 'Settle balance now'
- To build: Route /provider/wallet pushed from Profile. GET /provider/settlement and PATCH /provider/settlement/pay (aiwa-backend SettlementController.java:35,44); add both to ApiConstants and create a WalletBloc. Reuse ScreenHeader, AppTheme.heroGradient + AiwaGlow, LinearProgressIndicator (minHeight 6, radius 4), StatusPill, SectionHeader. The prototype's settle button has no handler; wire it to PATCH /pay with a confirm sheet.

### Wallet — blocked (over negative limit) state — `PROV-35` (state, missing)
- How the user reaches it: Provider app -> Profile -> Wallet (balance <= limit)
- Prototype source: ui_kits/aiwa-app/provider-extras.jsx:16-19,35,40-45,54
- Flutter files: none yet
- Key elements: Progress fill switches to danger500; danger InlineBanner ban 'Blocked from new bookings' — "You can still finish any job you've already accepted — completing those and settling this balance lifts the block automatically."; Status tile StatusPill 'cancelled'
- To build: Derive overLimit from the settlement payload (balance <= negativeLimit). InlineBanner(tone: BannerTone.danger, icon: Icons.block). Also consider reflecting it on Today (PROVIDER_NOTIFICATIONS pn1 'Settlement overdue').

### Business info (edit) screen with validation — `PROV-36` (sub-screen, missing)
- How the user reaches it: Provider app -> Profile tab -> Business info
- Prototype source: ui_kits/aiwa-app/provider-manage.jsx:9-66; ui_kits/aiwa-app/prototype.jsx:443
- Flutter files: none yet
- Key elements: ScreenHeader eyebrow 'Provider' title 'Business info'; ValidatedInput 'Business name' (store icon; error 'Business name is required.' when < 2 chars); 'Short bio' multiline, maxLength 220 with counter, hint 'Shown at the top of your public profile.'; 'Primary category' chips Hair / Nails / Spa / Makeup / Lashes / Skin / Massage; 'Base address' (map-pin; error 'Add the area so customers can find you.'); Service radius slider 1–25 km (JetBrains Mono value plum700; '1 km' / '25 km' labels); 'Home-visit surcharge (EGP)' · optional, car icon, hint text; StickyBar: Cancel secondary lg + 'Save changes' primary lg (opacity .45 until valid && dirty)
- To build: Route /provider/business-info. PUT /provider/profile (ApiConstants.myProviderProfile; backend ProviderController.java:79). Prefill from GET /providers/{id}. Reuse AiwaTextField (error/counter/multiline support not verified), AiwaChip, the theme Slider (app_theme.dart:207-212), InlineBanner, StickyBar. The onboarding provider_business_page.dart already has category/address inputs worth extracting. On save: toast (PROV-38) + pop.

### Business info — re-review notice banner — `PROV-37` (banner, missing)
- How the user reaches it: Provider app -> Profile -> Business info (above the sticky bar)
- Prototype source: ui_kits/aiwa-app/provider-manage.jsx:55-56
- Flutter files: none yet
- Key elements: info InlineBanner, badge-check icon, title 'Verified studio', body 'Changing your business name or address sends your profile for a quick re-review.'
- To build: `InlineBanner(tone: BannerTone.info, icon: Icons.verified_outlined, title: 'Verified studio', body: 'Changing your business name or address sends your profile for a quick re-review.')` with 14px bottom margin. If the backend flips verificationStatus on save, refresh the AuthBloc user.

### Toast 'Business info saved.' — `PROV-38` (toast, missing)
- How the user reaches it: Provider app -> Profile -> Business info -> Save changes
- Prototype source: ui_kits/aiwa-app/prototype.jsx:443
- Flutter files: none yet
- Key elements: Toast then pop() to Profile
- To build: Shared top toast + context.pop() after a successful PUT.

### Gallery manager (grid, cover badge, count, add tile) — `PROV-39` (sub-screen, missing)
- How the user reaches it: Provider app -> Profile tab -> Gallery
- Prototype source: ui_kits/aiwa-app/provider-manage.jsx:68-175; ui_kits/aiwa-app/prototype.jsx:444
- Flutter files: none yet
- Key elements: ScreenHeader eyebrow 'Provider' title 'Gallery' + Tag neutral '{n}/20'; Intro 13 ink3: 'Your best work, shown on your public profile. Drag to reorder — the first photo is your cover.'; Grid auto-fill minmax(96px,1fr) gap 9; square tiles radius 15 border; 'COVER' badge on the first visible photo (rgba(255,255,255,.92), plum700 9/700, radius 999); 24px x delete button rgba(42,19,32,.6) top-right; Dashed 1.5px divider 'Add' tile (plus 20, 11/600 plum700)
- To build: Route /provider/gallery. Backend: POST /provider/gallery (multipart), DELETE /provider/gallery, GET /provider/gallery/{providerId} (aiwa-backend GalleryController.java:23-69). Flutter ApiConstants.providerGallery is '/providers/$id/gallery' (api_constants.dart:26), which does not match the backend GET path, so verify. Needs image_picker (check pubspec). GridView with SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 120, mainAxisSpacing: 9, crossAxisSpacing: 9). A Tag widget does not exist in lib/shared/widgets, so add one (kit states.jsx:397-410). Drag-reorder is only in the copy, not implemented in the prototype.

### Gallery — upload progress card with cancel — `PROV-40` (state, missing)
- How the user reaches it: Provider app -> Gallery -> Add tile (or 'Upload first photo')
- Prototype source: ui_kits/aiwa-app/provider-manage.jsx:86-100,111-125
- Flutter files: none yet
- Key elements: Paper card radius 15 padding 13: image-up tile 32 plum100/plum700; 'Uploading photo…' 13/600; percent JetBrains Mono 11 ink3; x cancel; 5px progress bar (cream track, plum700 fill, 130ms linear); On completion the new tile is appended
- To build: Use Dio onSendProgress for the percentage and a CancelToken for the x button (ApiClient.post would need to expose these). LinearProgressIndicator(minHeight: 5, backgroundColor: AppColors.cream, color: AppColors.plum700).

### Gallery — moderation-hidden photo overlay + warning banner — `PROV-41` (state, missing)
- How the user reaches it: Provider app -> Gallery (a photo hidden by moderation)
- Prototype source: ui_kits/aiwa-app/provider-manage.jsx:74,135-142,162-166
- Flutter files: none yet
- Key elements: Tile overlay rgba(42,19,32,.72) with eye-off 17 rose300 + 'Hidden by moderation' 9.5 bone; No COVER badge on a hidden first tile; warn InlineBanner eye-off 'One photo is hidden' — "Our team hid a photo that didn't match your services. Replace it or contact support if you disagree."
- To build: The gallery item model needs hidden/hiddenReason from the backend (verify the GalleryController GET payload). Stack overlay on the tile plus InlineBanner(tone: BannerTone.warn, icon: Icons.visibility_off_outlined). Links to PROVIDER_NOTIFICATIONS pn2.

### Gallery — delete photo ConfirmSheet — `PROV-42` (sheet, missing)
- How the user reaches it: Provider app -> Gallery -> tile x button
- Prototype source: ui_kits/aiwa-app/provider-manage.jsx:169-172
- Flutter files: none yet
- Key elements: ConfirmSheet danger tone, icon trash-2, eyebrow 'Gallery', title 'Delete this photo?', confirm 'Delete'; Body "It's removed from your public profile straight away. This can't be undone."
- To build: `showConfirmSheet(context, eyebrow: 'Gallery', title: 'Delete this photo?', body: "It's removed from your public profile straight away. This can't be undone.", confirmLabel: 'Delete', icon: Icons.delete_outline_rounded)`, then DELETE /provider/gallery.

### Gallery — empty state — `PROV-43` (state, missing)
- How the user reaches it: Provider app -> Gallery (0 photos)
- Prototype source: ui_kits/aiwa-app/provider-manage.jsx:127-130
- Flutter files: none yet
- Key elements: EmptyState icon images, title 'No photos yet', body 'Profiles with photos get noticeably more bookings. Add a few examples of your work.', action 'Upload first photo'
- To build: `EmptyState(icon: Icons.photo_library_outlined, title: 'No photos yet', subtitle: ..., actionLabel: 'Upload first photo', onAction: _startUpload)` (empty_state.dart already matches the kit sizes).

### Provider Reviews screen (summary, distribution, filters, list) — `PROV-44` (sub-screen, missing)
- How the user reaches it: Provider app -> Profile tab -> Reviews
- Prototype source: ui_kits/aiwa-app/provider-manage.jsx:177-275; ui_kits/aiwa-app/prototype.jsx:445
- Flutter files: none yet
- Key elements: ScreenHeader 'Provider' / 'Reviews'; Summary card paper radius 18 padding 18: average DM Serif 38 plum900, Stars 13, '{n} reviews' 11 ink3; 5→1 distribution rows (mono 10.5 digit, 5px cream track with gold500 fill, count ink4); Filter chips (h-scroll): All / Needs reply / 5 star / 4 star; Review cards paper radius 18 padding 15: Avatar plum 38, author 13.5/600, 'service · when' 11 ink3, Stars 13, body 13.5 ink2 lh 1.55, neutral Tags, secondary sm 'Reply publicly' (reply icon); EndOfList '{n} reviews total'
- To build: Route /provider/reviews. GET /providers/{id}/reviews (ApiConstants.providerReviews). The backend ReviewDto has no reply field and ReviewController exposes no reply endpoint (only POST /reviews, GET /providers/{id}/reviews and admin moderation), so the backend needs reply support. Reuse StarRating, AiwaChip, EndOfList, AiwaAvatar and a new Tag widget. 'Needs reply' filters reviews without a reply.

### Reviews — reply composer (char count) and posted reply block — `PROV-45` (component, missing)
- How the user reaches it: Provider app -> Reviews -> 'Reply publicly'
- Prototype source: ui_kits/aiwa-app/provider-manage.jsx:187-198,246-268
- Flutter files: none yet
- Key elements: Textarea 74px, radius 13, 1.5px plum700 border, bone bg, placeholder 'Thank them, or explain what happened…', maxLength 280, autofocus; Counter JetBrains Mono 10.5 ink4 '{n}/280'; ghost sm 'Cancel'; primary sm 'Post reply' (opacity .45 until non-blank); Posted reply: plum100 radius 13 block, corner-down-right icon + 'YOUR REPLY' 11/700 .04em plum700 + text 12.5 plum700; Only one composer open at a time
- To build: Local state in the Reviews page (replyToId, TextEditingController). TextField(maxLength: 280, buildCounter: custom mono counter) with the focusedBorder from AppTheme.inputBorder(AppColors.plum700). Needs the backend reply endpoint (see PROV-44).

### Reviews — filter empty state — `PROV-46` (state, missing)
- How the user reaches it: Provider app -> Reviews -> a filter with no matches (e.g. Needs reply when all are answered)
- Prototype source: ui_kits/aiwa-app/provider-manage.jsx:228-229
- Flutter files: none yet
- Key elements: EmptyState compact, icon message-square, 'Nothing here', 'No reviews match this filter.'
- To build: `EmptyState(icon: Icons.chat_bubble_outline_rounded, title: 'Nothing here', subtitle: 'No reviews match this filter.', compact: true)`.

### Staff & availability (shop plan) — `PROV-47` (sub-screen, missing)
- How the user reaches it: Provider app -> Profile tab -> Staff & availability
- Prototype source: ui_kits/aiwa-app/flow-additions-v4.jsx:8-80; ui_kits/aiwa-app/prototype.jsx:446
- Flutter files: none yet
- Key elements: Header back IconBtn, Eyebrow 'Shop plan', h2 'Staff & availability' DM Serif 22, primary sm 'Add' (plus); Accordion cards paper radius 18 (first open by default): Avatar 44 verified, name DM Serif 17, role 12 ink3, chevron up/down; Expanded: Eyebrow 'Skills' + chips; 'Services & pricing' rows (13, price DM Serif plum900, divider); 'Weekly availability' rows (12.5; JetBrains Mono hours or 'Off'); secondary sm full pencil "Edit {name}'s schedule"
- To build: Route /provider/staff. GET /providers/{id}/staff, POST /provider/staff, PUT /provider/staff/{id} (aiwa-backend StaffController.java:26-53); add them to ApiConstants. Per-staff services/availability payload shape still needs verifying. Use an AnimatedSize accordion; reuse AiwaAvatar, AiwaChip, EyebrowLabel, AiwaButton. Onboarding already collects staff names (provider_business_page.dart:24-177).

### Business info — validation error / unsaved (Save disabled) state — `PROV-V03` (state, missing)
- How the user reaches it: Provider app -> Profile -> Business info -> clear Business name or Base address and blur (or open without editing)
- Prototype source: ui_kits/aiwa-app/provider-manage.jsx:18-23,29-31,40,59-63; ui_kits/aiwa-app/states.jsx:171-206
- Flutter files: none yet
- Key elements: ValidatedInput after blur: 1.5px danger500 border, leading icon turns danger500, trailing circle-alert 16 danger500 (states.jsx:189-199); Error line 11.5 danger700 with circle-alert 11: 'Business name is required.' (name < 2 chars) / 'Add the area so customers can find you.' (address < 4 chars); it replaces the 11.5 ink4 hint; Short bio counter JetBrains Mono 11 ink4 '{n}/220' (states.jsx:186); 'Save changes' primary lg at opacity .45 with pointerEvents none until `valid && dirty`, so a pristine form is also disabled (provider-manage.jsx:61)
- To build: Part of PROV-36. Use a Form with validators on onUserInteraction. AiwaTextField's support for errorText, prefix icon and counter was not verified; otherwise use TextFormField with errorBorder: AppTheme.inputBorder(AppColors.danger500) and a custom mono buildCounter. Track dirty via controller listeners. `AiwaButton(label: 'Save changes', size: AiwaButtonSize.lg, onPressed: valid && dirty ? _save : null)` gives the 0.45 disabled look.
