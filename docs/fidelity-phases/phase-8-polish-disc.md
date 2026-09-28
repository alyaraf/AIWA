# Polish backlog — disc (minor findings)

#### Home (greeting, search pill, hero promo, categories, trending, available now, bell) `DISC-01`
- **[MINOR · content] Search pill location label is 'Near me' instead of the area name** `DISC-01-F3`
  - Prototype: screens.jsx:89-90 `<Icon name="map-pin" size={14} />Maadi` (13px, w600, plum700)
  - Flutter now: home_page.dart:232 `'Near me'`
  - Fix: Show the resolved area or saved-address label (for example from reverse geocoding the Geolocator position, or the default address). Keep 'Near me' only as the fallback

#### Home (greeting, search pill, hero promo, categories, trending, available now, bell) `DISC-01`
- **[MINOR · content] Trending section action copy differs** `DISC-01-F4`
  - Prototype: screens.jsx:122 `<SectionHeader title="Trending near you" action="View map" />`
  - Flutter now: home_page.dart:371 `action: 'View all'` -> context.go(AppRoutes.search)
  - Fix: Use `action: 'View map'`, or confirm the copy change with design. The prototype has no map screen, so routing to Discover is acceptable

#### Home (greeting, search pill, hero promo, categories, trending, available now, bell) `DISC-01`
- **[MINOR · tokens] Hero glow and search-pill shadow use theme tokens instead of the prototype literals** `DISC-01-F5`
  - Prototype: screens.jsx:97 `radial-gradient(circle, rgba(231,186,182,.4) 0%, transparent 70%)` on a 180px circle (farthest-corner radius 127px x 70% = ~89px, i.e. it fades out at the circle edge) in fixed #E7BAB6; screens.jsx:84 pill shadow `0 2px 8px rgba(74,31,56,.06)` in fixed #4A1F38
  - Flutter now: home_page.dart:261-265 `AiwaGlow(size: 180, color: AppColors.rose300, opacity: 0.4)` = male #B5A898 / female #E6BAB0; its RadialGradient (screen_chrome.dart:446-448) reaches 0 at 90px, so the falloff already matches. home_page.dart:211 `AppColors.plum700.withOpacity(0.06)` = male #2E2A26 / female #6B3A3A
  - Fix: Only the colours differ. For literal parity use `const Color(0xFFE7BAB6)` for the hero glow and `const Color(0x0F4A1F38)` for the pill shadow; otherwise keep the gender-aware values and record them as intentional. Do not add `stops: [0, 0.7]` - that would shrink the glow to ~63px

#### Home (greeting, search pill, hero promo, categories, trending, available now, bell) `DISC-01`
- **[MINOR · tokens] Rating star is 12px with a 2px gap instead of 11px with a 3px gap** `DISC-01-F6`
  - Prototype: screens.jsx:139-141,161-163 `<svg width="11" height="11" ... fill={aiwa.gold500}>` inside `gap: 3`
  - Flutter now: provider_card.dart:282-283 `Icon(Icons.star_rounded, size: 12, ...)` + `SizedBox(width: 2)`
  - Fix: In RatingMeta, use `Icon(Icons.star_rounded, size: 11, color: AppColors.gold500), const SizedBox(width: 3)`

#### Home (greeting, search pill, hero promo, categories, trending, available now, bell) `DISC-01`
- **[MINOR · layout] Category tile horizontal padding is 4 instead of 8** `DISC-01-F7`
  - Prototype: screens.jsx:111 `padding: '12px 8px 10px'`
  - Flutter now: category_tile.dart:44 `EdgeInsets.fromLTRB(4, 12, 4, 10)`
  - Fix: Use `EdgeInsets.fromLTRB(8, 12, 8, 10)`. The label already has maxLines 1 with ellipsis

#### Home (greeting, search pill, hero promo, categories, trending, available now, bell) `DISC-01`
- **[MINOR · layout] Header gap between bell and avatar is 8 instead of 12** `DISC-01-F8`
  - Prototype: screens.jsx:71 header `gap: 12` (between headline, bell and avatar)
  - Flutter now: home_page.dart:176 `const SizedBox(width: 8)`
  - Fix: Change it to `SizedBox(width: 12)`

#### Home (greeting, search pill, hero promo, categories, trending, available now, bell) `DISC-01`
- **[MINOR · layout] Available-now price column spacing differs** `DISC-01-F9`
  - Prototype: screens.jsx:155 row `gap: 12`. screens.jsx:171-172 'From' eyebrow directly above the price with no spacer
  - Flutter now: provider_list_item.dart:82 `SizedBox(width: 8)` before the price and line 88 `SizedBox(height: 2)` between 'From' and the price
  - Fix: Use `SizedBox(width: 12)` and remove the 2px spacer

#### Home (greeting, search pill, hero promo, categories, trending, available now, bell) `DISC-01`
- **[MINOR · layout] Available now shows the whole page (20) plus 'Load more' instead of 4 rows** `DISC-01-F10`
  - Prototype: screens.jsx:154 `PROVIDERS.slice(0, 4).map(...)`, with no pagination control
  - Flutter now: home_page.dart:390-403 maps every `state.providers` item, and lines 415-426 add an 'Load more' ghost button
  - Fix: Render `state.providers.take(4)` and let users reach the full list through Discover. If the long list is wanted, confirm with design

