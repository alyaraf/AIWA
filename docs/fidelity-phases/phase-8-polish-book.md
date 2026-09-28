# Polish backlog — book (minor findings)

#### Booking screen - scheduled (date & slot picker + CTA) `BOOK-08`
- **[MINOR · layout] Day picker is a fixed-width horizontal scroller, not equal-width chips** `BOOK-08-F4`
  - Prototype: 5 days, each flex: 1, padding: '10px 6px', borderRadius: 14, number marginTop: 2 (screens.jsx:370-381)
  - Flutter now: ListView of 14 chips, width: 58, SizedBox(height: 70), gap SizedBox(height: 4) (booking_page.dart:55, 219-233, 510, 529)
  - Fix: Keep the 14-day horizon (BookingType copy says 'Up to 14 days out'). Size chips so 5 fill the row: width: (MediaQuery.sizeOf(context).width - 44 - 32) / 5, padding EdgeInsets.symmetric(vertical: 10, horizontal: 6), SizedBox(height: 2).

#### Booking screen - scheduled (date & slot picker + CTA) `BOOK-08`
- **[MINOR · components] Summary avatar ignores provider palette** `BOOK-08-F7`
  - Prototype: <Avatar name={p.name} palette={p.palette} size={44} verified={p.verified} /> (screens.jsx:359)
  - Flutter now: AiwaAvatar(name: provider.displayName, size: 44, verified: provider.isVerified, imageUrl: ...) with default plum palette (booking_page.dart:391-396)
  - Fix: Pass palette: AvatarPalette.values[provider.id.hashCode % 4] (the same rule everywhere a provider avatar is drawn).

#### Booking screen - scheduled (date & slot picker + CTA) `BOOK-08`
- **[MINOR · content] Duration rendered as raw minutes** `BOOK-08-F8`
  - Prototype: '{service?.name} · {service?.duration}', e.g. '2h 30min' (screens.jsx:362, 36)
  - Flutter now: '${service!.name} · ${service!.durationMinutes} min' renders '150 min' (booking_page.dart:410-412)
  - Fix: String fmt(int m) => m < 60 ? '$m min' : '${m ~/ 60}h${m % 60 > 0 ? ' ${m % 60}min' : ''}';

#### Booking screen - scheduled (date & slot picker + CTA) `BOOK-08`
- **[MINOR · states] No default day/slot selection** `BOOK-08-F9`
  - Prototype: React.useState(1) day and React.useState('12:30') slot are preselected, so the CTA always reads 'Confirm booking' (screens.jsx:331-332, 461)
  - Flutter now: _selectedTime starts null; CTA reads 'Choose a service' / 'Choose a time' and is disabled (booking_page.dart:357-362)
  - Fix: Preselect the first available slot after the slots load, or accept the disabled-CTA pattern as an intentional Flutter improvement.

#### Booking screen - Cash on visit payment card `BOOK-12`
- **[MINOR · components] banknote icon replaced by payments icon** `BOOK-12-F1`
  - Prototype: <Icon name="banknote" size={18}/> (screens.jsx:446)
  - Flutter now: Icon(Icons.payments_outlined, size: 18, color: AppColors.gold700) (booking_page.dart:290-294)
  - Fix: Use Icons.money_rounded, or the Lucide banknote glyph via lucide_icons_flutter (see consistency finding on icons).

#### Booking screen - Cash on visit payment card `BOOK-12`
- **[MINOR · tokens] Title line-height collapsed to 1.0** `BOOK-12-F2`
  - Prototype: fontWeight: 600, fontSize: 14 with normal line-height (screens.jsx:448)
  - Flutter now: AppTextStyles.label.copyWith(fontSize: 14), where label has height: 1 (booking_page.dart:303; app_text_styles.dart:71-76)
  - Fix: AppTextStyles.label.copyWith(fontSize: 14, height: 1.3)

