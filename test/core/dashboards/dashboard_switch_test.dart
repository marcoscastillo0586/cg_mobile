// Cambio de dashboard y pérdida de acceso: elección guardada, base local cerrada o borrada y aviso, con
// almacenamiento seguro SIMULADO y SQLite REAL (ffi) en una carpeta temporal.
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/auth/current_account.dart';
import 'package:gastos_mobile/core/dashboards/current_dashboard.dart';
import 'package:gastos_mobile/core/dashboards/dashboard_switch.dart';
import 'package:gastos_mobile/core/database/local_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory dir;
  bool exists(String name) => File(p.join(dir.path, name)).existsSync();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('cg_switch');
    LocalDatabase.documentsDirectory = () async => dir;
    CurrentAccount.id = 5;
    DashboardSwitch.userId = 5;
  });
  tearDown(() async {
    await LocalDatabase.close();
    CurrentAccount.id = null;
    CurrentDashboard.id.value = null;
    CurrentDashboard.notice.value = null;
    DashboardSwitch.userId = null;
    DashboardSwitch.keepLocalData = false;
    dir.deleteSync(recursive: true);
  });

  test('elegir otro dashboard cierra la base del anterior y guarda la elección a nombre del usuario', () async {
    final principal = await LocalDatabase.instance;
    await DashboardSwitch.select(9);
    expect(CurrentDashboard.id.value, 9);
    expect(principal.isOpen, isFalse);
    CurrentDashboard.id.value = null;
    expect(await CurrentDashboard.restore(), 5);
    expect(CurrentDashboard.id.value, 9);
  });

  test('elegir el que ya está no hace nada', () async {
    final principal = await LocalDatabase.instance;
    await DashboardSwitch.select(null);
    expect(principal.isOpen, isTrue);
  });

  test('perder el acceso al elegido: vuelve al principal, borra su base y avisa', () async {
    await DashboardSwitch.select(9);
    await LocalDatabase.instance;
    expect(exists('cg_u5_d9.db'), isTrue);
    await DashboardSwitch.lost(9);
    expect(CurrentDashboard.id.value, isNull);
    expect(exists('cg_u5_d9.db'), isFalse);
    expect(CurrentDashboard.notice.value, CurrentDashboard.accessLost);
  });

  test('perder el acceso a otro: borra su base sin cambiar ni avisar; en segundo plano no se borra nada', () async {
    File(p.join(dir.path, 'cg_u5_d7.db')).writeAsStringSync('');
    DashboardSwitch.keepLocalData = true;
    await DashboardSwitch.lost(7);
    expect(exists('cg_u5_d7.db'), isTrue);
    DashboardSwitch.keepLocalData = false;
    await DashboardSwitch.lost(7);
    expect(exists('cg_u5_d7.db'), isFalse);
    expect(CurrentDashboard.notice.value, isNull);
  });

  test('sin usuario de sesión se cambia igual, sin guardar; sin cuenta conectada borrar falla sin cortar', () async {
    DashboardSwitch.userId = null;
    await DashboardSwitch.select(3);
    expect(CurrentDashboard.id.value, 3);
    expect(await CurrentDashboard.restore(), isNull);
    CurrentAccount.id = null;
    await DashboardSwitch.lost(3);
    expect(CurrentDashboard.id.value, isNull);
  });
}