#### Home (greeting, search pill, hero promo, categories, trending, available now, bell) `DISC-01`
- **[MINOR · interaction] Bell sends guests to the auth gate** `DISC-01-F11`
  - Prototype: prototype.jsx:659 `onNotifications={() => push('notifications')}` has no guest check
  - Flutter now: home_page.dart:170-172 `user != null ? context.push(AppRoutes.notifications) : context.push(AppRoutes.authGate)`
  - Fix: Either follow the prototype (open Notifications for guests with an empty or generic list) or keep the gate and record it as an intentional product decision

#### Home (greeting, search pill, hero promo, categories, trending, available now, bell) `DISC-01`
- **[MINOR · components] Category icon glyphs swapped** `DISC-01-F12`
  - Prototype: screens.jsx:22-29 Lucide 'scissors','hand','leaf','brush','eye','droplets','hand-heart','sparkles'
  - Flutter now: home_page.dart:41-48 content_cut, back_hand, spa_outlined (a lotus, not a leaf), brush, visibility, water_drop_outlined (one drop, not droplets), volunteer_activism_outlined, auto_awesome
  - Fix: For exact parity add a Lucide icon font package (for example lucide_icons) and use LucideIcons.leaf / droplets / handHeart. At minimum replace spa_outlined with Icons.eco_outlined for 'leaf'

#### Home (greeting, search pill, hero promo, categories, trending, available now, bell) `DISC-01`
- **[MINOR · layout] Available now meta items are 6px apart instead of 8px** `DISC-01-V2`
  - Prototype: screens.jsx:160 meta row `gap: 8` between rating, dot, distance and 'Open now' (the trending card at screens.jsx:138 uses gap 6)
  - Flutter now: RatingMeta (provider_card.dart:298-313) separates items only with MetaDot, whose margin is `EdgeInsets.symmetric(horizontal: 6)` (screen_chrome.dart:416), so every row gets 6px gaps
  - Fix: Add `final double gap` (default 6) to RatingMeta and apply it around each MetaDot; ProviderListItem passes `gap: 8`

#### Home (greeting, search pill, hero promo, categories, trending, available now, bell) `DISC-01`
- **[MINOR · responsive] Trending carousel has a fixed 196px height that clips at larger text sizes** `DISC-01-V3`
  - Prototype: screens.jsx:123-124 the trending row is a flex row whose height follows the card content
  - Flutter now: home_page.dart:374-375 `SizedBox(height: 196, child: ListView.separated(...))`. The card is ~187px at text scale 1.0 (1+110+10+12+2+18.7+6+14.4+12+1) and exceeds 196 from about text scale 1.2 (about 4.6px overflow at Android 'Largest', 1.3)
  - Fix: Replace the fixed-height ListView with `SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 22), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [...]))`, or scale the height with `MediaQuery.textScalerOf(context)`

#### Home (greeting, search pill, hero promo, categories, trending, available now, bell) `DISC-01`
- **[MINOR · interaction] Home fires the OS location permission dialog directly** `DISC-01-V4`
  - Prototype: prototype.jsx:614 'Browse as guest' goes straight to `reset('home')` with no prompt; signed-up customers see the in-app PermissionPrimingScreen first (prototype.jsx:657 case 'perm-location'); HomeScreen never asks for location
  - Flutter now: home_page.dart:66-69 `if (perm == LocationPermission.denied) { perm = await Geolocator.requestPermission(); }` runs on every Home load and pull-to-refresh, so guests get the OS dialog over Home without priming
  - Fix: In HomePage._loadData only call `Geolocator.checkPermission()` and use the default coordinates when denied; request the permission from the permission-priming screen (onboarding partition)

#### Discover (search, category chips, sort, result list) `DISC-02`
- **[MINOR · content] Eight category chips instead of five** `DISC-02-F3`
  - Prototype: prototype.jsx:177-181 has only All, Hair (scissors), Nails (hand), Spa (leaf), Lashes (eye)
  - Flutter now: search_page.dart:40-49 `_cats` also includes Makeup, Skin and Massage
  - Fix: Trim `_cats` to the five prototype chips, or confirm with design. Keeping 8 lets Home's Makeup/Skin/Massage tiles preselect a chip

#### Discover (search, category chips, sort, result list) `DISC-02`
- **[MINOR · layout] Search pill right inset, height and filter-button padding differ** `DISC-02-F4`
  - Prototype: prototype.jsx:158 pill `padding: '13px 18px'` (row height = the 30px filter button, so the pill is ~58px tall incl. border); prototype.jsx:169 filter button `padding: 6` (button edge 18px, icon 24px from the pill edge)
  - Flutter now: search_page.dart:186 `EdgeInsets.only(left: 18, right: 8)` with no vertical padding; height comes from the TextField `contentPadding: EdgeInsets.symmetric(vertical: 14)` (line 219), about 52px. search_page.dart:242 `EdgeInsets.all(7)` puts the button edge 8px and the icon 15px from the pill edge
  - Fix: In _buildSearchField use `padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13)` on the pill Container, `contentPadding: EdgeInsets.zero` on the TextField and `padding: const EdgeInsets.all(6)` on the filter AnimatedContainer

