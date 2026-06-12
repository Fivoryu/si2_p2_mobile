import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../firebase_options.dart';

/// Notificaciones del sistema (bandeja Android / banner iOS).
class LocalNotificationService {
  LocalNotificationService._();

  static const _channelId = 'emergencias_push';
  static const _channelName = 'Emergencias';
  static const _channelDesc = 'Alertas de auxilio y cambios de estado';

  static final _plugin = FlutterLocalNotificationsPlugin();
  static GoRouter? _router;
  static bool _ready = false;
  static int _id = 0;

  static bool get supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static void attachRouter(GoRouter router) => _router = router;

  static Future<void> init() async {
    if (!supported || _ready) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onTap,
    );

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    _ready = true;
  }

  static void _onTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty && _router != null) {
      _router!.push('/tracking/$payload');
    }
  }

  static void _navigateFromMessage(RemoteMessage message) {
    final incidenteId = message.data['incidente_id'] as String?;
    if (incidenteId != null && _router != null) {
      _router!.push('/tracking/$incidenteId');
    }
  }

  static Future<void> bindFirebaseMessaging(FirebaseMessaging fm) async {
    if (!supported) return;

    final initial = await fm.getInitialMessage();
    if (initial != null) {
      _navigateFromMessage(initial);
    }

    FirebaseMessaging.onMessageOpenedApp.listen(_navigateFromMessage);
  }

  static Future<void> showFromRemoteMessage(RemoteMessage message) async {
    final title =
        message.notification?.title ?? message.data['title'] as String?;
    final body =
        message.notification?.body ?? message.data['body'] as String?;
    if (title == null) return;

    await show(
      title: title,
      body: body ?? '',
      incidenteId: message.data['incidente_id'] as String?,
    );
  }

  static Future<void> show({
    required String title,
    required String body,
    String? incidenteId,
  }) async {
    if (!supported) return;
    if (!_ready) await init();

    _id = (_id + 1) % 100000;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      visibility: NotificationVisibility.public,
      ticker: 'Emergencias',
    );

    await _plugin.show(
      _id,
      title,
      body,
      const NotificationDetails(android: androidDetails),
      payload: incidenteId,
    );
  }
}

/// Handler FCM con app en segundo plano o cerrada.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!LocalNotificationService.supported) return;
  await LocalNotificationService.init();
  await LocalNotificationService.showFromRemoteMessage(message);
}
