import 'dart:convert';
import 'dart:typed_data';

import 'package:aiwa_app/core/network/api_client.dart';
import 'package:aiwa_app/core/storage/secure_storage.dart';
import 'package:aiwa_app/features/bookings/data/datasources/booking_remote_datasource.dart';
import 'package:aiwa_app/features/provider_dashboard/data/datasources/dashboard_remote_datasource.dart';
import 'package:aiwa_app/features/providers/data/datasources/provider_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// CR-21: complaint text, cancel/reject reasons and notes travel in a JSON body,
/// never in the URL (proxy logs, request-line limits).
void main() {
  late _Recorder rec;
  late BookingRemoteDataSourceImpl bookings;
  late DashboardRemoteDataSourceImpl dashboard;
  late ProviderRemoteDataSourceImpl providers;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    rec = _Recorder();
    final api = ApiClient(SecureStorage(const FlutterSecureStorage()), adapter: rec);
    bookings = BookingRemoteDataSourceImpl(api);
    dashboard = DashboardRemoteDataSourceImpl(api);
    providers = ProviderRemoteDataSourceImpl(api);
  });

  /// The fake answers `{}`, which the models cannot parse; the request is what counts.
  Future<void> send(Future<Object?> Function() call) async {
    try {
      await call();
    } catch (_) {}
  }

  void expectBodyOnly(String path, Map<String, Object?> body, {Map<String, Object?> query = const {}}) {
    expect(rec.paths.single, path);
    expect(rec.bodies.single, body);
    expect(rec.queries.single, query);
  }

  test('a customer cancel reason goes in the body', () async {
    await send(() => bookings.cancelBooking('5', reason: 'Change of plans'));
    expectBodyOnly('/bookings/5/cancel', {'reason': 'Change of plans'});
  });

  test('a cancel without a reason sends no reason at all', () async {
    await send(() => bookings.cancelBooking('5'));
    expect(rec.queries.single, isEmpty);
    expect(rec.bodies.single, isNot(contains('reason')));
  });

  test('a complaint from a booking sends its description in the body', () async {
    await send(
      () => bookings.submitComplaint(
        bookingId: '5',
        providerId: '9',
        category: 'RUDE',
        description: 'Arrived an hour late',
      ),
    );
    expect(rec.bodies.single, {'description': 'Arrived an hour late'});
    expect(rec.queries.single, {'bookingId': '5', 'targetProviderId': '9', 'category': 'RUDE'});
  });

  test('flagging a provider sends the note in the body', () async {
    await send(() => providers.flagProvider('9', 'SPAM', 'Fake photos'));
    expect(rec.bodies.single, {'description': 'Fake photos'});
    expect(rec.queries.single, {'targetProviderId': '9', 'category': 'SPAM'});
  });

  test('a reported photo sends its reason in the body', () async {
    await send(() => providers.reportPhoto('9', '3', 'Not the salon'));
    expectBodyOnly('/providers/9/gallery/3/report', {'reason': 'Not the salon'});
  });

  test('a provider reject reason goes in the body', () async {
    await send(() => dashboard.rejectBooking('5', 'Fully booked'));
    expectBodyOnly('/bookings/5/reject', {'reason': 'Fully booked'});
  });

  test('a provider completion note goes in the body, the cash flag stays a parameter', () async {
    await send(() => dashboard.completeBooking('5', cashCollected: false, note: 'Left without paying'));
    expect(rec.bodies.single, {'note': 'Left without paying'});
    expect(rec.queries.single, {'cashCollected': false});
  });
}

class _Recorder implements HttpClientAdapter {
  final paths = <String>[];
  final bodies = <Object?>[];
  final queries = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(o.path);
    queries.add(o.queryParameters);
    final data = o.data;
    bodies.add(data is String ? jsonDecode(data) : (data ?? <String, dynamic>{}));
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
