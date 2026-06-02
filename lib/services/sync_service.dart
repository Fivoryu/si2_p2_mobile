import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import '../core/api_errors.dart';
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

  static List<Map<String, dynamic>> _normalizeEvidencias(List<dynamic> raw) {
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      if (m.containsKey('contenido_base64') && !m.containsKey('contenido_b64')) {
        m['contenido_b64'] = m.remove('contenido_base64');
      }
      if (!m.containsKey('mime_type')) {
        final tipo = m['tipo'] as String? ?? 'IMAGEN';
        m['mime_type'] = tipo == 'AUDIO' ? 'audio/aac' : 'image/jpeg';
      }
      return m;
    }).toList();
  }

  /// Returns synced count, or throws with [messageFromDio] message on failure.
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
          'evidencias': _normalizeEvidencias(
            jsonDecode(p['evidencias'] as String? ?? '[]') as List<dynamic>,
          ),
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
    } on DioException catch (e) {
      for (final p in pend) {
        await LocalDb.markError(p['id_local'] as String);
      }
      throw Exception(messageFromDio(e));
    } catch (e) {
      for (final p in pend) {
        await LocalDb.markError(p['id_local'] as String);
      }
      rethrow;
    }
  }
}
