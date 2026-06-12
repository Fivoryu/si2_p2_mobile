import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../firebase_options.dart';
import 'in_app_notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class PushService {
  static bool _initialized = false;

  static Future<void> init(Dio dio) async {
    if (_initialized) return;

    if (kIsWeb && DefaultFirebaseOptions.webOrNull == null) {
      _initialized = true;
      return;
    }

    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }

    final fm = FirebaseMessaging.instance;
    await fm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      if (kDebugMode) {
        debugPrint('Permiso notificaciones Android: $status');
      }
    }
    await _registerToken(dio, fm);

    fm.onTokenRefresh.listen((token) async {
      await _sendToken(dio, token);
    });

    FirebaseMessaging.onMessage.listen((message) {
      final title = message.notification?.title ?? message.data['title'] as String?;
      final body = message.notification?.body ?? message.data['body'] as String?;
      final incidenteId = message.data['incidente_id'] as String?;
      if (title != null) {
        InAppNotificationService.show(
          title: title,
          body: body ?? '',
          incidenteId: incidenteId,
        );
      }
    });

    _initialized = true;
  }

  static Future<void> _registerToken(Dio dio, FirebaseMessaging fm) async {
    const vapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');
    final token = kIsWeb && vapidKey.isNotEmpty
        ? await fm.getToken(vapidKey: vapidKey)
        : await fm.getToken();
    if (token != null) {
      await _sendToken(dio, token);
    }
  }

  static Future<void> _sendToken(Dio dio, String token) async {
    try {
      await dio.post('/usuarios/me/fcm', data: {'fcm_token': token});
      if (kDebugMode) {
        debugPrint('FCM token registrado (${token.substring(0, 12)}…)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('No se pudo registrar FCM token: $e');
      }
    }
  }
}
