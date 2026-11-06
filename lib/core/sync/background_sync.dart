import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';
import '../../features/auth/data/models/user_model.dart';
import '../auth/current_account.dart';
import '../auth/session_manager.dart';
import '../auth/session_providers.dart';
import '../dashboards/current_dashboard.dart';
import '../dashboards/dashboard_switch.dart';
import '../database/local_database.dart';
import '../errors/exceptions.dart';
import '../network/dio_client.dart';
import '../storage/secure_storage_service.dart';
import 'outbox.dart';
import 'sync_controller.dart';
import 'sync_coordinator.dart';

export 'sync_coordinator.dart' show BackgroundSyncOutcome;

/// Entrada de WorkManager: corre en un isolate propio, sin pasar por `main()`.
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  // Igual que main(): en release no se escribe nada en logcat.
  if (kReleaseMode) debugPrint = (String? message, {int? wrapWidth}) {};
  // En este isolate no corre el registro automático: lo necesita path_provider para encontrar la base.
  DartPluginRegistrant.ensureInitialized();
  Workmanager().executeTask(
    (task, input) async {
      final onlyIfPending = task == BackgroundSync.sendTask;
      final outcome = await SyncCoordinator.runTask(
        onlyIfPending: onlyIfPending,
        work: (isStopped) => BackgroundSync.run(onlyIfPending: onlyIfPending, isStopped: isStopped),
      );
      return BackgroundSync.taskSucceeded(task, outcome);
    },
    onTaskStopped: (task, reason) => SyncCoordinator.taskStoppedByPlatform(),
  );
}

/// Sincronización sin la app abierta: usa el mismo [SyncController] que el primer plano (push, pull,
/// cursor y conflictos) y nunca muestra nada ni borra datos ni la sesión.
class BackgroundSync {
  BackgroundSync._();

  /// Envío de lo pendiente apenas haya conexión. El nombre fijo evita tareas duplicadas.
  static const sendTask = 'cg.sync.send';

  /// Envío de lo pendiente y descarga de los cambios del servidor (p. ej. los hechos en la web).
  static const periodicTask = 'cg.sync.periodic';

  /// El mínimo que permite Android; el sistema puede demorarla más.
  static const _periodicEvery = Duration(minutes: 15);

  /// Da tiempo a que el envío inmediato de la app (`sendNow`) lo resuelva, sin levantar la tarea.
  static const _sendDelay = Duration(minutes: 1);

  /// Primera espera entre reintentos; Android la duplica en cada uno, hasta 5 horas.
  static const _retryDelay = Duration(minutes: 1);

  /// Contenedor de la app viva, para sincronizar a pedido de una tarea. Lo fija [SessionScope].
  static ProviderContainer? appContainer;

