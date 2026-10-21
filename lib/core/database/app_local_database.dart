import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

class AppLocalDatabase {
  static const String _dbName = 'gastos_offline.db';
  static const int _dbVersion = 1;

  static Database? _database;
  static const _uuid = Uuid();

  static String generateUuid() => _uuid.v4();

  static Future<Database> get instance async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite no está soportado en Web directamente');
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final Directory docDir = await getApplicationDocumentsDirectory();
    final String path = p.join(docDir.path, _dbName);
    final bool exists = File(path).existsSync();
    final int size = exists ? File(path).lengthSync() : 0;

    if (kDebugMode) {
      debugPrint('[SYNC-DEBUG] [DB-OPEN] Ruta DB: $path | Existe previa: $exists | Tamaño: $size bytes | Versión: $_dbVersion');
    }

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        if (kDebugMode) {
          debugPrint('[SYNC-DEBUG] [DB-ONCREATE] Creando tablas locales en SQLite v$version...');
        }
        await _onCreate(db, version);
      },
    );
  }

  static FutureOr<void> _onCreate(Database db, int version) async {
    // 1. Tabla Categorías
    await db.execute('''
      CREATE TABLE categorias_local (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sync_id TEXT UNIQUE NOT NULL,
        remote_id INTEGER,
        nombre TEXT NOT NULL,
        estado INTEGER NOT NULL DEFAULT 1,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 2. Tabla Lugares / Cuentas con soporte para saldo original, pesos, cotización e imágenes
    await db.execute('''
      CREATE TABLE lugares_local (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sync_id TEXT UNIQUE NOT NULL,
        remote_id INTEGER,
        nombre TEXT NOT NULL,
        tipo_moneda INTEGER NOT NULL DEFAULT 1,
        simbolo_moneda TEXT NOT NULL DEFAULT '\$',
        monto_original REAL NOT NULL DEFAULT 0.0,
        monto_pesos REAL NOT NULL DEFAULT 0.0,
        cotizacion REAL NOT NULL DEFAULT 1.0,
        saldo_actual REAL NOT NULL DEFAULT 0.0,
        estado INTEGER NOT NULL DEFAULT 1,
        img_url TEXT,
        img_base64 TEXT,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 3. Tabla Límites de Gastos
    await db.execute('''
      CREATE TABLE limites_local (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sync_id TEXT UNIQUE NOT NULL,
        remote_id INTEGER,
        categoria_sync_id TEXT,
        categoria_remote_id INTEGER,
        monto_limite REAL NOT NULL,
        periodo TEXT NOT NULL DEFAULT 'mensual',
        sync_status TEXT NOT NULL DEFAULT 'synced',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 4. Tabla Movimiento Encabezado
    await db.execute('''
      CREATE TABLE movimiento_enc_local (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sync_id TEXT UNIQUE NOT NULL,
        remote_id INTEGER,
        tipo_movimiento INTEGER NOT NULL DEFAULT 2,
        concepto_general TEXT NOT NULL,
        fecha_movimiento TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 5. Tabla Movimiento Detalle / Renglones
    await db.execute('''
      CREATE TABLE movimiento_det_local (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sync_id TEXT UNIQUE NOT NULL,
        remote_id INTEGER,
        movimiento_enc_sync_id TEXT NOT NULL,
        lugar_sync_id TEXT,
        lugar_remote_id INTEGER,
        categoria_sync_id TEXT,
        categoria_remote_id INTEGER,
        concepto TEXT NOT NULL,
        monto REAL NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (movimiento_enc_sync_id) REFERENCES movimiento_enc_local(sync_id) ON DELETE CASCADE
      )
    ''');


    await db.execute('CREATE INDEX idx_cat_sync ON categorias_local(sync_id, remote_id);');
    await db.execute('CREATE INDEX idx_lug_sync ON lugares_local(sync_id, remote_id);');
    await db.execute('CREATE INDEX idx_mov_enc_sync ON movimiento_enc_local(sync_id, remote_id);');
    await db.execute('CREATE INDEX idx_mov_det_enc ON movimiento_det_local(movimiento_enc_sync_id);');
  }
}
