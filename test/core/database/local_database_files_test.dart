// Archivos de las bases locales (una por cuenta y dashboard) sobre una carpeta temporal, con SQLite REAL (ffi).
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/auth/current_account.dart';
import 'package:gastos_mobile/core/dashboards/current_dashboard.dart';
import 'package:gastos_mobile/core/database/local_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory dir;
  bool exists(String name) => File(p.join(dir.path, name)).existsSync();
  void touch(String name, [String content = 'x']) => File(p.join(dir.path, name)).writeAsStringSync(content);

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() {
    dir = Directory.systemTemp.createTempSync('cg_files');
    LocalDatabase.documentsDirectory = () async => dir;
  });
  tearDown(() async {
    await LocalDatabase.close();
    CurrentAccount.id = null;
    CurrentDashboard.id.value = null;
    dir.deleteSync(recursive: true);
  });

  test('las bases de antes pasan a la cuenta dueña sin pisar las que ya existen', () async {
    touch('cg_local.db', 'principal');
    touch('cg_local.db-wal');
    touch('cg_local_7.db', 'viejo');
    touch('cg_u5_d7.db', 'nuevo');
    touch('otra.db');
    await LocalDatabase.adoptLegacyFiles(5);
    expect([exists('cg_u5.db'), exists('cg_u5.db-wal'), exists('cg_local.db')], [true, true, false]);
    expect(File(p.join(dir.path, 'cg_u5.db')).readAsStringSync(), 'principal');
    expect([exists('cg_local_7.db'), File(p.join(dir.path, 'cg_u5_d7.db')).readAsStringSync()], [true, 'nuevo']);
    expect(exists('otra.db'), isTrue);
  });

  test('una base por cuenta y dashboard; se reusa mientras no cambie; borrar la de un dashboard la cierra', () async {
    CurrentAccount.id = 5;
    final principal = await LocalDatabase.instance;
    expect(identical(await LocalDatabase.instance, principal), isTrue);
    expect(exists('cg_u5.db'), isTrue);
    CurrentDashboard.id.value = 9;
    final shared = await LocalDatabase.instance;
    expect(exists('cg_u5_d9.db'), isTrue);
    expect(principal.isOpen, isFalse); // al cambiar de dashboard se cierra la anterior
    await LocalDatabase.deleteFor(9);
    expect(shared.isOpen, isFalse);
    expect(exists('cg_u5_d9.db'), isFalse);
    await LocalDatabase.deleteFor(9); // ya no existe: no falla
  });
}
