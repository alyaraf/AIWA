import 'dart:convert';
import 'dart:io';

import 'package:aiwa_app/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Set<String> _keys(String f) => {
  for (final k
      in (jsonDecode(File('lib/l10n/$f').readAsStringSync()) as Map).keys)
    if (!(k as String).startsWith('@')) k,
};

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ar = lookupAppLocalizations(const Locale('ar'));
  setUpAll(() => initializeDateFormatting('ar'));

  test('app_en.arb and app_ar.arb have the same keys', () {
    final e = _keys('app_en.arb'), a = _keys('app_ar.arb');
    expect(e.difference(a), isEmpty, reason: 'missing in ar');
    expect(a.difference(e), isEmpty, reason: 'missing in en');
  });

  test('formatters follow the locale', () {
    expect(en.egp(1250), 'EGP 1,250');
    expect(ar.egp(1250), contains('ج.م'));
    expect(en.durationLabel(45), '45 min');
    expect(en.durationLabel(60), '1h');
    expect(en.durationLabel(150), '2h 30m');
    expect(ar.durationLabel(60), 'ساعة');
    expect(en.formatWhen('2026-05-19', '12:30'), 'Tue, May 19 · 12:30 PM');
    expect(ar.formatWhen('2026-05-19', '12:30'), contains('مايو'));
    expect(en.weekdayShort(0), 'Sun');
    expect(ar.weekdayShort(0), 'الأحد');
    expect(en.category('NAILS'), 'Nails');
    expect(ar.category('NAILS'), 'الأظافر');
  });

  test('Arabic plurals pick the right form', () {
    expect(ar.revCount(1), 'تقييم واحد');
    expect(ar.revCount(2), 'تقييمان');
    expect(ar.revCount(3), contains('تقييمات'));
    expect(ar.revCount(11), contains('تقييمًا'));
  });

  test('client fallback errors are translated, server text passes through', () {
    expect(ar.error('No internet connection'), ar.errorNoInternet);
    expect(
      ar.error('Trusted contacts isn’t supported yet.'),
      ar.errorNotSupported,
    );
    expect(ar.error('رسالة من الخادم'), 'رسالة من الخادم');
  });

  test('RTL: signs, dates and written text keep their direction', () {
    expect(en.egpCents(110, sign: '+'), 'EGP \u2066+110.00\u2069');
    expect(ar.egpCents(110, sign: '+'), startsWith('\u2066+110.00\u2069'));
    expect(ar.formatWhen('2026-05-19', '12:30'), contains('،'));
    expect(textDirectionOf('Trusted nails specialists.'), TextDirection.ltr);
    expect(textDirectionOf('أفضل صالون'), TextDirection.rtl);
  });

  test('spansOf keeps word order from the template', () {
    final spans = spansOf(ar.authCodeSentTo('{destination}'), {
      'destination': const TextSpan(text: 'X'),
    });
    expect(spans.map((s) => (s as TextSpan).text).join(), contains('X'));
    expect((spans.last as TextSpan).text, '.');
  });
}
