// Reglas de la sincronización en segundo plano sin servidor ni WorkManager. Que corra de verdad con la
// app cerrada (almacenamiento seguro, plugins en otro isolate) se prueba en el celular.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/auth/session_manager.dart';
import 'package:gastos_mobile/core/dashboards/dashboard_switch.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/core/money/money.dart';
import 'package:gastos_mobile/core/storage/secure_storage_service.dart';
import 'package:gastos_mobile/core/sync/background_sync.dart';
import 'package:gastos_mobile/core/sync/outbox.dart';
import 'package:gastos_mobile/core/sync/sync_controller.dart';
import 'package:gastos_mobile/features/accounts_admin/data/local_accounts_repository.dart';
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
}