  /// Una vez al arrancar la app, antes de abrir la base o la sesión.
  static Future<void> initialize() async {
    try {
      await SyncCoordinator.startApp(_syncForTask);
      await Workmanager().initialize(backgroundSyncDispatcher);
      Outbox.onEnqueued = scheduleSend;
      // keep: abrir la app no reinicia el ciclo.
      await Workmanager().registerPeriodicTask(
        periodicTask,
        periodicTask,
        frequency: _periodicEvery,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (e) {
      // Sin tareas de fondo la app sigue sincronizando como siempre mientras está abierta.
      debugPrint('[SYNC] No se pudieron iniciar las tareas en segundo plano: $e');
    }
  }

  /// Programa el envío de lo pendiente. No se espera ni falla: la operación ya está en la cola.
  static void scheduleSend() {
    unawaited(Workmanager()
        .registerOneOffTask(
      sendTask,
      sendTask,
      initialDelay: _sendDelay,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: _retryDelay,
    )
        .catchError((Object e) {
      debugPrint('[SYNC] No se pudo programar el envío en segundo plano: $e');
    }));
  }

  /// Lo que se le responde a Android; false = reintenta con espera creciente. La periódica no
  /// reintenta: si falla, espera su próximo ciclo.
  @visibleForTesting
  static bool taskSucceeded(String task, BackgroundSyncOutcome outcome) =>
      task == periodicTask || outcome != BackgroundSyncOutcome.retryLater;

  /// Pedido de una tarea con la app viva: la misma sincronización de siempre, con sus bloqueos.
  static Future<BackgroundSyncOutcome> _syncForTask(bool onlyIfPending) async {
    final container = appContainer;
    if (container == null || CurrentAccount.id == null) return BackgroundSyncOutcome.nothingToDo;
    if (onlyIfPending && await Outbox.pendingCount(await container.read(localDatabaseProvider)) == 0) {
      return BackgroundSyncOutcome.nothingToDo;
    }
    await container.read(syncControllerProvider.notifier).sync();
    return outcomeOf(container.read(syncControllerProvider));
  }

  /// Con [onlyIfPending], si la cola está vacía termina sin usar la red. Cuando [isStopped] da true no
  /// empieza más peticiones: lo no enviado sigue en la cola y lo retoma la app.
  static Future<BackgroundSyncOutcome> run({
    bool onlyIfPending = false,
    bool Function()? isStopped,
    List<Override> overrides = const [],
  }) async {
    // Lo que el primer plano resuelve al perder el acceso a un dashboard queda para cuando se abra la app.
    DashboardSwitch.keepLocalData = true;
    final container = ProviderContainer(overrides: [_sessionWithoutDeletes, ...overrides]);
    try {
      // Va primero para frenar también la renovación de la sesión que hace AuthInterceptor.
      if (isStopped != null) container.read(dioClientProvider).dio.interceptors.insert(0, _StopInterceptor(isStopped));
      if (!await _prepareAccount(container.read(secureStorageServiceProvider))) return BackgroundSyncOutcome.nothingToDo;
      if (onlyIfPending && await Outbox.pendingCount(await container.read(localDatabaseProvider)) == 0) {
        return BackgroundSyncOutcome.nothingToDo;
      }
      await container.read(syncControllerProvider.notifier).sync();
      return outcomeOf(container.read(syncControllerProvider));
    } catch (e) {
      debugPrint('[SYNC] Falló la sincronización en segundo plano: $e');
      return BackgroundSyncOutcome.retryLater;
    } finally {
      container.dispose();
      await LocalDatabase.close();
    }
  }

  /// Carga la cuenta y el dashboard que en primer plano fijan [SessionScope] y el inicio de sesión.
  /// Si la base local no existe no se sigue: crearla acá evitaría adoptar después los archivos de
  /// antes de separar por cuenta, y la primera descarga completa le toca a la app abierta.
  static Future<bool> _prepareAccount(SecureStorageService storage) async {
    if (await storage.getRefreshToken() == null) return false;
    final raw = await storage.getUserJson();
    if (raw == null || raw.isEmpty) return false;
    final user = UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>).idUsuario;
    // La elección guardada era de otro usuario: vale su principal, como en SessionScope.
    final owner = await CurrentDashboard.restore();
    if (owner != user) CurrentDashboard.id.value = null;
    CurrentAccount.id = user;
    return File(await LocalDatabase.pathFor(user, CurrentDashboard.id.value)).exists();
  }

  @visibleForTesting
  static BackgroundSyncOutcome outcomeOf(SyncState state) => switch (state.status) {
        SyncStatus.offline => BackgroundSyncOutcome.retryLater,
        // Sesión vencida o rechazada: reintentar no la arregla; se resuelve al abrir la app.
        SyncStatus.error when state.error is AuthException => BackgroundSyncOutcome.done,
        SyncStatus.error => BackgroundSyncOutcome.retryLater,
        _ => BackgroundSyncOutcome.done,
      };

  static final _sessionWithoutDeletes = sessionManagerProvider.overrideWith((ref) {
    final manager = SessionManager(
      authDio: DioClient.createDio(),
      storage: KeepTokenStorage(SecureRefreshTokenStorage(ref.watch(secureStorageServiceProvider))),
    );
    ref.onDispose(manager.dispose);
    return manager;
  });
}

/// Rechaza las peticiones nuevas después del aviso de parar; llega como un corte de red: lo que no
/// se confirmó queda en la cola con el mismo `opId`.
class _StopInterceptor extends Interceptor {
  final bool Function() _isStopped;
  _StopInterceptor(this._isStopped);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_isStopped()) return handler.reject(DioException(requestOptions: options, type: DioExceptionType.cancel));
    handler.next(options);
  }
}

/// Si la sesión no se puede renovar, [SessionManager] borra el token. En segundo plano no se borra
/// nada: al abrir la app, el refresh falla y se comporta como siempre.
@visibleForTesting
class KeepTokenStorage implements RefreshTokenStorage {
  final RefreshTokenStorage _inner;
  KeepTokenStorage(this._inner);

  @override
  Future<String?> read() => _inner.read();

  @override
  Future<void> write(String token) => _inner.write(token);

  @override
  Future<void> delete() async {}
}
