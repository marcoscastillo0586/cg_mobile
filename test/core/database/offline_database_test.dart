import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/database/app_local_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AppLocalDatabase Offline-First Integration Tests', () {
    test('Genera UUID v4 válido como sync_id maestro de sincronización', () {
      final syncId1 = AppLocalDatabase.generateUuid();
      final syncId2 = AppLocalDatabase.generateUuid();

      expect(syncId1, isNotEmpty);
      expect(syncId2, isNotEmpty);
      expect(syncId1, isNot(equals(syncId2)));
      expect(syncId1.length, equals(36)); // Formato UUID v4 estándar
    });

    test('Crea las tablas locales en SQLite con columnas de sincronización', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
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
        },
      );

      final syncId = AppLocalDatabase.generateUuid();
      final now = DateTime.now().toUtc().toIso8601String();

      await db.insert('categorias_local', {
        'sync_id': syncId,
        'remote_id': null,
        'nombre': 'Supermercado Offline',
        'estado': 1,
        'sync_status': 'pending_create',
        'created_at': now,
        'updated_at': now,
      });

      final rows = await db.query('categorias_local', where: 'sync_id = ?', whereArgs: [syncId]);
      expect(rows.length, equals(1));
      expect(rows.first['nombre'], equals('Supermercado Offline'));
      expect(rows.first['sync_status'], equals('pending_create'));

      await db.close();
    });
  });
}