#### Discover (search, category chips, sort, result list) `DISC-02`
- **[MINOR · layout] Chip row bottom padding is 4 instead of 6** `DISC-02-F5`
  - Prototype: prototype.jsx:176 `padding: '14px 22px 6px'`
  - Flutter now: search_page.dart:267-272 `EdgeInsets.fromLTRB(AppTheme.gutter, 14, AppTheme.gutter, 4)` inside `SizedBox(height: 50)`
  - Fix: Change the bottom padding to 6 and the SizedBox height to 52

#### Discover (search, category chips, sort, result list) `DISC-02`
- **[MINOR · components] Filter icon glyph differs** `DISC-02-F6`
  - Prototype: prototype.jsx:172 `<Icon name="sliders-horizontal" size={18} />`
  - Flutter now: search_page.dart:250 `Icons.tune_rounded`
  - Fix: Use the Lucide 'sliders-horizontal' glyph if a Lucide package is adopted (see DISC-01-F12). Otherwise acceptable

#### Discover (search, category chips, sort, result list) `DISC-02`
- **[MINOR · tokens] Row rating star is 12px (shared RatingMeta)** `DISC-02-F7`
  - Prototype: prototype.jsx:221 `<svg width="11" height="11" ...>` with `gap: 3`
  - Flutter now: provider_card.dart:282-283 `size: 12` + `SizedBox(width: 2)`
  - Fix: Same fix as DISC-01-F6

#### Discover (search, category chips, sort, result list) `DISC-02`
- **[MINOR · interaction] 'Nearest' sort and distances use hard-coded Cairo coordinates** `DISC-02-F8`
  - Prototype: prototype.jsx:148 sorts by the provider's distance from the user
  - Flutter now: search_page.dart:60-66, 87-89, 102 always dispatch `HomeLoadEvent(lat: 30.0444, lng: 31.2357, ...)`, while Home resolves the real position with Geolocator (home_page.dart:61-84)
  - Fix: Share the resolved position between Home and Discover (for example cache it in a singleton or LocationCubit registered in injection_container.dart) and pass it in every HomeLoadEvent

#### Discover (search, category chips, sort, result list) `DISC-02`
- **[MINOR · layout] Result-row meta items are 6px apart instead of 8px** `DISC-02-V2`
  - Prototype: prototype.jsx:219 Discover row meta `gap: 8` between rating, dot, distance and 'Open'
  - Flutter now: provider_list_item.dart:73-77 -> RatingMeta, whose MetaDot margin is 6 (screen_chrome.dart:416)
  - Fix: Same change as DISC-01-V2: ProviderListItem passes `gap: 8` to RatingMeta

#### Discover (search, category chips, sort, result list) `DISC-02`
- **[MINOR · tokens] 'Discover' title carries -0.64px letter-spacing** `DISC-02-V3`
  - Prototype: prototype.jsx:154 `fontFamily: fontDisp, fontSize: 28, ... lineHeight: 1.05` with no letterSpacing (Saved at prototype.jsx:296 and Bookings at screens.jsx:508 are the same)
  - Flutter now: screen_chrome.dart:119 PageTitle `AppTextStyles.h1.copyWith(fontSize: 28, height: 1.05)` inherits h1 `letterSpacing: -0.02 * 32` = -0.64px (app_text_styles.dart:20)
  - Fix: Add `letterSpacing: 0` to the copyWith in PageTitle (fixes Discover, Saved and Bookings at once)

#### Discover (search, category chips, sort, result list) `DISC-02`
- **[MINOR · responsive] Category chip row has a fixed height that clips chips at any text scale above ~1.03** `DISC-02-V4`
  - Prototype: prototype.jsx:176 the chip row is a flex row with `padding: '14px 22px 6px'` and a content-driven height
  - Flutter now: search_page.dart:263-272 `SizedBox(height: 50)` with 14/4 vertical padding leaves 32px, while an AiwaChip is ~31.6px (7+7 padding, 13px x 1.2 text, 2px border; aiwa_chip.dart:42-62)
  - Fix: Replace it with `SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(22, 14, 22, 6), child: Row(children: [...chips with SizedBox(width: 8) between]))`

