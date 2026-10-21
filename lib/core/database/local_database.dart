import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'migrations.dart';

/// Base local de la app (`cg_local.db`): copia de los datos del servidor más la cola de
/// operaciones pendientes. Ver `migrations.dart` para el esquema.
class LocalDatabase {
  LocalDatabase._();

  static const fileName = 'cg_local.db';

  /// Base del esquema viejo (contrato PHP). No se abre ni se migra: solo se borra al
  /// cerrar sesión, después de haberla revisado.
  static const legacyFileName = 'gastos_offline.db';

  static const _uuid = Uuid();
  static String newId() => _uuid.v4();

  static Database? _db;

  static Future<Database> get instance async => _db ??= await open(path: await _defaultPath());

  static Future<String> _defaultPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, fileName);
  }

  /// Abre (y crea o migra) la base en [path]. [factory] permite usar ffi en tests.
  static Future<Database> open({required String path, DatabaseFactory? factory}) {
    final f = factory ?? databaseFactory;
    return f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: latestSchemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => _migrate(db, 0, version),
        onUpgrade: _migrate,
        onDowngrade: (db, from, to) => throw StateError(
          'La base local es de una versión más nueva ($from) que la app ($to). '
          'Actualizá la app; no se abre para no perder datos.',
        ),
      ),
    );
  }

  /// sqflite corre onCreate/onUpgrade dentro de una transacción: si una migración
  /// falla, la base queda en la versión anterior.
  static Future<void> _migrate(Database db, int from, int to) async {
    for (final m in migrations.where((m) => m.version > from && m.version <= to)) {
      debugPrint('[DB] Migración ${m.version}: ${m.description}');
      for (final sql in m.statements) {
        await db.execute(sql);
      }
    }
  }

  /// Cierra y borra la base local y el archivo de la base vieja (cierre de sesión).
  static Future<void> deleteAll() async {
    final db = _db;
    _db = null;
    if (db != null && db.isOpen) await db.close();
    final dir = await getApplicationDocumentsDirectory();
    for (final name in [fileName, legacyFileName]) {
      final path = p.join(dir.path, name);
      if (await File(path).exists() || await databaseExists(path)) {
        await deleteDatabase(path);
      }
    }
  }
}

/// Base local abierta (creada o migrada). No se guarda el Future en el provider: tras un
/// cierre de sesión la base se cierra y `instance` la vuelve a abrir. Un error de apertura
/// llega a quien la usa.
final localDatabaseProvider = Provider<Future<Database>>((ref) => LocalDatabase.instance);
