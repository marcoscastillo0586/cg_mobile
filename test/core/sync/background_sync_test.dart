// Reglas de la sincronización en segundo plano sin servidor ni WorkManager. Que corra de verdad con la
// app cerrada (almacenamiento seguro, plugins en otro isolate) se prueba en el celular.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/auth/current_account.dart';
import 'package:gastos_mobile/core/auth/session_manager.dart';
import 'package:gastos_mobile/core/dashboards/current_dashboard.dart';
import 'package:gastos_mobile/core/database/local_database.dart';
import 'package:gastos_mobile/core/network/dio_client.dart';
import 'package:gastos_mobile/core/dashboards/dashboard_switch.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/core/money/money.dart';
import 'package:gastos_mobile/core/storage/secure_storage_service.dart';
import 'package:gastos_mobile/core/sync/background_sync.dart';
import 'package:gastos_mobile/core/sync/outbox.dart';
import 'package:gastos_mobile/core/sync/sync_controller.dart';
import 'package:gastos_mobile/features/accounts_admin/data/local_accounts_repository.dart';
import 'package:gastos_mobile/features/movements/data/local_movement_writer.dart';
import 'package:path/path.dart' as p;
import '../../helpers/local_seed.dart';

class _MemoryTokens implements RefreshTokenStorage {
  String? token = 'r1';

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String t) async => token = t;

  @override
  Future<void> delete() async => token = null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => DashboardSwitch.keepLocalData = false);

  group('resultado de la tarea', () {
    BackgroundSyncOutcome of(SyncStatus status, [Object? error]) => BackgroundSync.outcomeOf(SyncState(status: status, error: error));

    test('sin conexión o error pasajero: se reintenta', () {
      expect(of(SyncStatus.offline), BackgroundSyncOutcome.retryLater);
      expect(of(SyncStatus.error, StateError('x')), BackgroundSyncOutcome.retryLater);
    });

    test('sesión vencida: termina sin reintentar', () {
      expect(of(SyncStatus.error, const SessionExpiredException()), BackgroundSyncOutcome.done);
    });

    test('completa, rechazadas o diferencias: termina sin reintentar', () {
      for (final s in [SyncStatus.complete, SyncStatus.attention, SyncStatus.mismatch]) {
        expect(of(s), BackgroundSyncOutcome.done);
      }
    });
  });

  test('el envío reintenta si falla; la periódica espera su próximo ciclo', () {
    expect(BackgroundSync.taskSucceeded(BackgroundSync.sendTask, BackgroundSyncOutcome.retryLater), isFalse);
    expect(BackgroundSync.taskSucceeded(BackgroundSync.sendTask, BackgroundSyncOutcome.done), isTrue);
    expect(BackgroundSync.taskSucceeded(BackgroundSync.periodicTask, BackgroundSyncOutcome.retryLater), isTrue);
  });

  test('el token no se borra en segundo plano, pero sí se guarda el nuevo', () async {
    final tokens = _MemoryTokens();
    final storage = KeepTokenStorage(tokens);
    await storage.delete();
    expect(await storage.read(), 'r1');
    await storage.write('r2');
    expect(tokens.token, 'r2');
  });

  test('sin sesión guardada no hace nada', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final outcome = await BackgroundSync.run(overrides: [
      secureStorageServiceProvider.overrideWithValue(SecureStorageService(const FlutterSecureStorage())),
    ]);
    expect(outcome, BackgroundSyncOutcome.nothingToDo);
  });

  test('cada operación encolada avisa para programar el envío', () async {
    final s = await seededDb();
    addTearDown(s.db.close);
    var notices = 0;
    Outbox.onEnqueued = () => notices++;
    addTearDown(() => Outbox.onEnqueued = null);
    await LocalAccountsRepository(s.db).create(name: 'Nueva', currency: Currency.ars);
    expect(notices, 1);
  });

  test('en segundo plano no se borra la base de un dashboard sin acceso', () async {
    DashboardSwitch.keepLocalData = true;
    await expectLater(DashboardSwitch.lost(99), completes); // sin cuenta conectada, borrarla fallaría
  });

  group('tarea con sesión guardada', () {
    late SeededDb s;
    late Directory dir;
    setUp(() async {
      s = await seededDb();
      dir = Directory.systemTemp.createTempSync('cg_bg');
      LocalDatabase.documentsDirectory = () async => dir;
      FlutterSecureStorage.setMockInitialValues({
        'auth_refresh_token': 'r1',
        'auth_user': jsonEncode({'id': 7, 'name': 'Ana', 'email': 'a@b.c'}),
        'current_dashboard': '3:9', // elección de otro usuario
      });
    });
    tearDown(() async {
      CurrentAccount.id = null;
      CurrentDashboard.id.value = null;
      await s.db.close();
      dir.deleteSync(recursive: true);
    });

    Future<BackgroundSyncOutcome> run({bool onlyIfPending = false}) => BackgroundSync.run(onlyIfPending: onlyIfPending, overrides: [
          secureStorageServiceProvider.overrideWithValue(SecureStorageService(const FlutterSecureStorage())),
          localDatabaseProvider.overrideWithValue(Future.value(s.db)),
          dioClientProvider.overrideWithValue(DioClient(adapter: _TemporaryError())..dio.options.baseUrl = 'http://api.fake/api/v1'),
        ]);

    test('sin base local de la cuenta no sigue (la primera descarga es de la app abierta)', () async {
      expect(await run(), BackgroundSyncOutcome.nothingToDo);
      expect(CurrentAccount.id, 7);
      expect(CurrentDashboard.id.value, isNull); // la elección guardada era de otro usuario
    });

    test('con la cola vacía y sólo lo pendiente: termina sin usar la red', () async {
      File(p.join(dir.path, 'cg_u7.db')).writeAsStringSync('');
      expect(await run(onlyIfPending: true), BackgroundSyncOutcome.nothingToDo);
    });

    test('pedido de la tarea con la app viva: usa el contenedor de la app y sus reglas', () async {
      expect(await BackgroundSync.syncForTask(false), BackgroundSyncOutcome.nothingToDo); // sin app viva
      final container = ProviderContainer(overrides: [
        localDatabaseProvider.overrideWithValue(Future.value(s.db)),
        dioClientProvider.overrideWithValue(DioClient(adapter: _TemporaryError())..dio.options.baseUrl = 'http://api.fake/api/v1'),
      ]);
      addTearDown(() {
        BackgroundSync.appContainer = null;
        container.dispose();
      });
      BackgroundSync.appContainer = container;
      expect(await BackgroundSync.syncForTask(false), BackgroundSyncOutcome.nothingToDo); // sin cuenta conectada
      CurrentAccount.id = 7;
      expect(await BackgroundSync.syncForTask(true), BackgroundSyncOutcome.nothingToDo); // cola vacía
      await (await s.writer).createIncome(IncomeDraft(accountLocalId: s.accounts['Banco']!, date: DateTime(2026, 10, 21), concept: 'x', amountCents: 1));
      expect(await BackgroundSync.syncForTask(true), BackgroundSyncOutcome.retryLater);
    });

    test('con algo pendiente sincroniza; un error temporal del servidor pide reintentar', () async {
      File(p.join(dir.path, 'cg_u7.db')).writeAsStringSync('');
      await (await s.writer).createIncome(IncomeDraft(accountLocalId: s.accounts['Banco']!, date: DateTime(2026, 10, 21), concept: 'x', amountCents: 1));
      expect(await run(onlyIfPending: true), BackgroundSyncOutcome.retryLater);
      expect(await s.count('outbox', "status = 'pending'"), 1);
    });
  });
}

/// El servidor responde a todo con un error temporal.
class _TemporaryError implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async =>
      ResponseBody.fromString(jsonEncode({'statusCode': 503, 'code': 'TEMPORARY_ERROR', 'message': 'x'}), 503,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

  @override
  void close({bool force = false}) {}
}
