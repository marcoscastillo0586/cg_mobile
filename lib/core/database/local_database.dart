import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../dashboards/current_dashboard.dart';
import 'migrations.dart';

/// Base local de un dashboard: copia de sus datos del servidor más su cola de operaciones
/// pendientes. Una base por dashboard: `cg_local.db` el principal del usuario y
/// `cg_local_<id>.db` los demás (dashboards compartidos), así sus datos nunca se mezclan.
/// Ver `migrations.dart` para el esquema.
class LocalDatabase {
  LocalDatabase._();

  static const fileName = 'cg_local.db';

  /// Base del esquema viejo (contrato PHP). No se abre ni se migra: solo se borra al
  /// cerrar sesión, después de haberla revisado.
  static const legacyFileName = 'gastos_offline.db';

  static const _uuid = Uuid();
  static String newId() => _uuid.v4();

  /// Id fijo derivado de [name] (UUID v5): el mismo ticket QR genera siempre el mismo clientSyncId.
  static String idFor(String name) => _uuid.v5(Namespace.url.value, name);

  /// Base abierta y para qué dashboard (null = principal). Solo una abierta a la vez.
  static Future<Database>? _current;
  static int? _currentFor;

  /// Base del dashboard elegido ([CurrentDashboard]); si había otra abierta, la cierra antes.
  static Future<Database> get instance {
    final want = CurrentDashboard.id.value;
    final current = _current;
    if (current != null && _currentFor == want) return current;
    _currentFor = want;
    return _current = () async {
      await _close(current);
      return open(path: await pathFor(want));
    }();
  }

  /// Archivo de la base de un dashboard (null = el principal del usuario).
  static Future<String> pathFor(int? dashboardId) async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, dashboardId == null ? fileName : 'cg_local_$dashboardId.db');
  }

  static Future<void> _close(Future<Database>? db) async {
    if (db == null) return;
    try {
      final open = await db;
      if (open.isOpen) await open.close();
    } catch (e) {
      // Si no había llegado a abrirse, no hay nada que cerrar; el error ya lo vio quien la pidió.
      debugPrint('[DB] La base anterior no estaba abierta: $e');
    }
  }

  /// Cierra la base abierta (antes de cambiar de dashboard o de borrar archivos).
  static Future<void> close() async {
    final current = _current;
    _current = null;
    _currentFor = null;
    await _close(current);
  }

  /// Borra la base local de un dashboard (se perdió el acceso o se eliminó).
  static Future<void> deleteFor(int dashboardId) async {
    if (_currentFor == dashboardId) await close();
    final path = await pathFor(dashboardId);
    if (await File(path).exists() || await databaseExists(path)) await deleteDatabase(path);
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

  /// Cierra y borra las bases locales de todos los dashboards y la base vieja (cierre de sesión).
  static Future<void> deleteAll() async {
    await close();
    final dir = await getApplicationDocumentsDirectory();
    final names = {
      fileName,
      legacyFileName,
      for (final f in Directory(dir.path).listSync().whereType<File>())
        if (RegExp(r'^cg_local_\d+\.db$').hasMatch(p.basename(f.path))) p.basename(f.path),
    };
    for (final name in names) {
      final path = p.join(dir.path, name);
      if (await File(path).exists() || await databaseExists(path)) {
        await deleteDatabase(path);
      }
    }
  }
}

/// Base local abierta (creada o migrada). El provider guarda el Future: tras un cierre de sesión
/// [SessionScope] descarta el contenedor entero y el nuevo vuelve a abrir la base con `instance`.
/// Un error de apertura llega a quien la usa.
final localDatabaseProvider = Provider<Future<Database>>((ref) => LocalDatabase.instance);
