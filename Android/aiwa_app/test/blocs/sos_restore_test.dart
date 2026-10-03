// CR-16: an open SOS comes back when Tracking is reopened, and the SOS sends a
// fresh fix (with its time and accuracy) rather than an old last-known one.
// Runs the real cubit -> repository -> datasource -> ApiClient chain; only the
// HTTP adapter and the location platform are faked.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:aiwa_app/core/network/api_client.dart';
import 'package:aiwa_app/core/storage/secure_storage.dart';
import 'package:aiwa_app/features/bookings/data/datasources/booking_remote_datasource.dart';
import 'package:aiwa_app/features/bookings/data/repositories/booking_repository_impl.dart';
import 'package:aiwa_app/features/bookings/presentation/bloc/live_booking_cubit.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

const _booking = {
  'id': 7,
  'provider': {'id': 12, 'businessName': 'Nadia Studio'},
  'service': {'id': 3, 'name': 'Blowout'},
  'bookingDate': '2026-05-19',
  'startTime': '12:30:00',
  'status': 'ON_THE_WAY',
  'homeService': true,
  'totalPrice': 350,
};

const _openSos = {
  'id': 41,
  'type': 'SOS',
  'resolved': false,
  'supportAlerted': true,
  'contactsTexted': 2,
};

/// Serves GET /bookings/7 and GET|POST /bookings/7/safety; [safety] decides
/// what the SOS read returns: a JSON body, an HTTP status, or 'offline'.
class _Server implements HttpClientAdapter {
  Object safety = {'data': <Object>[]};
  final posted = <Map<String, dynamic>>[];

  static final _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (o.path == '/bookings/7') {
      return ResponseBody.fromString(
        jsonEncode({'data': _booking}),
        200,
        headers: _json,
      );
    }
    if (o.method == 'POST') {
      posted.add(
        (o.data is String ? jsonDecode(o.data as String) : o.data)
            as Map<String, dynamic>,
      );
      return ResponseBody.fromString(
        jsonEncode({'data': _openSos}),
        201,
        headers: _json,
      );
    }
    final s = safety;
    if (s is int) return ResponseBody.fromString('{}', s, headers: _json);
    if (s == 'offline') {
      throw DioException.connectionError(requestOptions: o, reason: 'offline');
    }
    return ResponseBody.fromString(jsonEncode(s), 200, headers: _json);
  }

  @override
  void close({bool force = false}) {}
}

/// Last known = an old fix far away; current = a fresh one, unless it fails.
class _Geo extends GeolocatorPlatform {
  bool currentFails = false;

  static Position fix(double lat, DateTime at, double accuracy) => Position(
    latitude: lat,
    longitude: 31.2,
    timestamp: at,
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  static final stale = fix(29.0, DateTime.utc(2026, 5, 19, 8), 900);
  static final fresh = fix(30.05, DateTime.utc(2026, 5, 19, 12, 31), 12.5);

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => stale;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    if (currentFails) throw TimeoutException('no fix in time');
    return fresh;
  }
}

void main() {
  late _Server server;
  late LiveBookingCubit cubit;
  late _Geo geo;
  final realGeo = GeolocatorPlatform.instance;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    server = _Server();
    geo = _Geo();
    GeolocatorPlatform.instance = geo;
    final api = ApiClient(
      SecureStorage(const FlutterSecureStorage()),
      adapter: server,
    );
    cubit = LiveBookingCubit(
      BookingRepositoryImpl(BookingRemoteDataSourceImpl(api)),
      '7',
    );
  });

  tearDown(() async {
    await cubit.close();
    GeolocatorPlatform.instance = realGeo;
  });

  group('load() restores an open SOS (C1)', () {
    test(
      'an SOS still open on the server brings back the banner and I\'m safe',
      () async {
        server.safety = {
          'data': [_openSos],
        };
        await cubit.load();
        expect(cubit.state.booking, isNotNull);
        expect(cubit.state.sos, SosStage.notified);
        expect(cubit.state.sosReport?.supportAlerted, isTrue);
        expect(cubit.state.sosReport?.contactsTexted, 2);
      },
    );

    test(
      'no open SOS (none, or only resolved ones): state stays none',
      () async {
        server.safety = {
          'data': [
            {..._openSos, 'resolved': true},
          ],
        };
        await cubit.load();
        expect(cubit.state.booking, isNotNull);
        expect(cubit.state.sos, SosStage.none);
      },
    );

    final failures = <String, Object>{
      'a 401': 401,
      'no network': 'offline',
      'a bad payload (thrown while reading)': {'data': 'not a list'},
    };
    for (final MapEntry(key: name, value: failure) in failures.entries) {
      test('the SOS read failing with $name leaves the page usable', () async {
        server.safety = failure;
        await cubit.load();
        expect(cubit.state.booking, isNotNull, reason: name);
        expect(cubit.state.loadError, isNull, reason: name);
        expect(cubit.state.sos, SosStage.none, reason: name);
        // SOS can still be raised.
        server.safety = {
          'data': [_openSos],
        };
        await cubit.sos();
        expect(cubit.state.sos, SosStage.notified, reason: name);
      });
    }
  });

  group('the SOS location is fresh and says how old and accurate it is (C2)', () {
    test(
      'a fresh fix wins over an old last-known one, with time and accuracy',
      () async {
        await cubit.sos();
        final body = server.posted.single;
        expect(
          body['latitude'],
          _Geo.fresh.latitude,
          reason: 'not the stale last-known fix',
        );
        expect(body['locationTime'], '2026-05-19T12:31:00.000Z');
        expect(body['locationAccuracy'], 12.5);
      },
    );

    test(
      'no fresh fix in time: the last known one goes, with its time and accuracy',
      () async {
        geo.currentFails = true;
        await cubit.sos();
        final body = server.posted.single;
        expect(body['latitude'], _Geo.stale.latitude);
        expect(body['locationTime'], '2026-05-19T08:00:00.000Z');
        expect(body['locationAccuracy'], 900);
      },
    );
  });
}
