import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDb {
  static Database? _db;

  static Future<Database> get db async => _db ??= await _open();

  static Future<Database> _open() async {
    final dbPath = join(await getDatabasesPath(), 'emergencias.db');
    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (database, version) async {
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
      },
    );
  }

  static Future<void> insertPending(Map<String, dynamic> row) async {
    final database = await db;
    await database.insert(
      'incidente_local',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Map<String, dynamic>>> pending() async {
    final database = await db;
    return database.query(
      'incidente_local',
      where: "estado_sync = 'PENDIENTE'",
    );
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
        'estado_sync': 'SINCRONIZADO',
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
      {'estado_sync': 'ERROR'},
      where: 'id_local = ?',
      whereArgs: [idLocal],
    );
  }
}
