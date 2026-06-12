import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'models/vehiculo.dart';

class LocalDb {
  static Database? _db;

  static const syncPending = 'PENDIENTE';
  static const syncError = 'ERROR';
  static const syncSynced = 'SINCRONIZADO';

  static Future<Database> get db async => _db ??= await _open();

  static Future<Database> _open() async {
    final dbPath = join(await getDatabasesPath(), 'emergencias.db');
    return openDatabase(
      dbPath,
      version: 2,
      onCreate: (database, version) async {
        await _createIncidenteTable(database);
        await _createVehiculoCacheTable(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createVehiculoCacheTable(database);
        }
      },
    );
  }

  static Future<void> _createIncidenteTable(Database database) async {
    await database.execute('''
      CREATE TABLE incidente_local(
        id_local TEXT PRIMARY KEY,
        vehiculo_id TEXT,
        descripcion TEXT,
        latitud REAL,
        longitud REAL,
        direccion TEXT,
        evidencias TEXT,
        estado_sync TEXT DEFAULT 'PENDIENTE',
        id_servidor TEXT,
        client_created_at TEXT,
        client_updated_at TEXT
      )''');
  }

  static Future<void> _createVehiculoCacheTable(Database database) async {
    await database.execute('''
      CREATE TABLE vehiculo_cache(
        id TEXT PRIMARY KEY,
        placa TEXT NOT NULL,
        marca TEXT,
        modelo TEXT,
        anio INTEGER,
        color TEXT,
        tipo_combustible TEXT,
        cached_at TEXT
      )''');
  }

  static Future<void> insertPending(Map<String, dynamic> row) async {
    final database = await db;
    await database.insert(
      'incidente_local',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Incidentes pendientes de envío o con error reintentable.
  static Future<List<Map<String, dynamic>>> pending() async {
    final database = await db;
    return database.query(
      'incidente_local',
      where: "estado_sync IN ('PENDIENTE', 'ERROR')",
      orderBy: 'client_created_at ASC',
    );
  }

  static Future<Map<String, dynamic>?> getByIdLocal(String idLocal) async {
    final database = await db;
    final rows = await database.query(
      'incidente_local',
      where: 'id_local = ?',
      whereArgs: [idLocal],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  static Future<List<Map<String, dynamic>>> allLocal() async {
    final database = await db;
    return database.query(
      'incidente_local',
      orderBy: 'client_created_at DESC',
    );
  }

  static Future<void> markSynced(String idLocal, String idServidor) async {
    final database = await db;
    await database.update(
      'incidente_local',
      {
        'estado_sync': syncSynced,
        'id_servidor': idServidor,
      },
      where: 'id_local = ?',
      whereArgs: [idLocal],
    );
  }

  static Future<void> markError(String idLocal) async {
    final database = await db;
    await database.update(
      'incidente_local',
      {'estado_sync': syncError},
      where: 'id_local = ?',
      whereArgs: [idLocal],
    );
  }

  static Future<void> resetToPending(String idLocal) async {
    final database = await db;
    await database.update(
      'incidente_local',
      {'estado_sync': syncPending},
      where: 'id_local = ?',
      whereArgs: [idLocal],
    );
  }

  static Future<void> cacheVehiculos(List<Vehiculo> vehiculos) async {
    final database = await db;
    final now = DateTime.now().toUtc().toIso8601String();
    final batch = database.batch();
    batch.delete('vehiculo_cache');
    for (final v in vehiculos) {
      batch.insert('vehiculo_cache', {
        'id': v.id,
        'placa': v.placa,
        'marca': v.marca,
        'modelo': v.modelo,
        'anio': v.anio,
        'color': v.color,
        'tipo_combustible': v.tipoCombustible,
        'cached_at': now,
      });
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Vehiculo>> vehiculosCached() async {
    final database = await db;
    final rows = await database.query(
      'vehiculo_cache',
      orderBy: 'placa ASC',
    );
    return rows
        .map(
          (r) => Vehiculo(
            id: r['id'] as String,
            placa: r['placa'] as String,
            marca: r['marca'] as String?,
            modelo: r['modelo'] as String?,
            anio: r['anio'] as int?,
            color: r['color'] as String?,
            tipoCombustible: r['tipo_combustible'] as String?,
          ),
        )
        .toList();
  }

  static List<Map<String, dynamic>> decodeEvidencias(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
