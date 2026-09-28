import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'app_localizations.dart';

export 'app_localizations.dart';

extension AiwaL10n on AppLocalizations {
  /// Translates the client-side fallback messages from core/errors,
  /// api_client and the datasources. Server messages already arrive in the
  /// user's language (Accept-Language), so anything else passes through.
  String error(String message) => switch (message) {
    'No internet connection' => errorNoInternet,
    'Connection timed out' => errorTimeout,
    'Something went wrong' || 'Failed' => errorGeneric,
    'Unauthorized. Please sign in again.' => errorUnauthorized,
    'Login failed' => errorLoginFailed,
    'Registration failed' => errorRegistrationFailed,
    'Failed to send OTP' => errorSendOtpFailed,
    'Invalid OTP' => errorInvalidOtp,
    _ when message.endsWith('supported yet.') => errorNotSupported,
    _ => message,
  };

  /// Backend category enum (`HAIR`, `NAILS`, …) -> display name.
  String category(String code) => switch (code.toUpperCase()) {
    'HAIR' => categoryHair,
    'NAILS' => categoryNails,
    'SPA' => categorySpa,
    'MAKEUP' => categoryMakeup,
    'LASHES' => categoryLashes,
    'SKIN' => categorySkin,
    'MASSAGE' => categoryMassage,
    _ => categoryOther,
  };

  /// Saved-address label: the stock `Home` / `Work` / `Other` values are
  /// translated, custom labels are the user's own text.
  String addressLabel(String label) => switch (label) {
    'Home' => addrHome,
    'Work' => addrWork,
    'Other' => addrOther,
    _ => label,
  };

  /// Review quick tags are stored as these English values; display only.
  String reviewTag(String tag) => switch (tag) {
    'Punctual' => tagPunctual,
    'Skilled' => tagSkilled,
    'Friendly' => tagFriendly,
    'Clean studio' => tagCleanStudio,
    'Worth the price' => tagWorthPrice,
    'Great with hair' => tagGreatHair,
    'On time' => rateTagOnTime,
    'Respectful' => rateTagRespectful,
    'Clear about needs' => rateTagClear,
    'Paid in full' => rateTagPaid,
    'Late' => rateTagLate,
    'Difficult to reach' => rateTagHardToReach,
    _ => tag,
  };

  /// 'EGP 1,250' / '1,250 ج.م'.
  String egp(num v) =>
      moneyEgp(NumberFormat.decimalPattern(localeName).format(v.round()));

  /// 'EGP 1,250.50' — two decimals, for ledgers. [sign] ('+' / '−') is
  /// kept on the number's left in RTL too ('+110.00 ج.م', not '110.00+').
  String egpCents(num v, {String sign = ''}) {
    final n = NumberFormat('#,##0.00', localeName).format(v);
    return moneyEgp(sign.isEmpty ? n : '\u2066$sign$n\u2069');
  }

  /// 'Tue, May 19 · 12:30 PM' from BookingDto's `yyyy-MM-dd` + `HH:mm[:ss]`.
  String formatWhen(String date, String time) {
    final dt = _parse(date, time);
    if (dt == null) return '$date · $time';
    return '${DateFormat.MMMEd(localeName).format(dt)} · '
        '${DateFormat('h:mm a', localeName).format(dt)}';
  }

  /// 'Today · 12:30 PM', 'Tomorrow · 11:00 AM', else [formatWhen].
  String relativeWhen(String date, String time) {
    final dt = _parse(date, time);
    if (dt == null) return formatWhen(date, time);
    final now = DateTime.now();
    final days = DateTime(
      dt.year,
      dt.month,
      dt.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    final t = DateFormat('h:mm a', localeName).format(dt);
    return switch (days) {
      0 => whenToday(t),
      1 => whenTomorrow(t),
      -1 => whenYesterday(t),
      _ => formatWhen(date, time),
    };
  }

  /// '45 min', '1h', '2h 30m'.
  String durationLabel(int minutes) => minutes < 60
      ? durationMinutes(minutes)
      : minutes % 60 == 0
      ? durationHours(minutes ~/ 60)
      : durationHoursMinutes(minutes ~/ 60, minutes % 60);

  /// '850 m' / '2.4 km'; '' when the backend sent no distance.
  String distance(double? km) => km == null
      ? ''
      : km < 1
      ? distanceMeters((km * 1000).round())
      : distanceKm(km.toStringAsFixed(1));

  /// "2 weeks ago" style, as in the design's review lists.
  String relativeDay(DateTime date) {
    final days = DateTime.now().difference(date.toLocal()).inDays;
    if (days < 1) return commonToday;
    if (days == 1) return agoYesterday;
    if (days < 7) return agoDays(days);
    if (days < 30) return agoWeeks(days ~/ 7);
    if (days < 365) return agoMonths(days ~/ 30);
    return DateFormat('MMM yyyy', localeName).format(date.toLocal());
  }

  /// Short day name, Sunday = 0 ('Sun' / 'الأحد'). 7 Jan 2024 was a Sunday.
  String weekdayShort(int sundayIndex) =>
      DateFormat.E(localeName).format(DateTime(2024, 1, 7 + sundayIndex));

  static DateTime? _parse(String date, String time) =>
      DateTime.tryParse('$date ${time.length == 5 ? '$time:00' : time}');
}

/// Direction of text people wrote (bios, reviews, chat), so an English bio
/// keeps its punctuation in place inside the Arabic UI and vice versa.
TextDirection textDirectionOf(String text) =>
    Bidi.detectRtlDirectionality(text) ? TextDirection.rtl : TextDirection.ltr;

/// Wraps a server-provided name (FSI…PDI) so a Latin name followed by a
/// number ('Gel Manicure · 45 دقيقة') doesn't swallow the number in RTL.
String bidiIsolate(String s) => '\u2068$s\u2069';

/// Splits a translated [template] on its `{name}` slots and drops the styled
/// [parts] in, so word order can differ per language.
/// Call as `spansOf(l.someKey('{a}'), {'a': TextSpan(...)})`.
List<InlineSpan> spansOf(String template, Map<String, InlineSpan> parts) {
  final out = <InlineSpan>[];
  template.splitMapJoin(
    RegExp(r'\{(\w+)\}'),
    onMatch: (m) {
      out.add(parts[m[1]] ?? TextSpan(text: m[0]));
      return '';
    },
    onNonMatch: (s) {
      if (s.isNotEmpty) out.add(TextSpan(text: s));
      return '';
    },
  );
  return out;
}
