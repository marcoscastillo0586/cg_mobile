import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

enum BackgroundSyncOutcome {
  /// Sin sesión, sin base local o sin nada que enviar: no se usó la red ni se creó nada.
  nothingToDo,

  /// La sincronización terminó. Lo rechazado queda en la pantalla de pendientes, sin aviso.
  done,

  /// Sin conexión con el servidor o error pasajero: lo pendiente sigue en la cola.
  retryLater,
}

/// Que la app y una tarea en segundo plano nunca sincronicen a la vez. Corren en isolates distintos del
/// mismo proceso y comparten la conexión nativa a SQLite; además, renovar la sesión a la vez con el mismo
/// refresh token haría que el servidor la revoque. Los bloqueos propios de [SyncController] y de
/// [SessionManager] valen para un solo isolate, por eso esto coordina con [IsolateNameServer]:
/// - app viva: la tarea no abre nada, le pide a la app que ejecute su propia sincronización;
/// - app cerrada: la tarea sincroniza sola;
/// - la app arranca con una tarea en curso: le pide que pare y la espera antes de abrir nada.
/// Cada una se registra primero y mira a la otra después: al menos una siempre ve a la otra.
/// Un corte en cualquier punto es seguro: lo no confirmado se reenvía con el mismo `opId` y `clientId`.
class SyncCoordinator {
  SyncCoordinator._();

  static const appPortName = 'cg_sync_app';
  static const taskPortName = 'cg_sync_task';

  /// Sin respuesta en este tiempo, el registro quedó de un isolate que ya no existe (Android cortó
  /// la tarea o destruyó la pantalla sin terminar el proceso).
  static const _ackTimeout = Duration(seconds: 2);

  /// Lo que dura como mucho una petición en curso: la tarea no empieza otra después del aviso.
  static const _stopTimeout = Duration(seconds: 35);

  /// Tope de una sincronización hecha por la app a pedido de la tarea (una descarga completa puede tardar).
  static const _appSyncTimeout = Duration(minutes: 5);

  /// Margen para terminar lo que está en curso cuando Android corta la tarea.
  static const _stoppedGrace = Duration(seconds: 3);

  static ReceivePort? _appPort;
  static void Function()? _requestStop;
  static Future<void>? _taskFinished;

  // ---------------- app ----------------

  /// Antes de abrir la base o la sesión: anuncia la app y espera a la tarea que esté en curso.
  /// [appSync] atiende los pedidos de sincronización mientras la app siga viva.
  static Future<void> startApp(Future<BackgroundSyncOutcome> Function(bool onlyIfPending) appSync) async {
    _appPort?.close();
    final port = _appPort = ReceivePort();
    port.listen((message) {
      if (message is! List) return;
      final reply = message[1] as SendPort;
      reply.send(_ack);
      if (message[0] == _sync) {
        appSync(message[2] as bool).then(
          (outcome) => reply.send(outcome.name),
          onError: (Object _) => reply.send(BackgroundSyncOutcome.retryLater.name),
        );
      }
    });
    // Puede quedar uno viejo si Android destruyó la pantalla sin terminar el proceso.
    IsolateNameServer.removePortNameMapping(appPortName);
    IsolateNameServer.registerPortWithName(port.sendPort, appPortName);

    final task = IsolateNameServer.lookupPortByName(taskPortName);
    if (task == null) return;
    final conversation = _Conversation();
    task.send([_stop, conversation.sendPort]);
    if (await conversation.acknowledged) {
      await conversation.result(_stopTimeout);
    } else {
      IsolateNameServer.removePortNameMapping(taskPortName);
    }
    conversation.close();
  }

  // ---------------- tarea ----------------

  /// Ejecuta [work] si le toca a la tarea; si la app está viva, sincroniza la app. [work] recibe cómo
  /// saber que le pidieron parar, y no debe lanzar excepciones.
  static Future<BackgroundSyncOutcome> runTask({
    required bool onlyIfPending,
    required Future<BackgroundSyncOutcome> Function(bool Function() isStopped) work,
  }) async {
    final port = ReceivePort();
    final finished = Completer<void>();
    final waiting = <SendPort>[];
    var stopped = false;
    var released = false;
    var registered = false;

    void release() {
      if (released) return;
      released = true;
      if (registered) IsolateNameServer.removePortNameMapping(taskPortName);
      for (final w in waiting) {
        w.send(_done);
      }
      port.close();
      finished.complete();
    }

    port.listen((message) {
      if (message is! List) return;
      final reply = message[1] as SendPort;
      reply.send(_ack);
      if (message[0] != _stop) return;
      stopped = true;
      waiting.add(reply);
    });

    try {
      registered = await _claimTask(port.sendPort);
      // Otra tarea en curso (envío y periódica pueden coincidir): la que no entra no hace nada.
      if (!registered) return BackgroundSyncOutcome.retryLater;

      final app = IsolateNameServer.lookupPortByName(appPortName);
      if (app != null) {
        final conversation = _Conversation();
        app.send([_sync, conversation.sendPort, onlyIfPending]);
        if (await conversation.acknowledged) {
          release(); // la tarea no tocó nada: la app sigue libre, aunque esté arrancando
          final name = await conversation.result(_appSyncTimeout);
          conversation.close();
          return BackgroundSyncOutcome.values.firstWhere((o) => o.name == name, orElse: () => BackgroundSyncOutcome.retryLater);
        }
        conversation.close();
        IsolateNameServer.removePortNameMapping(appPortName);
      }

      _requestStop = () => stopped = true;
      _taskFinished = finished.future;
      return await work(() => stopped);
    } finally {
      _requestStop = null;
      release();
    }
  }

  /// Android está cortando la tarea: deja de empezar peticiones y da un margen a lo que está en curso.
  static Future<void> taskStoppedByPlatform() async {
    _requestStop?.call();
    final finished = _taskFinished;
    if (finished != null) await finished.timeout(_stoppedGrace, onTimeout: () {});
  }

  /// Registra la tarea. Si hay otra registrada, comprueba que siga viva; si no responde, toma su lugar.
  static Future<bool> _claimTask(SendPort port) async {
    if (IsolateNameServer.registerPortWithName(port, taskPortName)) return true;
    final other = IsolateNameServer.lookupPortByName(taskPortName);
    if (other != null) {
      final conversation = _Conversation();
      other.send([_ping, conversation.sendPort]);
      final alive = await conversation.acknowledged;
      conversation.close();
      if (alive) return false;
    }
    IsolateNameServer.removePortNameMapping(taskPortName);
    return IsolateNameServer.registerPortWithName(port, taskPortName);
  }

  static const _ping = 'ping';
  static const _stop = 'stop';
  static const _sync = 'sync';
  static const _ack = 'ack';
  static const _done = 'done';
}

/// Un pedido a otro isolate: primero confirma que está vivo y después manda el resultado.
class _Conversation {
  final _port = ReceivePort();
  final _ack = Completer<bool>();
  final _result = Completer<String?>();

  _Conversation() {
    _port.listen((message) {
      if (message == SyncCoordinator._ack) {
        if (!_ack.isCompleted) _ack.complete(true);
      } else if (!_result.isCompleted) {
        _result.complete(message as String?);
      }
    });
  }

  SendPort get sendPort => _port.sendPort;

  Future<bool> get acknowledged => _ack.future.timeout(SyncCoordinator._ackTimeout, onTimeout: () => false);

  Future<String?> result(Duration limit) => _result.future.timeout(limit, onTimeout: () => null);

  void close() => _port.close();
}
