import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../core/dio_client.dart';
import '../data/local_db.dart';

class SyncService {
  static void start() {
    Connectivity().onConnectivityChanged.listen((results) {
      if (_isOnline(results)) syncNow();
    });
  }

  static bool _isOnline(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  static Future<bool> hasConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    return _isOnline(results);
  }

  static Future<int> syncNow() async {
    final pend = await LocalDb.pending();
    if (pend.isEmpty) return 0;

    final body = {
      'dispositivo': 'flutter-android',
      'incidentes': pend.map((p) {
        return {
          'external_id': p['id_local'],
          'vehiculo_id': p['vehiculo_id'],
          'descripcion': p['descripcion'],
          'latitud': p['latitud'],
          'longitud': p['longitud'],
          'direccion': p['direccion'],
          'client_created_at': p['client_created_at'],
          'client_updated_at': p['client_updated_at'],
          'evidencias': jsonDecode(p['evidencias'] as String? ?? '[]'),
        };
      }).toList(),
    };

    try {
      final res = await buildDio().post<Map<String, dynamic>>(
        '/sync',
        data: body,
      );
      final results = res.data?['results'] as List<dynamic>? ?? [];
      var synced = 0;
      for (final item in results) {
        final map = item as Map<String, dynamic>;
        await LocalDb.markSynced(
          map['external_id'] as String,
          map['incidente_id'] as String,
        );
        synced++;
      }
      return synced;
    } catch (_) {
      return 0;
    }
  }
}
