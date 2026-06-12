import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'local_notification_service.dart';

export 'local_notification_service.dart' show firebaseMessagingBackgroundHandler;

class PushService {
  static bool _initialized = false;

  static Future<void> init(Dio dio) async {
    if (_initialized) return;

    if (kIsWeb) {
      _initialized = true;
      return;
    }

    await LocalNotificationService.init();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

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

    await fm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await _registerToken(dio, fm);
    await LocalNotificationService.bindFirebaseMessaging(fm);

    fm.onTokenRefresh.listen((token) async {
      await _sendToken(dio, token);
    });

    FirebaseMessaging.onMessage.listen((message) async {
      await LocalNotificationService.showFromRemoteMessage(message);
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
