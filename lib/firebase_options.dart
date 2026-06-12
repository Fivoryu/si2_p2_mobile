import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Configuración de Firebase (proyecto **si2-p2-862ad**).
class DefaultFirebaseOptions {
  /// Web: pasa `--dart-define=FIREBASE_WEB_APP_ID=1:904373067369:web:...`
  /// al registrar la app web en Firebase Console.
  static FirebaseOptions? get webOrNull {
    const appId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
    if (appId.isEmpty) return null;
    return const FirebaseOptions(
      apiKey: 'AIzaSyCBZBjw2nP80g7TM9yCfmPp-fkz6sTbjf8',
      appId: appId,
      messagingSenderId: '904373067369',
      projectId: 'si2-p2-862ad',
      authDomain: 'si2-p2-862ad.firebaseapp.com',
      storageBucket: 'si2-p2-862ad.firebasestorage.app',
    );
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      final web = webOrNull;
      if (web != null) return web;
      throw UnsupportedError(
        'Firebase web no configurado. Registra una app Web en Firebase y ejecuta '
        'con --dart-define=FIREBASE_WEB_APP_ID=1:904373067369:web:XXXX',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions no están configuradas para iOS.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions no soportan esta plataforma.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCBZBjw2nP80g7TM9yCfmPp-fkz6sTbjf8',
    appId: '1:904373067369:android:4941b507839bc4bd844cf8',
    messagingSenderId: '904373067369',
    projectId: 'si2-p2-862ad',
    storageBucket: 'si2-p2-862ad.firebasestorage.app',
  );
}
