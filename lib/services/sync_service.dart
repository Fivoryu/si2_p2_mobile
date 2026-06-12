import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import '../core/api_errors.dart';
import '../core/dio_client.dart';
import '../data/local_db.dart';

typedef SyncListener = void Function(int syncedCount);

class SyncService {
  static const maxBatchSize = 20;
  static const maxEvidencias = 6;

  static final List<SyncListener> _listeners = [];

  static void addListener(SyncListener listener) {
    _listeners.add(listener);
  }

  static void _notify(int count) {
    if (count <= 0) return;
    for (final listener in List<SyncListener>.from(_listeners)) {
      listener(count);
    }
  }

  static void start() {
    Connectivity().onConnectivityChanged.listen((results) {
      if (_isOnline(results)) {
        syncNow().then(_notify);
      }
    });
    hasConnectivity().then((online) {
      if (online) syncNow().then(_notify);
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

  /// Devuelve el id de servidor tras sincronizar, o null si sigue pendiente.
  static Future<String?> ensureSynced(String idOrLocal) async {
    final existing = await LocalDb.serverIdFor(idOrLocal);
    if (existing != null && existing != idOrLocal) return existing;
    if (!await LocalDb.needsSync(idOrLocal)) {
      return idOrLocal;
    }
    if (!await hasConnectivity()) return null;
    final ok = await syncOne(idOrLocal);
    if (!ok) return null;
    return LocalDb.serverIdFor(idOrLocal);
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
    _notify(totalSynced);
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
      if (synced > 0) _notify(synced);
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