#### Booking confirmed ('You said aiwa. We told Nadia.') `BOOK-14`
- **[MINOR · content] Date/time format differs** `BOOK-14-F4`
  - Prototype: Body 'Tuesday, May 19 at 12:30 PM.'; When row 'Tue, May 19 · 12:30 PM' (screens.jsx:478, 484)
  - Flutter now: '${DateFormat('EEE, MMM d').format(d)} · $t' with 24h 'HH:mm', used in both body and row (booking_confirmed_page.dart:16-26, 83, 102)
  - Fix: Body: '${DateFormat('EEEE, MMMM d').format(dt)} at ${DateFormat('h:mm a').format(dt)}'. Row: '${DateFormat('EEE, MMM d').format(dt)} · ${DateFormat('h:mm a').format(dt)}'.

#### Booking confirmed ('You said aiwa. We told Nadia.') `BOOK-14`
- **[MINOR · tokens] Headline gets h1 tracking the prototype does not use** `BOOK-14-F5`
  - Prototype: h1 fontFamily fontDisp, fontSize 30, lineHeight 1.1, no letterSpacing (screens.jsx:477)
  - Flutter now: AppTextStyles.h1.copyWith(fontSize: 30, height: 1.1) keeps letterSpacing -0.64 (-0.02*32) (booking_confirmed_page.dart:63; app_text_styles.dart:16-21)
  - Fix: AppTextStyles.h1.copyWith(fontSize: 30, height: 1.1, letterSpacing: 0)

#### Booking confirmed ('You said aiwa. We told Nadia.') `BOOK-14`
- **[MINOR · content] Headline uses the business name and the body says 'they' instead of 'she'** `BOOK-14-V1`
  - Prototype: 'You said aiwa. We told Nadia.' (first name) and 'We'll ping you the moment she confirms — usually within 30 minutes.' (screens.jsx:477-478), while the Provider row shows 'Nadia Studio' (480)
  - Flutter now: '. We told $provider.' with provider = booking.displayProviderName (business name first) and "We'll ping you the moment they confirm — usually within 30 minutes." (booking_confirmed_page.dart:31, 73, 83)
  - Fix: Headline: use the owner's first name, i.e. (booking.providerName.isNotEmpty ? booking.providerName : booking.displayProviderName).split(' ').first, once providerName maps ownerName (BOOK-50-F1). Keep the business name in the Provider row. Confirm with design whether gender-neutral 'they' replaces 'she'.

#### Cancel booking sheet (with reasons) `BOOK-29`
- **[MINOR · layout] Icon circle and spacing not in prototype sheet** `BOOK-29-F6`
  - Prototype: Handle then Eyebrow directly (no icon); padding '18px 22px 36px' (flow-screens.jsx:511-516)
  - Flutter now: 46px danger100 circle with Icons.warning_amber_rounded (confirm_sheet.dart:57-69); bottom padding 24 + safe area (36-41)
  - Fix: Reason sheet: no icon; EdgeInsets.fromLTRB(22, 18, 22, 36 + safeBottom).

#### Cancel booking sheet (with reasons) `BOOK-29`
- **[MINOR · tokens] Scrim, shadow and button size differ** `BOOK-29-F7`
  - Prototype: Scrim 'rgba(42,19,32,.45)' + backdropFilter blur(2px); shadow '0 -12px 32px rgba(0,0,0,.18)'; Btn size md (flow-screens.jsx:505-506, 512, 541-543)
  - Flutter now: barrierColor: AppColors.plum900.withOpacity(0.48), i.e. male #2E2A26 / female #6B3A3A (confirm_sheet.dart:27); sheetDecoration shadow AppColors.plum700.withOpacity(0.14) (app_theme.dart:41-51); buttons AiwaButtonSize.lg (confirm_sheet.dart:112, 124)
  - Fix: barrierColor: const Color(0x732A1320); BoxShadow(color: Color(0x2E000000), blurRadius: 32, offset: Offset(0, -12)); AiwaButtonSize.md.