#### Discover - loading skeleton `DISC-03`
- **[MINOR · tokens] Shimmer highlight is paper white instead of the hover token, and the period is 1.5s instead of 1.25s** `DISC-03-F1`
  - Prototype: states.jsx:28-30 `linear-gradient(90deg, ${aiwa.cream} 0%, ${aiwa.hover} 50%, ${aiwa.cream} 100%)`, `aiwa-shimmer 1.25s linear infinite`. hover = male #EBE5DA / female #F8E8E3, which equals cream in both themes, so the prototype shimmer is effectively flat
  - Flutter now: loading_shimmer.dart:21-23 `Shimmer.fromColors(baseColor: AppColors.cream, highlightColor: AppColors.paper)` (#FFFFFF), using the shimmer package's default 1500ms period
  - Fix: `Shimmer.fromColors(baseColor: AppColors.cream, highlightColor: AppColors.hover, period: const Duration(milliseconds: 1250), ...)`, or keep white and record it as an intentional deviation

#### Discover - empty results `DISC-04`
- **[MINOR · interaction] EmptyState icon has no pop-in animation** `DISC-04-F3`
  - Prototype: states.jsx:95 `animation: 'aiwa-pop 320ms cubic-bezier(.32,.72,0,1)'` (scale .86 -> 1, opacity 0 -> 1)
  - Flutter now: empty_state.dart:60-65 draws a static circle
  - Fix: Wrap the circle: `TweenAnimationBuilder<double>(tween: Tween(begin: .86, end: 1), duration: AppTheme.dur3, curve: AppTheme.easeSoft, builder: (_, v, child) => Opacity(opacity: ((v - .86) / .14).clamp(0, 1), child: Transform.scale(scale: v, child: child)), child: circle)`

#### Discover - empty results `DISC-04`
- **[MINOR · components] Empty-results icon glyph differs** `DISC-04-V1`
  - Prototype: prototype.jsx:203 `<EmptyState icon="search-x" ...>` (magnifier with an x)
  - Flutter now: search_page.dart:397 `icon: Icons.search_off_rounded` (magnifier with a slash)
  - Fix: Use the Lucide search-x glyph once a Lucide icon package is adopted (see DISC-01-F12); acceptable otherwise

#### Discover - active filter chips `DISC-05`
- **[MINOR · layout] Chip wrap padding is inverted (8 top / 0 bottom instead of 0 top / 4 bottom)** `DISC-05-F1`
  - Prototype: prototype.jsx:184 `padding: '0 22px 4px'`
  - Flutter now: search_page.dart:295-300 `EdgeInsets.fromLTRB(AppTheme.gutter, 8, AppTheme.gutter, 0)`
  - Fix: Use `EdgeInsets.fromLTRB(AppTheme.gutter, 0, AppTheme.gutter, 4)`

#### Discover - active filter chips `DISC-05`
- **[MINOR · content] Two spaces before '×'** `DISC-05-F2`
  - Prototype: prototype.jsx:186,189 `★ {minRating.toFixed(1)}+ ×` and `Under EGP {maxPrice} ×` (one space)
  - Flutter now: search_page.dart:307,313 `'★ ${...}+  ×'` and `'Under EGP ${...}  ×'`
  - Fix: Use a single space: `'★ ${_minRating.toStringAsFixed(1)}+ ×'`

#### Discover - Filters bottom sheet (rating / price) `DISC-06`
- **[MINOR · tokens] Sheet shadow and scrim colours differ from the prototype literals** `DISC-06-F1`
  - Prototype: prototype.jsx:238 scrim `rgba(42,19,32,.45)` (#2A1320). prototype.jsx:244 `boxShadow: '0 -12px 32px rgba(0,0,0,.18)'`
  - Flutter now: search_page.dart:451 `AppColors.plum900.withOpacity(0.45)` gives male #2E2A26. app_theme.dart:44-50 sheetDecoration `AppColors.plum700.withOpacity(0.14)`, blur 32, offset (0,-12)
  - Fix: In app_theme.dart sheetDecoration use `BoxShadow(color: Colors.black.withOpacity(.18), blurRadius: 32, offset: Offset(0, -12))`. Optionally use barrierColor `const Color(0x732A1320)`

#### Discover - Filters bottom sheet (rating / price) `DISC-06`
- **[MINOR · layout] Bottom padding and slider vertical rhythm differ** `DISC-06-F2`
  - Prototype: prototype.jsx:244 `padding: '18px 22px 36px'`; prototype.jsx:254 header `marginBottom: 8`; prototype.jsx:261,272 range labels `marginTop: 4`
  - Flutter now: search_page.dart:467-472 bottom `24 + safe-area`. Lines 508-521 and 523-534 put the Slider directly under _SliderHeader with no 8/4 spacers, and the Material Slider adds its own ~24px vertical padding
  - Fix: Add `SizedBox(height: 8)` before and `SizedBox(height: 4)` after each Slider, and remove the Slider's intrinsic padding (`Slider(padding: EdgeInsets.zero, ...)` on Flutter >= 3.24, or SliderTheme overlayShape: RoundSliderOverlayShape(overlayRadius: 0)). Set bottom padding to `36 + safe-area - 34` or simply 36

#### Discover - Filters bottom sheet (rating / price) `DISC-06`
- **[MINOR · interaction] Open/close animation uses Flutter defaults** `DISC-06-F3`
  - Prototype: prototype.jsx:240,245 scrim `aiwa-fade-in 220ms`, sheet `aiwa-slide-in 320ms cubic-bezier(.32,.72,0,1)`
  - Flutter now: search_page.dart:448-453 showModalBottomSheet without an animation style
  - Fix: Pass `sheetAnimationStyle: AnimationStyle(duration: AppTheme.dur3, curve: AppTheme.easeSoft)` (Flutter >= 3.22)

#### Provider profile (cover, bio, action chips, tab bar, sticky Book CTA) `DISC-08`
- **[MINOR · tokens] Cover rating star uses gold300 instead of gold500** `DISC-08-F4`
  - Prototype: screens.jsx:205 `<svg width="13" ... fill={aiwa.gold500} stroke={aiwa.gold500}>` gives male #5C544D / female #C4837A (base #B58A4E)
  - Flutter now: provider_detail_page.dart:280-281 `icon: Icons.star_rounded, iconColor: AppColors.gold300` gives male #B5A898 / female #E6BAB0
  - Fix: Use `iconColor: AppColors.gold500`. Check contrast on the male charcoal cover with design first; gold300 may be an intentional legibility fix

#### Provider profile (cover, bio, action chips, tab bar, sticky Book CTA) `DISC-08`
- **[MINOR · content] Location meta shows the full address instead of 'distance · area'** `DISC-08-F5`
  - Prototype: screens.jsx:209 `<Icon name="map-pin" size={12} /> {p.distance} · Maadi`
  - Flutter now: provider_detail_page.dart:287-293 `_CoverMeta(icon: Icons.location_on_outlined, text: p.address!)`, icon size 13 (line 571). The detail entity has no distance
  - Fix: Pass `distanceKm` (from the list item via `extra`, or from the API) and render `'${distanceText} · ${area}'` with a 12px icon

#### Provider profile (cover, bio, action chips, tab bar, sticky Book CTA) `DISC-08`
- **[MINOR · layout] Cover meta spacing and tab gap differ** `DISC-08-F6`
  - Prototype: screens.jsx:203 meta `columnGap: 10, rowGap: 4` (10px on each side of the 3px dot). screens.jsx:233 tabs `gap: 6`, and buttons use default line-height (about 40px tall)
  - Flutter now: provider_detail_page.dart:275-278 Wrap has no `spacing`; MetaDot margin is 6 on each side (screen_chrome.dart:416). Tabs Row of Expanded without gaps (607-636), label height 1 (AppTextStyles.label), about 38px tall
  - Fix: `Wrap(spacing: 10, runSpacing: 4, ...)` with `MetaDot` margin zero in this context. In _Tabs, add `SizedBox(width: 6)` between Expanded children and `height: 1.3` on the label

#### Provider profile (cover, bio, action chips, tab bar, sticky Book CTA) `DISC-08`
- **[MINOR · responsive] Cover height grows by half the safe-area inset** `DISC-08-F7`
  - Prototype: screens.jsx:191 `height: 280` (includes the status bar; the top buttons sit at top: 60)
  - Flutter now: provider_detail_page.dart:178 `280 + MediaQuery.paddingOf(context).top * 0.5` gives about 303px on a 47px notch
  - Fix: Use `double get _coverHeight => 280;`. The top buttons are already offset by `top + 12`

#### Provider profile (cover, bio, action chips, tab bar, sticky Book CTA) `DISC-08`
- **[MINOR · tokens] Provider name inherits h1 letter-spacing** `DISC-08-F8`
  - Prototype: screens.jsx:202 `fontFamily: fontDisp, fontSize: 32, margin: '4px 0 6px', lineHeight: 1.05` (no letterSpacing)
  - Flutter now: provider_detail_page.dart:268-272 `AppTextStyles.h1.copyWith(color: AppColors.bone, fontSize: 32, height: 1.05)`; h1 carries `letterSpacing: -0.02 * 32` (app_text_styles.dart:16-21)
  - Fix: Add `letterSpacing: 0` to the copyWith

#### Provider profile (cover, bio, action chips, tab bar, sticky Book CTA) `DISC-08`
- **[MINOR · tokens] Cover glows are theme-mapped and smaller than the prototype's** `DISC-08-F9`
  - Prototype: screens.jsx:192 `radial-gradient(circle at 25% 30%, rgba(231,186,182,.4), transparent 50%), radial-gradient(circle at 80% 70%, rgba(216,185,138,.25), transparent 60%)`. With farthest-corner sizing on a ~390x280 cover, the rose glow is centred at ~(98,84) and fades out at ~176px, and the gold glow is centred at ~(312,196) and fades out at ~221px, in fixed #E7BAB6 / #D8B98A
  - Flutter now: provider_card.dart:205-223 two `AiwaGlow(size: 280)` (radius 140) at left -60/top -20 (centre ~(80,120)) and right -80/bottom -60 (centre ~(330,200)); colours AppColors.rose300 / gold300 = male #B5A898 for both, female #E6BAB0 for both
  - Fix: For parity, size the glows from the cover box with a LayoutBuilder: rose glow diameter ~0.9 x width centred at (25%,30%), gold glow diameter ~1.13 x width centred at (80%,70%), colours `const Color(0xFFE7BAB6)` @ .4 and `const Color(0xFFD8B98A)` @ .25. Do not add RadialGradient stops to AiwaGlow (its gradient already reaches 0 at the edge, screen_chrome.dart:446-448). Keeping the theme-aware colours is acceptable if recorded as intentional

#### Provider profile (cover, bio, action chips, tab bar, sticky Book CTA) `DISC-08`
- **[MINOR · content] Bio fallback copy differs** `DISC-08-F10`
  - Prototype: screens.jsx:223 "Top-rated provider in your area. Read more about the studio, services, and recent reviews."
  - Flutter now: provider_detail_page.dart:330 'Top-rated provider in your area. Browse the services, recent reviews and gallery below.'
  - Fix: Use the prototype string

#### Provider profile (cover, bio, action chips, tab bar, sticky Book CTA) `DISC-08`
- **[MINOR · components] WhatsApp chip glyph differs** `DISC-08-F11`
  - Prototype: screens.jsx:227 `<Chip icon="message-circle">WhatsApp</Chip>`
  - Flutter now: provider_detail_page.dart:347 `Icons.chat_bubble_outline_rounded`
  - Fix: Use the Lucide 'message-circle' (round bubble). A close Material alternative is Icons.mode_comment_outlined

#### Provider profile (cover, bio, action chips, tab bar, sticky Book CTA) `DISC-08`
- **[MINOR · interaction] 'Book now' CTA does not preselect the first service** `DISC-08-F12`
  - Prototype: screens.jsx:320 `onClick={() => onBook(services[0])}`
  - Flutter now: provider_detail_page.dart:170 `onPressed: p.services.any((s) => s.available) ? _book : null` (no service)
  - Fix: `onPressed: ... ? () => _book(service: p.services.firstWhere((s) => s.available)) : null`

#### Provider profile (cover, bio, action chips, tab bar, sticky Book CTA) `DISC-08`
- **[MINOR · interaction] Push transition is the platform default instead of the 8% slide-in** `DISC-08-F13`
  - Prototype: prototype.jsx:730 `animation: aiwa-slide-in 320ms cubic-bezier(.32,.72,0,1)`; prototype.html:16-19 `from { transform: translateX(8%) }`
  - Flutter now: app_router.dart:180-186 `GoRoute(path: '/provider/:id', builder: ...)` uses the default MaterialPage transition; no pageTransitionsTheme in app_theme.dart
  - Fix: Use `pageBuilder: (c, s) => CustomTransitionPage(child: ProviderDetailPage(...), transitionDuration: AppTheme.dur3, transitionsBuilder: (_, a, __, child) => SlideTransition(position: Tween(begin: const Offset(.08, 0), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: AppTheme.easeSoft)), child: child))`, or apply it app-wide in one helper

#### Provider profile (cover, bio, action chips, tab bar, sticky Book CTA) `DISC-08`
- **[MINOR · tokens] Sticky CTA price line-height is 1.1 instead of 1** `DISC-08-V3`
  - Prototype: screens.jsx:318 `fontFamily: fontDisp, fontSize: 22, color: aiwa.plum900, lineHeight: 1`
  - Flutter now: provider_detail_page.dart:161 `AppTextStyles.price.copyWith(height: 1.1)`; price is already 22 / height 1 (app_text_styles.dart:64-69)
  - Fix: Use `style: AppTextStyles.price` without the copyWith

#### Provider profile - Services tab `DISC-09`
- **[MINOR · content] Extra description line not in the prototype** `DISC-09-F2`
  - Prototype: screens.jsx:250-257 shows only the name and the meta row
  - Flutter now: provider_detail_page.dart:670-680 adds `service.description` (up to 2 lines, 12px)
  - Fix: Remove it, or confirm the addition with design

#### Provider profile - Services tab `DISC-09`
- **[MINOR · layout] Name-to-meta spacing is 3 instead of 2** `DISC-09-F3`
  - Prototype: screens.jsx:252 `marginTop: 2`
  - Flutter now: provider_detail_page.dart:681 `const SizedBox(height: 3)`
  - Fix: Use `SizedBox(height: 2)`

#### Provider profile - Services tab `DISC-09`
- **[MINOR · interaction] Plus button has no press feedback** `DISC-09-F4`
  - Prototype: prototype.html:41-42 `button:active:not(:disabled) { transform: scale(.96); }` (120ms)
  - Flutter now: provider_detail_page.dart:710-728 plain GestureDetector + Container
  - Fix: Wrap it in an AnimatedScale driven by onTapDown/onTapUp (as AiwaButton does, aiwa_button.dart:114-123), or reuse AiwaIconButton with an outlined variant

#### Provider profile - Services tab `DISC-09`
- **[MINOR · states] Service availability is parsed from a key the backend does not send** `DISC-09-V1`
  - Prototype: screens.jsx:248-266 every listed service is bookable (no unavailable state)
  - Flutter now: provider_detail_model.dart:91 `available: json['available'] as bool? ?? true`, but ServiceDto sends `active` (ApiResponse.java:185), so inactive services render as bookable and the dimmed 'Unavailable' state (provider_detail_page.dart:688-698, 712-713) never triggers
  - Fix: `available: json['active'] as bool? ?? json['available'] as bool? ?? true`, or leave inactive services out of the public profile on the server; parse `pricingType` in the same place for DISC-09-F1

#### Provider profile - Reviews tab `DISC-10`
- **[MINOR · layout] Extra 3px gap between the name row and the stars** `DISC-10-F1`
  - Prototype: screens.jsx:283-287 the header div is followed directly by `<Stars value={r.rating} size={11} />`
  - Flutter now: provider_detail_page.dart:768 `const SizedBox(height: 3)`
  - Fix: Remove the spacer

#### Provider profile - Reviews tab `DISC-10`
- **[MINOR · components] Empty stars use a divider-coloured outline icon instead of an ink4 stroke** `DISC-10-F2`
  - Prototype: components.jsx:180 unfilled star `fill='none' stroke={aiwa.ink4} strokeWidth="2"`; there are no half stars
  - Flutter now: star_rating.dart:27,29-35 `Icons.star_outline_rounded` coloured `AppColors.divider`, plus `star_half_rounded` for .5 values
  - Fix: Use `inactiveColor ?? AppColors.ink4`, and round `value` for review rows if half stars are not wanted

#### Provider profile - Reviews tab `DISC-10`
- **[MINOR · tokens] 38px summary rating carries -0.96px letter-spacing** `DISC-10-V2`
  - Prototype: screens.jsx:273 `fontFamily: fontDisp, fontSize: 38, color: aiwa.plum900, lineHeight: 1` (no letterSpacing)
  - Flutter now: provider_detail_page.dart:411-414 `AppTextStyles.display.copyWith(fontSize: 38, height: 1)` keeps display's `letterSpacing: -0.02 * 48` = -0.96px (app_text_styles.dart:9-14)
  - Fix: Add `letterSpacing: 0` to the copyWith

#### AuthGateScreen ('Sign in to book.') `DISC-15`
- **[MINOR · layout] Top and bottom padding differ from the prototype** `DISC-15-F2`
  - Prototype: customer-extras-2.jsx:29 `padding: '70px 24px 32px'` (about 23px below a 47px status bar; 32px bottom)
  - Flutter now: step_header.dart:96 `EdgeInsets.fromLTRB(24, insets.top + 18, 24, 16)` and step_header.dart:114 bottom `16 + insets.bottom`
  - Fix: Use insets.top + 23 for this screen. The bottom is acceptable because the safe area is added

#### AuthGateScreen ('Sign in to book.') `DISC-15`
- **[MINOR · tokens] Title letter-spacing is computed for 32px** `DISC-15-F3`
  - Prototype: customer-extras-2.jsx:33 `fontSize: 30, lineHeight: 1.05, letterSpacing: '-0.02em'` = -0.6px
  - Flutter now: auth_gate_page.dart:53 `AppTextStyles.h1.copyWith(fontSize: 30, height: 1.05)`; h1 letterSpacing = -0.64 (app_text_styles.dart:20)
  - Fix: Add `letterSpacing: -0.6` to the copyWith (negligible visually)

#### Saved (favorites list) `DISC-16`
- **[MINOR · tokens] Tile gradient has 3 stops instead of plum500 -> plum900** `DISC-16-F2`
  - Prototype: prototype.jsx:309-310 `linear-gradient(135deg, ${aiwa.plum500}, ${aiwa.plum900})` + `radial-gradient(circle at 30% 30%, rgba(231,186,182,.35), transparent 55%)`
  - Flutter now: saved_page.dart:190-194 uses CoverImage (non-hero): colors [plum500, plum700, plum900], stops [0, .6, 1] and AiwaGlow(rose300) (provider_card.dart:193-229). In the male theme plum700 == plum900 (#2E2A26), so it darkens from 60% instead of blending across
  - Fix: Add an optional `List<Color>? colors` to CoverImage and pass `[AppColors.plum500, AppColors.plum900]` with stops [0, 1] from SavedPage

#### Saved (favorites list) `DISC-16`
- **[MINOR · tokens] Rating star is 13px with a 2px gap instead of 11 / 3** `DISC-16-F3`
  - Prototype: prototype.jsx:319-321 `<svg width="11" height="11" ...>` in `gap: 3`
  - Flutter now: saved_page.dart:221-226 `Icon(Icons.star_rounded, size: 13, ...)` + `SizedBox(width: 2)`
  - Fix: Use size 11 and `SizedBox(width: 3)`

#### Saved (favorites list) `DISC-16`
- **[MINOR · states] Unsave waits for the API and removes the item even if the call fails** `DISC-16-F4`
  - Prototype: prototype.jsx:329 removes instantly: `setSaved(s => s.filter(x => x.id !== p.id))`
  - Flutter now: saved_bloc.dart:53-67 `await _repository.removeProvider(...)`, then emits the filtered list regardless of the result, so the UI lags and can go out of sync with the server
  - Fix: Emit the filtered list first, then call the API and re-insert the provider (with a toast) if the result is a Left

#### Saved (favorites list) `DISC-16`
- **[MINOR · tokens] Saved title and tile initial carry negative letter-spacing; the initial's colour is theme-mapped** `DISC-16-V2`
  - Prototype: prototype.jsx:296 'Saved' 28px / lineHeight 1.05 with no letterSpacing; prototype.jsx:311 initial `fontFamily: fontDisp, fontSize: 48, color: 'rgba(250,245,238,.9)'` with no letterSpacing
  - Flutter now: saved_page.dart:80-84 PageTitle -> screen_chrome.dart:119 keeps -0.64px; provider_card.dart:234-238 `AppTextStyles.display.copyWith(fontSize: 48, color: AppColors.bone.withOpacity(0.9), height: 1)` keeps -0.96px, and the colour resolves to male #F5F2ED / female #FDF6F4 @ 90% instead of the fixed #FAF5EE
  - Fix: Set `letterSpacing: 0` in PageTitle (see DISC-02-V3) and in the CoverImage initial style; use `const Color(0xE6FAF5EE)` if the literal colour is wanted

#### Saved - empty state ('No favorites yet') `DISC-17`
- **[MINOR · interaction] 'Browse providers' opens Discover instead of a provider profile** `DISC-17-F1`
  - Prototype: prototype.jsx:302 `onAction={() => onProvider && onProvider(1)}`, which pushes 'provider' for the hardcoded demo provider #1
  - Flutter now: saved_page.dart:123 `onAction: () => context.go(AppRoutes.search)`
  - Fix: Keep Discover. The prototype target is a demo placeholder with a hardcoded id, which is why this is rated minor. Confirm with design and record the decision

#### GuestLockedScreen (shared guest gate for Bookings / Saved / Profile) `DISC-18`
- **[MINOR · tokens] Guest-locked title carries -0.26px letter-spacing** `DISC-18-V1`
  - Prototype: customer-extras-2.jsx:19 `fontFamily: fontDisp, fontSize: 24, color: aiwa.plum900, margin: '8px 0 8px', lineHeight: 1.1` (no letterSpacing)
  - Flutter now: guest_locked_view.dart:45 `AppTextStyles.h2.copyWith(fontSize: 24, height: 1.1)` keeps h2's `letterSpacing: -0.01 * 26` = -0.26px (app_text_styles.dart:23-28)
  - Fix: Add `letterSpacing: 0` to the copyWith

#### Bookings tab - guest locked variant `DISC-19`
- **[MINOR · content] Guest Bookings copy differs from the prototype** `DISC-19-F1`
  - Prototype: prototype.jsx:699 `title="See your bookings" body="Sign in to view and track your bookings."`
  - Flutter now: my_bookings_page.dart:40-42 `title: 'Your bookings live here'`, `body: 'Sign in to book providers, track them on the way, and see your history.'`
  - Fix: Use `title: 'See your bookings', body: 'Sign in to view and track your bookings.'`

#### Saved tab - guest locked variant `DISC-20`
- **[MINOR · content] Guest Saved copy differs from the prototype** `DISC-20-F1`
  - Prototype: prototype.jsx:707 `title="Save your favorites" body="Sign in to save providers you love and book them faster next time."`
  - Flutter now: saved_page.dart:37-39 `title: 'Keep your favorites'`, `body: 'Sign in to save providers and book them again in one tap.'`
  - Fix: Use the prototype title and body strings

#### Profile tab - guest locked variant `DISC-21`
- **[MINOR · content] Guest Profile copy differs from the prototype** `DISC-21-F1`
  - Prototype: prototype.jsx:710 `title="Your profile" body="Sign in to manage your account, addresses, and notifications."`
  - Flutter now: profile_page.dart:33-35 `title: 'Make AIWA yours'`, `body: 'Sign in to manage your details, notifications and bookings.'`
  - Fix: Use the prototype title and body strings

#### Customer bottom tab bar + onTabChange behaviour `DISC-22`
- **[MINOR · components] Bookings tab badge dot missing** `DISC-22-F1`
  - Prototype: components.jsx:207 `{ id: 'bookings', ..., badge: true }`; components.jsx:229 `<span style={{ position: 'absolute', top: -2, right: -4, width: 8, height: 8, background: aiwa.rose500, borderRadius: '50%', border: '2px solid #fff' }}/>`
  - Flutter now: shell_page.dart:122-156 _TabItem renders only Icon + Text, with no badge
  - Fix: Add `final bool badge` to _TabItem and wrap the icon: `Stack(clipBehavior: Clip.none, children: [Icon(...), if (badge) Positioned(top: -2, right: -4, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.rose500, shape: BoxShape.circle, border: Border.all(color: AppColors.paper, width: 2))))])`. Drive it from an upcoming-bookings or unread count

#### Customer bottom tab bar + onTabChange behaviour `DISC-22`
- **[MINOR · interaction] Tab switch has no fade/scale transition** `DISC-22-F2`
  - Prototype: prototype.jsx:567 `setDirection('back')` gives prototype.jsx:730 `aiwa-fade-in 320ms cubic-bezier(.32,.72,0,1)`; prototype.html:20-23 `from { transform: scale(.98) }`
  - Flutter now: app_router.dart:151-177 every tab uses `NoTransitionPage`
  - Fix: Replace NoTransitionPage with `CustomTransitionPage(child: ..., transitionDuration: AppTheme.dur3, transitionsBuilder: (_, a, __, c) => ScaleTransition(scale: Tween(begin: .98, end: 1.0).animate(CurvedAnimation(parent: a, curve: AppTheme.easeSoft)), child: c))`

#### Customer bottom tab bar + onTabChange behaviour `DISC-22`
- **[MINOR · interaction] Re-tapping the active tab re-navigates and can drop Discover's category** `DISC-22-F3`
  - Prototype: prototype.jsx:565 `if (t === tab) return;`
  - Flutter now: shell_page.dart:94 `onTap: () => context.go(tabs[i].$4)` runs even when active. On /app/search?category=HAIR this goes to /app/search, and didUpdateWidget resets `_activeCategory` and refetches (search_page.dart:70-76)
  - Fix: `onTap: i == index ? () {} : () => context.go(tabs[i].$4)`
