import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import '../core/api_errors.dart';
import '../core/dio_client.dart';
import '../data/local_db.dart';

class SyncService {
  static const maxBatchSize = 20;
  static const maxEvidencias = 6;

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

  static Map<String, dynamic> _rowToPayload(Map<String, dynamic> p) {
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
  }

  static Future<int> _postBatch(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return 0;

    final body = {
      'dispositivo': 'flutter-android',
      'incidentes': rows.map(_rowToPayload).toList(),
    };

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
  }

  /// Returns synced count, or throws with [messageFromDio] message on failure.
  static Future<int> syncNow() async {
    final pend = await LocalDb.pending();
    if (pend.isEmpty) return 0;

    var totalSynced = 0;
    for (var i = 0; i < pend.length; i += maxBatchSize) {
      final batch = pend.sublist(
        i,
        i + maxBatchSize > pend.length ? pend.length : i + maxBatchSize,
      );
      final ids = batch.map((p) => p['id_local'] as String).toList();
      try {
        totalSynced += await _postBatch(batch);
      } on DioException catch (e) {
        for (final id in ids) {
          await LocalDb.markError(id);
        }
        throw Exception(messageFromDio(e));
      } catch (e) {
        for (final id in ids) {
          await LocalDb.markError(id);
        }
        rethrow;
      }
    }
    return totalSynced;
  }

  /// Reintenta un incidente local por [idLocal]. Devuelve true si quedó sincronizado.
  static Future<bool> syncOne(String idLocal) async {
    final row = await LocalDb.getByIdLocal(idLocal);
    if (row == null) return false;
    if (row['estado_sync'] == LocalDb.syncSynced) return true;

    if (row['estado_sync'] == LocalDb.syncError) {
      await LocalDb.resetToPending(idLocal);
    }

    try {
      final synced = await _postBatch([row]);
      return synced > 0;
    } on DioException catch (e) {
      await LocalDb.markError(idLocal);
      throw Exception(messageFromDio(e));
    } catch (e) {
      await LocalDb.markError(idLocal);
      rethrow;
    }
  }
}
