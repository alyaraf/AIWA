# Customer discovery: home, discover, provider profile, staff picker, flag, saved, guest gating

Generated from the AIWA prototype-fidelity audit. Paths: prototype = `C:/Users/alyar/Desktop/AIWA Design System (2)/design_handoff_aiwa_app/`, Flutter = `Android/aiwa_app/`.


## Entries

### Home (greeting, search pill, hero promo, categories, trending, available now, bell) — `DISC-01` (screen, deviates)
- How the user reaches it: Splash -> Browse as guest -> Home; or Sign in -> Home; or Tab bar -> Home
- Prototype source: ui_kits/aiwa-app/screens.jsx:67-179 (HomeScreen); prototype.jsx:659 (case 'home')
- Flutter files: Android/aiwa_app/lib/features/home/presentation/pages/home_page.dart, Android/aiwa_app/lib/features/home/presentation/widgets/category_tile.dart, Android/aiwa_app/lib/features/home/presentation/widgets/provider_card.dart, Android/aiwa_app/lib/features/home/presentation/widgets/provider_list_item.dart, Android/aiwa_app/lib/shared/widgets/section_header.dart, Android/aiwa_app/lib/shared/widgets/screen_chrome.dart
- Key elements: Eyebrow 'Good evening, Layla' + DM Serif 26 headline 'Who's making you / feel new tonight?'; IconBtn bell with rose dot -> notifications; Avatar 42 rose; Search pill: search icon, 'Service or provider', divider, map-pin 'Maadi'; Hero promo card: plum700->plum900 gradient, radial glow, eyebrow 'This week · 20% off', 'Bridal lookbook season', body, accent sm 'Explore →'; SectionHeader 'Categories' / 'See all' + 4x2 category tiles (44px tinted icon squares); SectionHeader 'Trending near you' / 'View map' + 200px carousel cards (Verified pill, glass heart 32, category eyebrow, name, star rating · distance); SectionHeader 'Available now' + row cards (avatar 52 verified, name, category, rating (reviews) · distance · 'Open now', 'From EGP n')
- Findings:
  - **[MAJOR · responsive] Category grid tiles overflow on 360dp and 375dp phones** `DISC-01-F1`
    - Prototype: screens.jsx:106,111 - CSS grid rows auto-size; tile `padding: '12px 8px 10px'`, 44px icon + gap 8 + 12px label, so height follows content
    - Flutter now: home_page.dart:331 `childAspectRatio: 0.86`. Tile content is 88px: padding 22 (category_tile.dart:44) + 2px border added by Container from `Border.all` (category_tile.dart:48) + 44 + 8 + 12 (labelSm height 1). At 360dp a tile is (360-44-30)/4 = 71.5 wide and 83.1 tall, a ~4.9px RenderFlex overflow; at 375dp it is 87.5 tall (~0.5px overflow); any text scale > 1 makes it worse
    - Fix: In home_page.dart replace GridView.count with `GridView(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), padding: EdgeInsets.zero, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 90), children: ...)`, or build two Rows of four Expanded tiles so the height follows content under text scaling
  - **[MAJOR · content] 'Open now' status is never shown on Available now rows** `DISC-01-F2`
    - Prototype: screens.jsx:167 `{p.openNow && (<>...<span style={{ color: aiwa.success700, fontWeight: 600 }}>Open now</span></>)}` (success700 = male #2E2A26 / female #6B3A3A)
    - Flutter now: provider_list_item.dart:73-77 calls `RatingMeta(rating:, reviews:, distance:)` without openNow. ProviderSummaryEntity/Model have no open field (provider_summary_entity.dart, provider_summary_model.dart:38-58), so the openNow branch in RatingMeta (provider_card.dart:302-313) never runs
    - Fix: Add `final bool openNow` to ProviderSummaryEntity/Model. The backend ProviderSummaryDto (aiwa-backend/src/main/java/com/aiwa/dto/response/ApiResponse.java:91-109) sends only `vacationMode`, `offlineMode` and `settlementPaused`. Either derive `openNow: !(json['vacationMode'] ?? false) && !(json['offlineMode'] ?? false) && !(json['settlementPaused'] ?? false)`, or add a real `openNow` (computed from today's availabilities) to the DTO. Then pass `openNow: provider.openNow` in ProviderListItem
  - **[MAJOR · content] 'From EGP' price column never renders on Available now rows** `DISC-01-V1`
    - Prototype: screens.jsx:170-173 every Available now row ends with `<Eyebrow style={{ fontSize: 9 }}>From</Eyebrow>` + `EGP {p.price}` (DM Serif 17, plum900, lineHeight 1)
    - Flutter now: provider_list_item.dart:83 `if (!discover && provider.startingPrice != null)`; provider_summary_model.dart:27-36 derives startingPrice only from `json['services']` or `json['startingPrice']`, and the backend ProviderSummaryDto (aiwa-backend/src/main/java/com/aiwa/dto/response/ApiResponse.java:91-109) sends neither, so startingPrice is always null and the price column is dropped (ProviderServiceImpl.java:115 notes 'price sort added when min-price is on ProviderSummaryDto')
    - Fix: Add `private BigDecimal startingPrice;` (the minimum active service price) to ProviderSummaryDto and set it in ProviderServiceImpl.toSummaryDto; the Flutter model already reads `json['startingPrice']`. Until then, keep the column and show a placeholder instead of omitting it

### Discover (search, category chips, sort, result list) — `DISC-02` (screen, deviates)
- How the user reaches it: Tab bar -> Discover; Home -> category tile -> Discover; Book Now check sheet -> 'See alternatives' -> Discover
- Prototype source: ui_kits/aiwa-app/prototype.jsx:129-233 (DiscoverScreen); prototype.jsx:660 (case 'discover')
- Flutter files: Android/aiwa_app/lib/features/home/presentation/pages/search_page.dart, Android/aiwa_app/lib/features/home/presentation/widgets/provider_list_item.dart, Android/aiwa_app/lib/features/home/presentation/bloc/home_bloc.dart, Android/aiwa_app/lib/shared/widgets/aiwa_chip.dart, Android/aiwa_app/lib/shared/widgets/screen_chrome.dart
- Key elements: Eyebrow 'Find someone new' + DM Serif 28 'Discover'; Search input 'Search providers, services, locations' with clear 'x' and sliders-horizontal filter button (filled plum700 when filters are active); Category chips: All, Hair (scissors), Nails (hand), Spa (leaf), Lashes (eye); Sort row: 'Sort' + Nearest / Top rated / Price chips + 'N found'; Result rows: avatar 56 verified, DM Serif 18 name, category, star rating · distance · 'Open', chevron-right; EndOfList '{n} providers in range'
- Findings:
  - **[MAJOR · interaction] Query and category chip are never applied together** `DISC-02-F1`
    - Prototype: prototype.jsx:139-145 filters one list by `cat`, rating, price and `query` together: `if (cat !== 'all' && p.cat.toLowerCase() !== cat) return false; ... if (query.trim() && ![p.name, p.category].some(...)) return false;`
    - Flutter now: search_page.dart:91 `_homeBloc.add(HomeSearchEvent(q.trim()))` sends no category, and home_bloc.dart:113-126 emits `selectedCategory: null` while the chip stays active (search_page.dart:277-278). Reverse direction: a chip tap with text in the field dispatches `HomeCategoryFilterEvent(_activeCategory)` (search_page.dart:283-286), which calls getNearbyProviders without the query (home_bloc.dart:89-111), so the typed text stays visible but is ignored
    - Fix: In `_apply` (search_page.dart:105) add `if (_activeCategory != null && p.primaryCategory != _activeCategory) return false;` plus a client-side text match on businessName/categoryLabel. In the chip onTap, when `_controller.text.trim().isNotEmpty` call `_onSearch(_controller.text)` instead of HomeCategoryFilterEvent, so both inputs always apply
  - **[MAJOR · content] 'Open' status missing on result rows** `DISC-02-F2`
    - Prototype: prototype.jsx:226 `{p.openNow && (<>...<span style={{ color: aiwa.success700, fontWeight: 600 }}>Open</span></>)}` (Discover says 'Open', not 'Open now')
    - Flutter now: provider_list_item.dart:73-77 passes no openNow, and ProviderSummaryEntity has no field for it
    - Fix: After adding openNow (see DISC-01-F2), add a label parameter: `RatingMeta(..., openNow: provider.openNow, openLabel: discover ? 'Open' : 'Open now')`
  - **[MAJOR · interaction] 'Price' sort and 'Max price' filter have no effect** `DISC-02-V1`
    - Prototype: prototype.jsx:142 `if (p.price > maxPrice) return false;` and prototype.jsx:147 `sort === 'Price'` sorts by `a.price - b.price`; the sheet button counts the filtered result (prototype.jsx:278)
    - Flutter now: search_page.dart:108-111 keeps every provider whose `startingPrice == null`, and search_page.dart:121-126 sorts nulls as `double.infinity`. startingPrice is always null (DISC-01-V1), so the Max price slider removes no one, 'Show N providers' never changes with it, and 'Price' leaves the order unchanged (the backend 'price' sort is also a rating placeholder, ProviderServiceImpl.java:114-115)
    - Fix: Expose startingPrice on ProviderSummaryDto (DISC-01-V1). Until then, hide the 'Price' sort chip and the Max price slider rather than showing controls that do nothing

### Discover - loading skeleton — `DISC-03` (state, deviates)
- How the user reaches it: Tab bar -> Discover (first 620ms), or type a query (380ms)
- Prototype source: ui_kits/aiwa-app/prototype.jsx:136-138,201; states.jsx:24-55 (Skeleton, SkeletonCard, SkeletonList)
- Flutter files: Android/aiwa_app/lib/features/home/presentation/pages/search_page.dart, Android/aiwa_app/lib/shared/widgets/loading_shimmer.dart
- Key elements: SkeletonList count 4 inside '14px 22px 0'; SkeletonCard: paper, radius 18, border divider, padding 14, 64x64 r16 block + 3 lines (62%/14, 40%/11, 78%/11, gap 8); Shimmer: linear-gradient cream -> hover -> cream, 320px, 1.25s linear infinite; 'N found' hidden while loading

### Discover - empty results — `DISC-04` (state, deviates)
- How the user reaches it: Discover -> type a query or pick a category/filter that returns 0 providers
- Prototype source: ui_kits/aiwa-app/prototype.jsx:202-208; states.jsx:80-107 (EmptyState)
- Flutter files: Android/aiwa_app/lib/features/home/presentation/pages/search_page.dart, Android/aiwa_app/lib/shared/widgets/empty_state.dart
- Key elements: search-x icon in a 64px plum100 circle (pop-in animation); Title: 'No match for “{query}”' or 'Nothing in this category nearby'; Body: 'Try a different spelling, or browse by category instead.' or 'No providers within your radius match these filters yet.'; Primary: 'Clear search & filters' (query or filters) or 'Widen my radius'; Secondary ghost sm: 'Notify me when someone joins'
- Findings:
  - **[MAJOR · components] 'Notify me when someone joins' secondary action missing** `DISC-04-F1`
    - Prototype: prototype.jsx:207 `secondary="Notify me when someone joins" onSecondary={() => {}}`, rendered by states.jsx:102 as `<Btn variant="ghost" full size="sm">`
    - Flutter now: search_page.dart:396-406 passes no `secondaryLabel`/`onSecondary`, although EmptyState supports them (empty_state.dart:15-16,99-108)
    - Fix: Add `secondaryLabel: 'Notify me when someone joins', onSecondary: _notifyMe` where `_notifyMe` calls a waitlist endpoint. Until that exists, show a SnackBar 'We'll let you know.'
  - **[MAJOR · content] 'Widen my radius' primary action missing; category-only case uses a different label** `DISC-04-F2`
    - Prototype: prototype.jsx:149,205 `filtersActive = minRating > 0 || maxPrice < 2500`; `action={filtersActive || query ? 'Clear search & filters' : 'Widen my radius'}`, so an action always shows, and a category-only empty result shows 'Widen my radius'
    - Flutter now: search_page.dart:392-405 `narrowed = q.isNotEmpty || _filtersActive || _activeCategory != null; actionLabel: narrowed ? 'Clear search & filters' : null`, so there is no button when nothing is narrowed and category-only shows 'Clear search & filters'
    - Fix: `final cleared = q.isNotEmpty || _filtersActive; actionLabel: cleared ? 'Clear search & filters' : 'Widen my radius', onAction: cleared ? _clearAll : _widenRadius,` where `_widenRadius` reloads with a larger radiusKm. The prototype resets everything in both cases, so `_clearAll` is an acceptable minimum

### Discover - active filter chips — `DISC-05` (state, deviates)
- How the user reaches it: Discover -> filter button -> set a minimum rating or max price -> close the sheet
- Prototype source: ui_kits/aiwa-app/prototype.jsx:183-192
- Flutter files: Android/aiwa_app/lib/features/home/presentation/pages/search_page.dart
- Key elements: Wrap of tonal chips below the category row; '★ 4.0+ ×' clears the rating; 'Under EGP 1500 ×' clears the price

### Discover - Filters bottom sheet (rating / price) — `DISC-06` (sheet, deviates)
- How the user reaches it: Tab bar -> Discover -> sliders button in the search pill
- Prototype source: ui_kits/aiwa-app/prototype.jsx:235-282
- Flutter files: Android/aiwa_app/lib/features/home/presentation/pages/search_page.dart, Android/aiwa_app/lib/core/theme/app_theme.dart
- Key elements: Scrim rgba(42,19,32,.45) fade 220ms; sheet slides in over 320ms; Bone sheet, 24 top radius, padding 18/22/36, shadow 0 -12 32 rgba(0,0,0,.18), 40x4 handle; 'Filters' DM Serif 22 + 'Reset' 13 w600 plum700; 'Minimum rating' eyebrow + value ('Any' or 'x.x★') DM Serif 18; range 0-5 step .5; 'Any' / '5.0'; 'Max price' + 'EGP n'; range 100-2500 step 50; 'EGP 100' / 'EGP 2,500+'; Primary full lg 'Show N provider(s)'

### Discover - end-of-list footer — `DISC-07` (component, implemented)
- How the user reaches it: Discover -> scroll to the bottom of a non-empty result list
- Prototype source: ui_kits/aiwa-app/prototype.jsx:232; states.jsx:320-328 (EndOfList)
- Flutter files: Android/aiwa_app/lib/features/home/presentation/pages/search_page.dart, Android/aiwa_app/lib/shared/widgets/screen_chrome.dart
- Key elements: Hairline divider - '{n} providers in range' (11.5 ink4) - hairline divider; Padding 18/4/6, gap 10

### Provider profile (cover, bio, action chips, tab bar, sticky Book CTA) — `DISC-08` (screen, deviates)
- How the user reaches it: Home -> Trending card or Available now row -> Provider; Discover -> result row -> Provider; Saved -> card or 'Book again' -> Provider; Rejected -> alternative -> Provider
- Prototype source: ui_kits/aiwa-app/screens.jsx:184-244,314-321 (ProviderScreen); prototype.jsx:661-667 (case 'provider')
- Flutter files: Android/aiwa_app/lib/features/providers/presentation/pages/provider_detail_page.dart, Android/aiwa_app/lib/features/providers/presentation/bloc/provider_bloc.dart, Android/aiwa_app/lib/features/providers/domain/entities/provider_detail_entity.dart, Android/aiwa_app/lib/features/home/presentation/widgets/provider_card.dart, Android/aiwa_app/lib/core/router/app_router.dart
- Key elements: 280px cover: 160deg plum500->plum700->plum900 gradient + rose and gold radial glows; Glass back button; glass share-2 and heart at top right (gap 8); Eyebrow category (rose300), DM Serif 32 name, meta row: gold500 ★ rating (reviews) · map-pin '1.2 km · Maadi' · gold300 badge-check 'Verified'; Bone body card with 28 top radius overlapping by 24; bio 14 ink2; Chips: Call (phone), WhatsApp (message-circle), Directions (map), Report (flag) -> FlagProviderSheet; Tabs Services / Reviews / Gallery (14 w600, 2px plum700 underline); White sticky CTA: 'Starts at' eyebrow + 'EGP n' DM Serif 22 + primary lg 'Book now' (calendar-check)
- Findings:
  - **[CRITICAL · interaction] Report chip missing: the FlagProviderSheet flow cannot be reached** `DISC-08-F1`
    - Prototype: screens.jsx:229 `<Chip icon="flag" onClick={onFlag}>Report</Chip>`; prototype.jsx:667 `onFlag={() => setShowFlag(true)}` mounts FlagProviderSheet (prototype.jsx:742-750)
    - Flutter now: provider_detail_page.dart:334-361 chip Wrap has only Call, WhatsApp and Directions. The string 'Report' and any flag sheet are absent from lib/
    - Fix: Append to the Wrap: `AiwaChip(label: 'Report', icon: Icons.flag_outlined, onTap: () => showFlagProviderSheet(context, providerId: p.id, providerName: p.displayName))`. Build the sheet as described in DISC-12
  - **[CRITICAL · interaction] Book routing has no shop -> staff-picker branch and skips the booking-type step** `DISC-08-F2`
    - Prototype: prototype.jsx:661-667 `if (p?.type === 'shop') { push('staff-picker'); } else if (isGuest) { push('auth-gate'); } else { push('booking-type'); }` - the shop check runs before the guest check; used by both the CTA (screens.jsx:320) and each service '+' (screens.jsx:263)
    - Flutter now: provider_detail_page.dart:62-69 `if (!_isSignedIn) { context.push(AppRoutes.authGate); return; } ... context.push('/booking/${widget.providerId}$query');`. ProviderDetailEntity/Model have no provider type or staff (provider_detail_entity.dart, provider_detail_model.dart:49-69)
    - Fix: Map `providerType` ('INDIVIDUAL'/'SHOP') and `staffMembers` (id, fullName, title) in ProviderDetailModel. The backend already sends them in ProviderDetailDto (aiwa-backend .../dto/response/ApiResponse.java:125,135; staff also at GET /providers/{providerId}/staff, StaffController.java:26), so no backend change is needed. Then: `void _book({ServiceEntity? service}) { final q = service != null ? '?serviceId=${service.id}' : ''; if (p.providerType == 'SHOP') { context.push('/provider/${widget.providerId}/staff$q'); return; } if (!_isSignedIn) { context.push(AppRoutes.authGate, extra: '/booking/${widget.providerId}$q'); return; } context.push('/booking/${widget.providerId}$q'); }`. Route to a booking-type screen once it exists; there is none in lib/features/bookings/presentation/pages (booking partition)
  - **[MAJOR · components] Share button missing from the cover** `DISC-08-F3`
    - Prototype: screens.jsx:195-198 `<div style={{ display: 'flex', gap: 8 }}><IconBtn icon="share-2" variant="glass" /><IconBtn icon="heart" variant="glass" /></div>`
    - Flutter now: provider_detail_page.dart:237-254 Row(back, Spacer(), heart) has no share button
    - Fix: Insert `AiwaIconButton(icon: Icons.share_outlined, variant: AiwaIconButtonVariant.glass, onTap: _share), const SizedBox(width: 8),` before the heart. Implement `_share` with the share_plus package (not in pubspec.yaml; add it) or copy a deep link
  - **[CRITICAL · content] Provider detail model reads keys the backend does not send, so name, category, Verified and Call/WhatsApp/Directions disappear** `DISC-08-V1`
    - Prototype: screens.jsx:201-215 the cover shows the category eyebrow, a DM Serif 32 name, rating, 'distance · area' and Verified; screens.jsx:226-228 Call / WhatsApp / Directions chips are always shown
    - Flutter now: provider_detail_model.dart:28-30 `final user = json['user'] as Map<String, dynamic>? ?? json; final profile = json['providerProfile'] as Map<String, dynamic>? ?? {};` reads businessName/bio/address/latitude/longitude/verified from `profile` and fullName/phone from `user` (lines 45-65). GET /providers/{id} (ProviderController.java:56-63) returns a flat ProviderDetailDto: businessName, bio, address, latitude, longitude, primaryCategory, verificationStatus, and owner {fullName, phone, profileImageUrl} (ApiResponse.java:114-137). Result: displayName is '' (provider_detail_page.dart:267), categories [] hides the eyebrow (263), isVerified is always false, phone '' hides Call and WhatsApp (338-351), and a null latitude hides Directions (352)
    - Fix: Rewrite ProviderDetailModel.fromJson for the flat DTO: `final owner = json['owner'] as Map<String, dynamic>? ?? const {};` then `providerName: owner['fullName'] ?? ''`, `businessName: json['businessName']`, `bio: json['bio']`, `address: json['address']`, `latitude: (json['latitude'] as num?)?.toDouble()`, `phone: owner['phone'] ?? ''`, `profileImageUrl: owner['profileImageUrl']`, `categories: [if (json['primaryCategory'] != null) json['primaryCategory'] as String]`, `isVerified: json['verificationStatus'] == 'APPROVED'`. Add a model test using a real response fixture
  - **[CRITICAL · interaction] Save heart calls endpoints that do not exist, so saving never persists** `DISC-08-V2`
    - Prototype: screens.jsx:197 cover `<IconBtn icon="heart" variant="glass" />`; prototype.jsx:290-337 Saved lists the providers the user has hearted
    - Flutter now: provider_remote_datasource.dart:67 `_api.post(ApiConstants.savedProviders, data: {'providerId': providerId})` sends POST /users/me/saved, but SavedController.java:48 maps only `@PostMapping("/{providerId}")`, so the call gets a 405. provider_remote_datasource.dart:78 checks GET /users/me/saved/{id}, but only GET /{providerId}/check exists (SavedController.java:80; ApiConstants.checkSaved at api_constants.dart:62 is unused), so isSaved is always false on open. ProviderBloc._onToggleSave (provider_bloc.dart:53-66) ignores the Either and flips `isSaved` anyway, so the cover heart fills without saving; SaveHeartButton (provider_card.dart:150-159) rolls back, so the trending heart springs back empty
    - Fix: In ProviderRemoteDataSourceImpl use `_api.post('${ApiConstants.savedProviders}/$providerId')` to save and `_api.get(ApiConstants.checkSaved(providerId))`, reading `response.data['data'] as bool`, to check. In _onToggleSave emit the optimistic value first and revert on Left. Also parse ProviderSummaryDto.saved (ApiResponse.java:104) and pass it as `initiallySaved` at provider_card.dart:86

### Provider profile - Services tab — `DISC-09` (tab, deviates)
- How the user reaches it: Provider profile -> Services tab (default)
- Prototype source: ui_kits/aiwa-app/screens.jsx:246-268
- Flutter files: Android/aiwa_app/lib/features/providers/presentation/pages/provider_detail_page.dart, Android/aiwa_app/lib/features/providers/domain/entities/provider_detail_entity.dart
- Key elements: Rows: name 15 w600; meta 12 ink3 'duration · Fixed price' or 'duration · Starts at'; Right: 'From' eyebrow 9 (non-fixed only) above 'EGP 1,200' DM Serif 18; 34px outlined plus button -> onBook(service); 16px vertical padding, divider between rows
- Findings:
  - **[MAJOR · content] Price-type label and 'From' eyebrow missing** `DISC-09-F1`
    - Prototype: screens.jsx:253-255 `<span>{s.duration}</span><dot/><span>{s.fixed ? 'Fixed price' : 'Starts at'}</span>`; screens.jsx:260 `{!s.fixed && <Eyebrow style={{ fontSize: 9, marginBottom: 2 }}>From</Eyebrow>}`
    - Flutter now: provider_detail_page.dart:682-700 meta row shows only `_duration(service.durationMinutes)` (plus 'Unavailable'); lines 705-708 show a bare price. ServiceEntity has no fixed-price flag (provider_detail_entity.dart:55-73)
    - Fix: Add `final bool fixedPrice;` to ServiceEntity and the model. Render `Text(_duration(...)), const MetaDot(), Text(service.fixedPrice ? 'Fixed price' : 'Starts at', style: AppTextStyles.micro.copyWith(fontSize: 12))`, and wrap the price in `Column(crossAxisAlignment: CrossAxisAlignment.end, children: [if (!service.fixedPrice) ...[const EyebrowLabel('From', fontSize: 9), const SizedBox(height: 2)], Text('EGP ${_money(service.price)}', ...)])`

### Provider profile - Reviews tab — `DISC-10` (tab, deviates)
- How the user reaches it: Provider profile -> Reviews tab
- Prototype source: ui_kits/aiwa-app/screens.jsx:270-293
- Flutter files: Android/aiwa_app/lib/features/providers/presentation/pages/provider_detail_page.dart, Android/aiwa_app/lib/shared/widgets/star_rating.dart
- Key elements: Cream summary card: DM Serif 38 rating + Stars + 'Based on N reviews'; Review rows: avatar 38, name 14 w600, time 11 ink3, Stars 11, text 13 ink2 lh1.55
- Findings:
  - **[CRITICAL · states] Reviews are never loaded, so the tab always shows 'No reviews yet'** `DISC-10-V1`
    - Prototype: screens.jsx:270-293 the Reviews tab shows the summary card and the review list (REVIEWS seed at screens.jsx:42-46)
    - Flutter now: provider_detail_model.dart:37-40 reads `json['reviews']`, which ProviderDetailDto does not contain (ApiResponse.java:114-137), and ProviderBloc._onLoad (provider_bloc.dart:32-51) never calls ProviderRepository.getProviderReviews (GET /providers/{id}/reviews, provider_remote_datasource.dart:40-51). provider_detail_page.dart:381-392 therefore always renders the 'No reviews yet' EmptyState, even when the cover shows e.g. '4.9 (312)'. ReviewSummaryModel also reads `json['customer']` (provider_detail_model.dart:108-113) while ReviewDto sends `user` (ApiResponse.java:276-286), so names would read 'Anonymous'
    - Fix: Add a GetProviderReviewsUseCase and fetch reviews in ProviderBloc._onLoad (or lazily on the first switch to the Reviews tab), storing them in ProviderLoaded. In ReviewSummaryModel read `final u = (json['user'] ?? json['customer'] ?? const {}) as Map<String, dynamic>;`

### Provider profile - Gallery tab — `DISC-11` (tab, implemented)
- How the user reaches it: Provider profile -> Gallery tab
- Prototype source: ui_kits/aiwa-app/screens.jsx:295-311
- Flutter files: Android/aiwa_app/lib/features/providers/presentation/pages/provider_detail_page.dart
- Key elements: 3-column grid, gap 6, square tiles, radius 12; Placeholder gradients + caption 'Placeholder gallery — replace with provider uploads' (a handoff note)

### FlagProviderSheet (report a provider) — `DISC-12` (sheet, missing)
- How the user reaches it: Provider profile -> 'Report' chip
- Prototype source: ui_kits/aiwa-app/customer-extras.jsx:432-491; mounted at prototype.jsx:742-750
- Flutter files: none yet
- Key elements: Scrim rgba(42,19,32,.45) + backdrop blur 2px; bone sheet, 24 radius, padding 18/22/36, 40x4 handle; Eyebrow rose700 'Flag {providerName}'; title DM Serif 22 'Tell us what's wrong'; Helper 12.5 ink3 'Flags are anonymous. Our team reviews every report and acts on the provider if confirmed.'; Six reason rows (13/14 padding, radius 12, 1.5px border; selected = plum100 background + plum700 border + check): Misleading profile or gallery / Inappropriate or unsafe behavior / Refused to honor agreed price / Identity feels suspicious / Spam or fake account / Other; 'Other' shows a 70px textarea 'Help us understand'; Cancel (secondary) + 'Submit flag' (danger), which requires a reason
- To build: Create lib/features/providers/presentation/widgets/flag_provider_sheet.dart exposing `Future<void> showFlagProviderSheet(BuildContext context, {required String providerId, required String providerName})`. Use showModalBottomSheet(isScrollControlled: true, backgroundColor: Colors.transparent, barrierColor: const Color(0x732A1320)), a Container with AppTheme.sheetDecoration and padding fromLTRB(22, 18, 22, 36 + viewInsets.bottom), and a StatefulBuilder holding `reason` and a TextEditingController. Follow the structure of shared/widgets/confirm_sheet.dart (handle, EyebrowLabel(color: AppColors.rose700), AppTextStyles.h3), build reason rows as GestureDetector + AnimatedContainer, and use AiwaTextField(maxLines: 3, placeholder: 'Help us understand') when reason == 'Other'. Put Row(Expanded(AiwaButton secondary 'Cancel'), SizedBox(10), Expanded(AiwaButton danger 'Submit flag', onPressed: reason == null ? null : submit)). Data: add `flagProvider(providerId, reason, note)` to ProviderRepository, ProviderRemoteDataSource and a use case, backed by a backend endpoint (for example POST /api/providers/{id}/flags; not visible in the Flutter code, verify in aiwa-backend). On success pop the sheet and show the DISC-13 toast. Open it from the new 'Report' chip (DISC-08-F1).

### Toast - 'Thanks — flag received. Our team reviews every report.' — `DISC-13` (toast, missing)
- How the user reaches it: Provider profile -> Report -> choose a reason -> Submit flag
- Prototype source: ui_kits/aiwa-app/prototype.jsx:746-749 (setToast); Toast at prototype.jsx:20-39
- Flutter files: none yet
- Key elements: Top-anchored (top 56, 16px sides), rgba(42,19,32,.96) background, radius 14, shadow 0 12 32; 26px success500 circle with a check + 13px w500 bone text; Slides down (aiwa-toast 320ms); auto-dismisses after 2800ms
- To build: No shared toast widget exists in lib/shared/widgets. The only equivalent is snackBarTheme (floating, plum900 @ .96, radius 14; app_theme.dart:185-193), which is bottom-anchored and has no check icon. Add lib/shared/widgets/aiwa_toast.dart with `void showAiwaToast(BuildContext context, String message)`: an OverlayEntry positioned at top: safeTop + 12, left/right 16; a Container with color Color(0xF52A1320) (or AppColors.plum900.withOpacity(.96)), radius 14 and a BoxShadow; a 26px circle in AppColors.success500 with Icons.check (15, white); a SlideTransition from Offset(0, -0.2) over 320ms easeSoft; removal after 2800ms. Call it with the prototype string once the flag API succeeds. The same helper serves every other setToast in the app.

### StaffPickerScreen ('Pick your stylist.' - shop-type providers) — `DISC-14` (screen, missing)
- How the user reaches it: Provider profile (shop-type, e.g. Layla Beauty or Maadi Hammam) -> 'Book now' or a service '+' -> Staff picker -> (guest) Auth gate or (signed in) Booking type
- Prototype source: ui_kits/aiwa-app/customer-extras-2.jsx:56-98; prototype.jsx:664,668-671
- Flutter files: none yet
- Key elements: Back IconBtn; eyebrow = provider name; DM Serif 28 'Pick your stylist.' (lh 1.05, -0.02em); Body 14 ink2 'This is a shop with multiple staff — your booking will be tied to whoever you pick.'; Staff cards: paper, 1.5px divider border, radius 18, padding 14, gap 14; Avatar 50 verified; DM Serif 18 name; 12 ink3 role; chevron-right 18; 'No preference' card: cream background, 1.5px dashed divider border, 50px plum100 circle with a shuffle icon, 'First available staff member'
- To build: Data first: ProviderDetailEntity and its model need `type` ('INDIVIDUAL'/'SHOP') and `List<StaffEntity> staff` (id, name, role, imageUrl). Staff names are already collected at signup (provider_business_page.dart:62-63), but the provider-detail API contract is not visible and needs backend exposure. Add GoRoute '/provider/:id/staff' (root navigator, outside the ShellRoute) -> StaffPickerPage(providerId, serviceId?). Reuse AuthStepScaffold (auth/presentation/widgets/step_header.dart:75) or ScreenHeader for the header, AiwaIconButton(Icons.arrow_back_rounded), EyebrowLabel, AppTextStyles.h1.copyWith(fontSize: 28, height: 1.05), and AiwaAvatar(size: 50, verified: true) plus Icons.chevron_right_rounded for rows. The dashed 'No preference' border needs a small CustomPainter (there is no dotted_border dependency in pubspec). Read staff from ProviderBloc state (pass the bloc or re-fetch). onPick(staffId or null): if not AuthAuthenticated, push AppRoutes.authGate with a return path; otherwise push '/booking/:id?serviceId=..&staffId=..'. BookingPage (booking partition) must accept staffId. Wire it from ProviderDetailPage._book (DISC-08-F2).

### AuthGateScreen ('Sign in to book.') — `DISC-15` (screen, deviates)
- How the user reaches it: Guest -> Provider profile -> Book now or service '+' (individual provider) -> Auth gate; Guest -> Staff picker -> pick -> Auth gate; Guest-locked tab -> 'Sign in or create account' (prototype)
- Prototype source: ui_kits/aiwa-app/customer-extras-2.jsx:27-54; prototype.jsx:665,669,672
- Flutter files: Android/aiwa_app/lib/features/auth/presentation/pages/auth_gate_page.dart, Android/aiwa_app/lib/features/auth/presentation/widgets/step_header.dart, Android/aiwa_app/lib/features/auth/presentation/pages/sign_in_page.dart, Android/aiwa_app/lib/features/auth/presentation/pages/avatar_gender_page.dart
- Key elements: Back IconBtn; Eyebrow rose700 'One quick step'; DM Serif 30 'Sign in to book.'; Body 14 ink2 'Browsing is open to everyone. Booking needs an account so providers can reach you.'; Three check perks (14px plum700 check, 13.5 ink2): 'Your booking history in one place', 'Live status + safety tracking', 'Save favorite providers'; Primary full lg 'Create account' + secondary full lg 'I already have an account', both of which continue to booking-type
- Findings:
  - **[CRITICAL · interaction] Signing in or creating an account from the gate does not resume the booking** `DISC-15-F1`
    - Prototype: prototype.jsx:672 `<AuthGateScreen onBack={pop} onContinue={() => { setIsGuest(false); push('booking-type'); }} />`; both buttons call onContinue (customer-extras-2.jsx:49-50)
    - Flutter now: auth_gate_page.dart:30-31 pushes AppRoutes.phoneEntry; line 39 pushes '/sign-in?role=CUSTOMER'. On success sign_in_page.dart:65-69 does `context.go(... AppRoutes.home)` and avatar_gender_page.dart:70-73 does the same, so the provider and service being booked are lost
    - Fix: Give AuthGatePage a `returnTo` (from `state.extra` or `?from=`) and forward it: `context.push('${AppRoutes.signIn}?role=CUSTOMER&from=${Uri.encodeComponent(returnTo)}')`. In the SignIn and AvatarGender listeners use `context.go(from ?? AppRoutes.home)`. Callers pass the target, for example `context.push(AppRoutes.authGate, extra: '/booking/42?serviceId=7')`

### Saved (favorites list) — `DISC-16` (screen, deviates)
- How the user reaches it: Tab bar -> Saved (signed in)
- Prototype source: ui_kits/aiwa-app/prototype.jsx:290-337 (SavedScreen); prototype.jsx:706-708 (case 'saved')
- Flutter files: Android/aiwa_app/lib/features/saved/presentation/pages/saved_page.dart, Android/aiwa_app/lib/features/saved/presentation/bloc/saved_bloc.dart, Android/aiwa_app/lib/features/home/presentation/widgets/provider_card.dart
- Key elements: Eyebrow 'Your favorites' + DM Serif 28 'Saved' (padding bottom 18); Cards: 110x110 gradient tile with a DM Serif 48 initial; category eyebrow 10; DM Serif 18 name; ★ rating; plum100 'Book again' pill (11.5 w700); Filled rose500 heart (20px, padding 14) removes the item; Card tap opens the provider; 'Book again' opens the provider (onRebook)
- Findings:
  - **[CRITICAL · interaction] 'Book again' jumps straight to the booking page instead of the provider profile** `DISC-16-F1`
    - Prototype: prototype.jsx:708 `onRebook={(id) => { setProviderId(id); push('provider'); }}`; the button is at prototype.jsx:323-326
    - Flutter now: saved_page.dart:149 `onBook: () => context.push('/booking/${p.id}')` bypasses the provider page, and with it service selection, the staff picker and booking-type
    - Fix: `onBook: () => context.push('/provider/${p.id}')`
  - **[CRITICAL · states] Saved list never loads: the page stays on the skeleton** `DISC-16-V1`
    - Prototype: prototype.jsx:291-334 Saved renders the favorites list, or the 'No favorites yet' EmptyState when it is empty
    - Flutter now: saved_remote_datasource.dart:24-32 passes `response.data['data']` to `PagedData.fromJson(Map<String, dynamic> json, ...)` (api_response.dart:43-58), but GET /users/me/saved returns a plain `List<ProviderSummaryDto>` (SavedController.java:31-46). The implicit cast throws a TypeError that SavedRepositoryImpl does not catch (it catches only ServerException/NetworkException, saved_repository_impl.dart:18-33), so SavedBloc stays in SavedLoading and saved_page.dart:108-113 shows the SkeletonList indefinitely. Neither the list nor the empty state can be reached
    - Fix: In SavedRemoteDataSourceImpl.getSavedProviders accept a list: `final data = response.data['data']; if (data is List) return PagedData(content: data.map((e) => ProviderSummaryModel.fromJson(e as Map<String, dynamic>)).toList(), totalElements: data.length, totalPages: 1, number: 0, size: data.length, last: true);`, otherwise use PagedData.fromJson. Add a catch-all -> Left(ServerFailure) in SavedRepositoryImpl so parse errors show ErrorState

### Saved - empty state ('No favorites yet') — `DISC-17` (state, deviates)
- How the user reaches it: Tab bar -> Saved with no saved providers (or after un-hearting all of them)
- Prototype source: ui_kits/aiwa-app/prototype.jsx:299-303; states.jsx:80-107
- Flutter files: Android/aiwa_app/lib/features/saved/presentation/pages/saved_page.dart, Android/aiwa_app/lib/shared/widgets/empty_state.dart
- Key elements: Rose-tone heart icon; 'No favorites yet'; 'Tap the heart on any provider to save them here and book again in one tap.'; Primary 'Browse providers'

### GuestLockedScreen (shared guest gate for Bookings / Saved / Profile) — `DISC-18` (component, deviates)
- How the user reaches it: Splash -> Browse as guest -> tap the Bookings, Saved or Profile tab
- Prototype source: ui_kits/aiwa-app/customer-extras-2.jsx:11-25
- Flutter files: Android/aiwa_app/lib/shared/widgets/guest_locked_view.dart
- Key elements: Vertically centred: 64px plum100 circle with a 28px icon; Eyebrow 'Browsing as guest'; DM Serif 24 title; 13.5 ink2 body (maxWidth 280); Bottom primary full lg 'Sign in or create account' -> push('auth-gate')
- Findings:
  - **[CRITICAL · interaction] CTA pushes /role-choice instead of the auth gate** `DISC-18-F1`
    - Prototype: prototype.jsx:699,707,710 `onSignIn={() => push('auth-gate')}`
    - Flutter now: guest_locked_view.dart:65 `onPressed: () => context.push(AppRoutes.roleChoice)`
    - Fix: `onPressed: () => context.push(AppRoutes.authGate)` (with a return path to the current tab once DISC-15-F1 is fixed)

### Bookings tab - guest locked variant — `DISC-19` (state, deviates)
- How the user reaches it: Splash -> Browse as guest -> Bookings tab
- Prototype source: ui_kits/aiwa-app/prototype.jsx:698-699
- Flutter files: Android/aiwa_app/lib/features/bookings/presentation/pages/my_bookings_page.dart, Android/aiwa_app/lib/shared/widgets/guest_locked_view.dart
- Key elements: Icon calendar-check; Title 'See your bookings'; Body 'Sign in to view and track your bookings.'; CTA 'Sign in or create account' -> auth-gate
- Findings:
  - **[CRITICAL · interaction] CTA goes to /role-choice instead of the auth gate (shared widget)** `DISC-19-F2`
    - Prototype: prototype.jsx:699 `onSignIn={() => push('auth-gate')}`
    - Flutter now: guest_locked_view.dart:65 `context.push(AppRoutes.roleChoice)`
    - Fix: Fix once in GuestLockedView (DISC-18-F1)

### Saved tab - guest locked variant — `DISC-20` (state, deviates)
- How the user reaches it: Splash -> Browse as guest -> Saved tab
- Prototype source: ui_kits/aiwa-app/prototype.jsx:706-707
- Flutter files: Android/aiwa_app/lib/features/saved/presentation/pages/saved_page.dart, Android/aiwa_app/lib/shared/widgets/guest_locked_view.dart
- Key elements: Icon heart; Title 'Save your favorites'; Body 'Sign in to save providers you love and book them faster next time.'; CTA -> auth-gate
- Findings:
  - **[CRITICAL · interaction] CTA goes to /role-choice instead of the auth gate (shared widget)** `DISC-20-F2`
    - Prototype: prototype.jsx:707 `onSignIn={() => push('auth-gate')}`
    - Flutter now: guest_locked_view.dart:65 `context.push(AppRoutes.roleChoice)`
    - Fix: Fix once in GuestLockedView (DISC-18-F1)

### Profile tab - guest locked variant — `DISC-21` (state, deviates)
- How the user reaches it: Splash -> Browse as guest -> Profile tab (or the Home avatar in Flutter)
- Prototype source: ui_kits/aiwa-app/prototype.jsx:709-710
- Flutter files: Android/aiwa_app/lib/features/profile/presentation/pages/profile_page.dart, Android/aiwa_app/lib/shared/widgets/guest_locked_view.dart
- Key elements: Icon user; Title 'Your profile'; Body 'Sign in to manage your account, addresses, and notifications.'; CTA -> auth-gate
- Findings:
  - **[CRITICAL · interaction] CTA goes to /role-choice instead of the auth gate (shared widget)** `DISC-21-F2`
    - Prototype: prototype.jsx:710 `onSignIn={() => push('auth-gate')}`
    - Flutter now: guest_locked_view.dart:65 `context.push(AppRoutes.roleChoice)`
    - Fix: Fix once in GuestLockedView (DISC-18-F1)

### Customer bottom tab bar + onTabChange behaviour — `DISC-22` (component, deviates)
- How the user reaches it: Any customer tab root (home, discover, bookings, saved, profile)
- Prototype source: ui_kits/aiwa-app/components.jsx:203-237 (TabBar); prototype.jsx:564-573 (onTabChange), 721, 736
- Flutter files: Android/aiwa_app/lib/features/shell/shell_page.dart, Android/aiwa_app/lib/core/router/app_router.dart
- Key elements: Tabs in order: Home (house), Discover (search), Bookings (calendar-check, rose badge dot), Saved (heart), Profile (user); Active tab: plum100 pill, plum700 icon and label; inactive: ink3; Re-tapping the active tab does nothing; switching tabs resets that tab's stack with a fade (scale .98 -> 1, 320ms); Hidden on pushed screens