#### Cancel booking sheet (with reasons) `BOOK-29`
- **[MINOR · tokens] Sheet eyebrow colour, title size and handle spacing differ** `BOOK-29-V1`
  - Prototype: <Eyebrow> uses the default aiwa.ink3 (male #7A7268 / female #8A6F71). The h2 is fontSize 22, lineHeight 1.1, margin '4px 0 14px', and the handle margin-bottom is 14 (flow-screens.jsx:515-517)
  - Flutter now: EyebrowLabel(eyebrow, color: fg) with fg = AppColors.danger700 (male #2E2A26 / female #6B3A3A). The title is AppTextStyles.h3.copyWith(fontSize: 23, height: 1.12) with h3 letterSpacing -0.22, and there is a SizedBox(height: 16) after the handle (confirm_sheet.dart:56, 71, 75)
  - Fix: In the new reason sheet use EyebrowLabel('Cancel your booking') with the default ink3, a title style of AppTextStyles.h3.copyWith(fontSize: 22, height: 1.1, letterSpacing: 0), and SizedBox(height: 14) after the handle and after the title.

#### Leave a review ('How was it?') `BOOK-34`
- **[MINOR · components] Provider avatar lacks palette and verified badge** `BOOK-34-F2`
  - Prototype: <Avatar name={p.name} palette={p.palette} size={64} verified={p.verified} /> (customer-extras.jsx:42)
  - Flutter now: AiwaAvatar(name: b.displayProviderName, size: 64, imageUrl: b.providerImageUrl) (review_page.dart:192-196)
  - Fix: Pass verified (needs a provider verification flag on BookingEntity) and a palette.

#### Leave a review ('How was it?') `BOOK-34`
- **[MINOR · states] Provider name/avatar disappear without route extra** `BOOK-34-F3`
  - Prototype: Provider block always rendered (customer-extras.jsx:42-44)
  - Flutter now: if (b != null) ...[AiwaAvatar, name, subtitle] (review_page.dart:191-208); a deep link '/review/:id' has no extra
  - Fix: When widget.booking is null, fetch it with getBookingDetail(bookingId) before rendering.

#### Leave a review ('How was it?') `BOOK-34`
- **[MINOR · layout] Star spacing tighter and glyph differs** `BOOK-34-F4`
  - Prototype: display flex gap: 10 with each button padding: 4, giving about 18px between 38px stars; lucide polygon strokeWidth 1.8 (customer-extras.jsx:47-60)
  - Flutter now: Padding(padding: EdgeInsets.symmetric(horizontal: 5)) gives 10px between stars; Icons.star_rounded / star_outline_rounded (review_page.dart:219-226)
  - Fix: EdgeInsets.symmetric(horizontal: 9). Optionally draw the kit polygon with CustomPaint for an exact glyph.

#### Leave a review ('How was it?') `BOOK-34`
- **[MINOR · layout] Header and field label spacing** `BOOK-34-F5`
  - Prototype: Header padding '60px 22px 12px'; Eyebrow marginBottom 10 above the textarea (customer-extras.jsx:33, 78)
  - Flutter now: ScreenHeader bottom padding 8 (screen_chrome.dart:36-41); AiwaTextField label gap SizedBox(height: 6) (aiwa_text_field.dart:82)
  - Fix: Use EyebrowLabel + SizedBox(height: 10) + TextField instead of AiwaTextField's label. Add a SizedBox(height: 4) after ScreenHeader.

#### Leave a review ('How was it?') `BOOK-34`
- **[MINOR · tokens] Textarea text size 15 instead of 14 and height by lines** `BOOK-34-F6`
  - Prototype: textarea fontSize: 14, height: 100, padding 14 (customer-extras.jsx:80-84)
  - Flutter now: style: AppTextStyles.body (15) with maxLines: 4 (aiwa_text_field.dart:96; review_page.dart:146)
  - Fix: SizedBox(height: 100, child: TextField(expands: true, maxLines: null, style: AppTextStyles.bodySm (14)))

#### My Bookings - Upcoming tab `BOOK-41`
- **[MINOR · content] Meta shows the provider address and 24h time instead of distance and 12h time** `BOOK-41-F4`
  - Prototype: <Icon name="calendar"/>{b.when} e.g. 'Tue, May 19 · 12:30 PM'; <Icon name="map-pin"/>{b.distance} e.g. '1.2 km' (screens.jsx:548-551)
  - Flutter now: _Meta(text: _when) with 'HH:mm', plus _Meta(Icons.location_on_outlined, b.providerAddress!) (my_bookings_page.dart:305-315, 375-391)
  - Fix: Use DateFormat('h:mm a') for the time. Show distance (needs ProviderSummaryDto.distanceKm on the booking) formatted as '${d.toStringAsFixed(1)} km'.

#### My Bookings - Upcoming tab `BOOK-41`
- **[MINOR · components] Avatar palette by list index and no verified badge** `BOOK-41-F5`
  - Prototype: <Avatar name={p.name} palette={p.palette} size={42} verified={p.verified} /> (screens.jsx:540)
  - Flutter now: AiwaAvatar(..., palette: AvatarPalette.values[index % AvatarPalette.values.length]) and no verified (my_bookings_page.dart:341-347)
  - Fix: Derive the palette from the provider id, not the index, so it is stable across tabs. Pass verified.

#### My Bookings - Upcoming tab `BOOK-41`
- **[MINOR · tokens] Card shadow differs** `BOOK-41-F6`
  - Prototype: boxShadow: '0 1px 2px rgba(74,31,56,.04)' (screens.jsx:537)
  - Flutter now: boxShadow: AppTheme.shadow1 = plum700 @0.06 blur 2 + ink @0.04 blur 1 (my_bookings_page.dart:333; app_theme.dart:60-71)
  - Fix: [BoxShadow(color: Color(0x0A4A1F38), blurRadius: 2, offset: Offset(0, 1))]

#### My Bookings - Upcoming tab `BOOK-41`
- **[MINOR · layout] Avatar and name not vertically centred** `BOOK-41-F7`
  - Prototype: Inner row display flex, alignItems: 'center' (screens.jsx:539)
  - Flutter now: Row(crossAxisAlignment: CrossAxisAlignment.start) for avatar, name and pill (my_bookings_page.dart:338-340)
  - Fix: Nest Row(crossAxisAlignment: center, [avatar, name column]) inside the outer start-aligned Row with the StatusPill.

#### My Bookings - Upcoming tab `BOOK-41`
- **[MINOR · layout] Tab spacing 18 instead of 24, and the underline does not overlap the divider** `BOOK-41-V1`
  - Prototype: Tab row display:flex gap 6 plus marginRight 18 per tab, 24px between 'Upcoming' and 'Past'. The underline has marginBottom -1, so the 2px bar sits over the row's 1px divider (screens.jsx:510-518)
  - Flutter now: AnimatedContainer margin right 18 only. The 2px bottom border is drawn inside the row, above the container's own 1px bottom divider (my_bookings_page.dart:245-272)
  - Fix: margin: const EdgeInsets.only(right: 24), and wrap the tab in Transform.translate(offset: const Offset(0, 1)) so the active underline covers the divider.

#### My Bookings - Upcoming tab `BOOK-41`
- **[MINOR · tokens] 'Bookings' title inherits -0.64 letterSpacing** `BOOK-41-V2`
  - Prototype: h1 fontDisp 28, lineHeight 1.05, no letterSpacing (screens.jsx:508)
  - Flutter now: PageTitle: AppTextStyles.h1.copyWith(fontSize: 28, height: 1.05), which keeps h1 letterSpacing -0.02*32 = -0.64 (screen_chrome.dart:119; app_text_styles.dart:16-21)
  - Fix: Add a letterSpacing parameter to PageTitle, or pass letterSpacing: 0 for Bookings (see BOOK-C4).

#### My Bookings - Past tab `BOOK-42`
- **[MINOR · states] Past status filter constant omits EXPIRED** `BOOK-42-F2`
  - Prototype: The Past filter includes 'expired', and b8 is listed and tappable (screens.jsx:60-61, 503, 535)
  - Flutter now: static const _pastStatuses = 'COMPLETED,CANCELLED,REJECTED,NO_SHOW' (my_bookings_page.dart:65) is sent as ?status= (85). The backend ignores it and the Past branch renders every booking (179-181), so EXPIRED appears today only by accident. Any filter built from this constant would drop it.
  - Fix: Include EXPIRED in the Past set, i.e. _pastSet = {'COMPLETED','CANCELLED','REJECTED','NO_SHOW','EXPIRED'}, and use it for both the query and the client-side filter (see BOOK-42-F1).

#### My Bookings - Past tab `BOOK-42`
- **[MINOR · tokens] Card shadow differs (same as Upcoming)** `BOOK-42-F3`
  - Prototype: boxShadow: '0 1px 2px rgba(74,31,56,.04)' (screens.jsx:537)
  - Flutter now: AppTheme.shadow1 (my_bookings_page.dart:333)
  - Fix: Same as BOOK-41-F6.

#### My Bookings - Past tab `BOOK-42`
- **[MINOR · content] Time format and location meta** `BOOK-42-F4`
  - Prototype: 'Last Sunday · 11:00 AM', '2.4 km' (screens.jsx:51, 549-550)
  - Flutter now: 'EEE, MMM d · HH:mm' and provider address (my_bookings_page.dart:305-315, 384-390)
  - Fix: Same as BOOK-41-F4.

#### Bookings - cancelled reason card (incl. provider-penalty variant) `BOOK-43`
- **[MINOR · states] Reason box shown even when no reason exists** `BOOK-43-V1`
  - Prototype: The box renders only when (b.status === 'cancelled' || b.status === 'noshow') && b.cancellationReason (screens.jsx:552). The rejected box likewise requires b.rejectionReason (565)
  - Flutter now: _ReasonBox is always rendered for CANCELLED / NO_SHOW / REJECTED (my_bookings_page.dart:392-409)
  - Fix: After mapping the fields (BOOK-50-F2): if ((b.status == 'CANCELLED' || b.status == 'NO_SHOW') && b.cancellationReason != null) ... and if (b.status == 'REJECTED' && b.rejectionReason != null) ...

#### Bookings - Upcoming empty state ('Nothing booked yet') `BOOK-47`
- **[MINOR · components] calendar-plus glyph replaced** `BOOK-47-F1`
  - Prototype: icon={tab === 'upcoming' ? 'calendar-plus' : 'history'} (screens.jsx:524)
  - Flutter now: Icons.calendar_month_outlined (my_bookings_page.dart:186-188)
  - Fix: Icons.edit_calendar_outlined (closest), or the Lucide calendar-plus glyph.

#### Bookings - Upcoming empty state ('Nothing booked yet') `BOOK-47`
- **[MINOR · interaction] 'Find a provider' target differs (prototype stub)** `BOOK-47-F2`
  - Prototype: onAction={() => onProvider && onProvider(1)} pushes the hard-coded provider #1 profile (screens.jsx:530; prototype.jsx:700)
  - Flutter now: onAction: () => context.go(AppRoutes.search) (my_bookings_page.dart:194)
  - Fix: Keep Search. The prototype hard-codes a demo provider id, so confirm the intent with design.

#### Bookings - Upcoming empty state ('Nothing booked yet') `BOOK-47`
- **[MINOR · layout] Empty state lacks the 22px list gutter** `BOOK-47-F3`
  - Prototype: EmptyState sits inside padding: '14px 22px 0' (screens.jsx:521)
  - Flutter now: SliverToBoxAdapter(child: EmptyState(...)) with no outer padding (my_bookings_page.dart:184-196)
  - Fix: Wrap it in Padding(padding: EdgeInsets.fromLTRB(AppTheme.gutter, 14, AppTheme.gutter, 0)).

#### Bookings - Upcoming empty state ('Nothing booked yet') `BOOK-47`
- **[MINOR · layout] EmptyState internal gaps 3px tighter and no pop-in** `BOOK-47-V1`
  - Prototype: EmptyState column uses gap: 3, so icon to title is 17 (marginBottom 14 + 3) and title to body is 9 (6 + 3). The circle animates 'aiwa-pop 320ms cubic-bezier(.32,.72,0,1)' (states.jsx:88-98)
  - Flutter now: SizedBox(height: 14) and SizedBox(height: 6), with no entrance animation (empty_state.dart:60-73). This also applies to BOOK-48
  - Fix: In empty_state.dart use SizedBox(height: 17) and SizedBox(height: 9). Wrap the circle in TweenAnimationBuilder<double>(tween: Tween(begin: .85, end: 1), duration: AppTheme.dur3, curve: AppTheme.easeSoft, builder: (_, v, c) => Transform.scale(scale: v, child: c)).

#### Bookings - Past empty state ('No past appointments') `BOOK-48`
- **[MINOR · layout] Empty state lacks the 22px list gutter** `BOOK-48-F1`
  - Prototype: padding: '14px 22px 0' wrapper (screens.jsx:521)
  - Flutter now: No outer padding (my_bookings_page.dart:184-196)
  - Fix: Same as BOOK-47-F3.

#### Bookings - guest locked state `BOOK-49`
- **[MINOR · content] Title/body copy differs** `BOOK-49-F2`
  - Prototype: title="See your bookings" body="Sign in to view and track your bookings." (prototype.jsx:699)
  - Flutter now: title: 'Your bookings live here', body: 'Sign in to book providers, track them on the way, and see your history.' (my_bookings_page.dart:40-42)
  - Fix: Use the prototype strings.

#### Bookings - guest locked state `BOOK-49`
- **[MINOR · layout] Padding differs** `BOOK-49-F3`
  - Prototype: padding: '68px 24px 32px' (customer-extras-2.jsx:13)
  - Flutter now: EdgeInsets.fromLTRB(24, insets.top + 24, 24, 24) inside Padding(bottom: 90) (guest_locked_view.dart:27; my_bookings_page.dart:37-38)
  - Fix: Top insets.top + 14 (68 minus the ~54 status bar), bottom 32 + tab bar height.

#### Toast component (success toast) `BOOK-52`
- **[MINOR · tokens] Background, text size and shadow differ** `BOOK-52-F3`
  - Prototype: background: 'rgba(42,19,32,.96)'; fontSize 13 fontWeight 500; boxShadow '0 12px 32px rgba(74,31,56,.3)' (prototype.jsx:28-36)
  - Flutter now: AppColors.plum900.withOpacity(0.96), i.e. male #2E2A26 / female #6B3A3A; bodySm 14 w500; no shadow (app_theme.dart:185-193)
  - Fix: color: const Color(0xF52A1320) (or keep theme-aware plum900 by design decision); AppTextStyles.bodySm.copyWith(fontSize: 13); BoxShadow(color: Color(0x4D4A1F38), blurRadius: 32, offset: Offset(0, 12)).

#### Toast component (success toast) `BOOK-52`
- **[MINOR · interaction] Dismiss timing and entrance animation** `BOOK-52-F4`
  - Prototype: setTimeout(onClose, 2800); animation 'aiwa-toast 320ms cubic-bezier(.32,.72,0,1)' from translateY(-10px) (prototype.jsx:22, 30)
  - Flutter now: Default SnackBar duration 4s with the Material bottom slide
  - Fix: Duration(milliseconds: 2800) and a 320ms AppTheme.easeSoft slide from Offset(0, -0.2).

#### Toast - 'Booking cancelled. Reason: {reason}' `BOOK-55`
- **[MINOR · components] Rendered as Material SnackBar** `BOOK-55-F2`
  - Prototype: <Toast> component (prototype.jsx:20-39)
  - Flutter now: ScaffoldMessenger.of(context).showSnackBar(...) (my_bookings_page.dart:127-129)
  - Fix: Use showAiwaToast (BOOK-52).

#### Toast - 'Thanks - your review is live.' `BOOK-56`
- **[MINOR · components] Rendered as Material SnackBar** `BOOK-56-F1`
  - Prototype: <Toast> top toast with check badge (prototype.jsx:20-39)
  - Flutter now: ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks - your review is live.'))) (review_page.dart:91-93)
  - Fix: showAiwaToast(context, 'Thanks - your review is live.') (BOOK-52).

#### Cross-cutting `-`
- **[MINOR · components] Material Icons used instead of the Lucide set** `BOOK-C2`
  - Prototype: All icons are Lucide names via <Icon name=...> (components.jsx:21-41), e.g. banknote, calendar-plus, x-circle
  - Flutter now: Icons.* throughout (e.g. Icons.payments_outlined booking_page.dart:291, Icons.calendar_month_outlined my_bookings_page.dart:187); pubspec.yaml has no Lucide package
  - Fix: Add lucide_icons_flutter and map kit names 1:1 (LucideIcons.banknote, LucideIcons.calendarPlus, ...).

#### Cross-cutting `-`
- **[MINOR · tokens] Sheet scrim and shadow derived from theme colours instead of the kit literals** `BOOK-C3`
  - Prototype: Scrim rgba(42,19,32,.45-.48); shadow rgba(0,0,0,.18) / rgba(42,19,32,.2) (flow-screens.jsx:505-512; states.jsx:234-240)
  - Flutter now: AppColors.plum900.withOpacity(0.48) (confirm_sheet.dart:27); AppTheme.sheetDecoration plum700 @0.14 (app_theme.dart:41-51)
  - Fix: Add AppColors.scrim = Color(0x7A2A1320) and AppTheme.sheetShadow = BoxShadow(color: Color(0x332A1320), blurRadius: 32, offset: Offset(0, -12)). Use them in every bottom sheet.

#### Cross-cutting `-`
- **[MINOR · tokens] Serif heading styles bake in tracking that screens then inherit** `BOOK-C4`
  - Prototype: letterSpacing is set per heading only where needed (e.g. BookingType h1 -0.02em at flow-screens.jsx:168; Confirmed h1 none at screens.jsx:477)
  - Flutter now: AppTextStyles.h1/h2/h3 always carry -0.02em / -0.01em (app_text_styles.dart:16-35) and are reused with copyWith(fontSize: ...), so tracking is computed from the base size
  - Fix: Compute letterSpacing from the final size, e.g. static TextStyle serif(double size, {double tracking = 0}) => _serif(fontSize: size, letterSpacing: tracking * size, ...).

#### Cross-cutting `-`
- **[MINOR · components] No shared reason-picker sheet; the generic ConfirmSheet is used instead** `BOOK-C5`
  - Prototype: CancelSheet and FlagProviderSheet share one pattern: handle, eyebrow, h2, selectable reason rows, 'other' textarea, secondary + danger buttons (flow-screens.jsx:490-549; customer-extras.jsx:432-491)
  - Flutter now: Only showConfirmSheet exists (confirm_sheet.dart:12-138); cancel uses it without reasons (my_bookings_page.dart:95-106)
  - Fix: Create shared/widgets/reason_sheet.dart (showReasonSheet(context, eyebrow, title, reasons, otherLabel, confirmLabel)). Reuse it for Cancel, Flag provider and the Complaint categories.
