import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../auth/current_account.dart';
import '../dashboards/current_dashboard.dart';
import 'migrations.dart';

/// Base local de un dashboard de una cuenta: copia de sus datos del servidor más su cola de
/// operaciones pendientes. Una base por cuenta y por dashboard: `cg_u<usuario>.db` el principal y
/// `cg_u<usuario>_d<dashboard>.db` los compartidos. Así nunca se mezclan cuentas ni dashboards, y
/// cerrar sesión no borra nada: al volver, la cuenta encuentra sus datos y sus pendientes.
/// Ver `migrations.dart` para el esquema.
class LocalDatabase {
  LocalDatabase._();

  /// Archivos de antes de separar por cuenta (`cg_local.db`, `cg_local_<dashboard>.db`).
  static final _legacyFile = RegExp(r'^cg_local(?:_(\d+))?\.db(-journal|-wal|-shm)?$');

  static const _uuid = Uuid();
  static String newId() => _uuid.v4();

  /// Id fijo derivado de [name] (UUID v5): el mismo ticket QR genera siempre el mismo clientSyncId.
  static String idFor(String name) => _uuid.v5(Namespace.url.value, name);

  /// Base abierta y de qué cuenta y dashboard (`usuario:dashboard`). Solo una abierta a la vez.
  static Future<Database>? _current;
  static String? _currentFor;

  /// Base de la cuenta conectada ([CurrentAccount]) y del dashboard elegido ([CurrentDashboard]);
  /// si había otra abierta, la cierra antes.
  static Future<Database> get instance {
    final user = CurrentAccount.requireId();
    final dashboard = CurrentDashboard.id.value;
    final want = '$user:${dashboard ?? ''}';
    final current = _current;
    if (current != null && _currentFor == want) return current;
    _currentFor = want;
    return _current = () async {
      await _close(current);
      return open(path: await pathFor(user, dashboard));
    }();
  }

  /// Archivo de la base de una cuenta y un dashboard (null = el principal de la cuenta).
  static Future<String> pathFor(int userId, int? dashboardId) async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, dashboardId == null ? 'cg_u$userId.db' : 'cg_u${userId}_d$dashboardId.db');
  }

  /// Una sola vez, al pasar a una base por cuenta: los archivos de antes pasan a ser de [ownerId]
  /// (el dueño registrado). No pisa archivos que ya existan.
  static Future<void> adoptLegacyFiles(int ownerId) async {
    final dir = await getApplicationDocumentsDirectory();
    for (final file in Directory(dir.path).listSync().whereType<File>()) {
      final m = _legacyFile.firstMatch(p.basename(file.path));
      if (m == null) continue;
      final dashboard = m.group(1) == null ? null : int.parse(m.group(1)!);
      final target = '${await pathFor(ownerId, dashboard)}${m.group(2) ?? ''}';
      if (await File(target).exists()) {
        debugPrint('[DB] No se adopta ${p.basename(file.path)}: ya existe ${p.basename(target)}');
        continue;
      }
      await file.rename(target);
      debugPrint('[DB] ${p.basename(file.path)} → ${p.basename(target)} (cuenta $ownerId)');
    }
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

  /// Borra la base local de un dashboard de la cuenta conectada (se perdió el acceso o se eliminó).
  static Future<void> deleteFor(int dashboardId) async {
    final user = CurrentAccount.requireId();
    if (_currentFor == '$user:$dashboardId') await close();
    final path = await pathFor(user, dashboardId);
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
}

/// Base local abierta (creada o migrada). El provider guarda el Future: al cambiar de sesión o de
/// dashboard [SessionScope] descarta el contenedor entero y el nuevo vuelve a abrir la base con `instance`.
/// Un error de apertura llega a quien la usa.
final localDatabaseProvider = Provider<Future<Database>>((ref) => LocalDatabase.instance);
