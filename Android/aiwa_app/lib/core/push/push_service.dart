import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../telemetry.dart';

/// Push notifications (FE-3) over Firebase Cloud Messaging.
///
/// Firebase is configured from --dart-defines (tool/build_release.sh), so no
/// google-services.json / GoogleService-Info.plist or Gradle plugin is needed:
///   FIREBASE_API_KEY, FIREBASE_PROJECT_ID, FIREBASE_SENDER_ID,
///   FIREBASE_ANDROID_APP_ID, FIREBASE_IOS_APP_ID
/// Without them (dev, tests) every method is a no-op and the app runs as before.
class PushService {
  PushService._();

  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const _androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');

  static const _channel = AndroidNotificationChannel(
    'aiwa_default',
    'Bookings and safety',
    description: 'Booking updates, messages and safety alerts',
    importance: Importance.high,
  );

  static final _local = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// Push data of a tapped notification ({type, relatedBookingId, ...}). The
  /// app listens once it has a signed-in user and a router (see app.dart).
  static final taps = StreamController<Map<String, String>>.broadcast();

  /// A tap that launched the app from a terminated state, kept until the app
  /// is ready to route it.
  static Map<String, String>? pendingLaunchTap;

  static bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  static bool get configured =>
      _apiKey.isNotEmpty &&
      _projectId.isNotEmpty &&
      _senderId.isNotEmpty &&
      (_isIOS ? _iosAppId.isNotEmpty : _androidAppId.isNotEmpty);

  /// Call once from main() after WidgetsFlutterBinding.ensureInitialized().
  static Future<void> init() async {
    if (_ready || kIsWeb || !configured) return;
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: _apiKey,
          appId: _isIOS ? _iosAppId : _androidAppId,
          messagingSenderId: _senderId,
          projectId: _projectId,
        ),
      );

      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) => _emit(r.payload),
      );
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);

      // In the foreground the OS shows nothing, so show it ourselves.
      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(
        (m) => taps.add(_strings(m.data)),
      );
      final launch = await FirebaseMessaging.instance.getInitialMessage();
      if (launch != null) pendingLaunchTap = _strings(launch.data);
      _ready = true;
    } catch (e) {
      // Push is a convenience; a bad config must never stop the app starting.
      logDiagnostic('Push disabled', error: e);
    }
  }

  /// The device's FCM token for PushRegistrar, or null when push is off.
  static Future<String?> token() async {
    if (!_ready) return null;
    try {
      if (_isIOS) {
        // iOS hands out an FCM token only once APNs has one.
        final apns = await FirebaseMessaging.instance.getAPNSToken();
        if (apns == null) return null;
      }
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  /// After the OS notification prompt was accepted: iOS registers with APNs
  /// here, so a token exists for the next PushRegistrar.register().
  static Future<void> afterPermissionGranted() async {
    if (!_ready) return;
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {}
  }

  /// Fires when FCM rotates the token, so the backend can be told again.
  static Stream<String> get tokenRefresh =>
      _ready ? FirebaseMessaging.instance.onTokenRefresh : const Stream.empty();

  static Future<void> _showForeground(RemoteMessage m) async {
    final n = m.notification;
    if (n == null) return;
    await _local.show(
      m.messageId.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(m.data),
    );
  }

  static void _emit(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) taps.add(_strings(decoded));
    } catch (_) {}
  }

  static Map<String, String> _strings(Map<dynamic, dynamic> data) => {
    for (final e in data.entries) '${e.key}': '${e.value ?? ''}',
  };
}
