// Coordinación entre la app y la tarea en un solo isolate: que funcione entre el isolate de la app y el
// de WorkManager se prueba en el celular.
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/sync/sync_coordinator.dart';

void main() {
  void clear() {
    IsolateNameServer.removePortNameMapping(SyncCoordinator.appPortName);
    IsolateNameServer.removePortNameMapping(SyncCoordinator.taskPortName);
  }

  setUp(clear);
  tearDown(clear);

  Future<BackgroundSyncOutcome> appSync(bool onlyIfPending) async => BackgroundSyncOutcome.done;

  SendPort deadPort() {
    final port = ReceivePort();
    final send = port.sendPort;
    port.close();
    return send;
  }

  test('con la app cerrada la tarea sincroniza y libera su registro', () async {
    final outcome = await SyncCoordinator.runTask(onlyIfPending: false, work: (_) async => BackgroundSyncOutcome.done);
    expect(outcome, BackgroundSyncOutcome.done);
    expect(IsolateNameServer.lookupPortByName(SyncCoordinator.taskPortName), isNull);
  });

  test('con la app viva sincroniza la app y la tarea no toca nada', () async {
    bool? asked;
    await SyncCoordinator.startApp((onlyIfPending) async {
      asked = onlyIfPending;
      return BackgroundSyncOutcome.retryLater;
    });
    var worked = false;
    final outcome = await SyncCoordinator.runTask(
      onlyIfPending: true,
      work: (_) async {
        worked = true;
        return BackgroundSyncOutcome.done;
      },
    );
    expect((worked, asked, outcome), (false, true, BackgroundSyncOutcome.retryLater));
  });

  test('un registro viejo de la app no bloquea a la tarea', () async {
    IsolateNameServer.registerPortWithName(deadPort(), SyncCoordinator.appPortName);
    final outcome = await SyncCoordinator.runTask(onlyIfPending: false, work: (_) async => BackgroundSyncOutcome.done);
    expect(outcome, BackgroundSyncOutcome.done);
    expect(IsolateNameServer.lookupPortByName(SyncCoordinator.appPortName), isNull);
  });

  test('la app que arranca le pide parar a la tarea y la espera', () async {
    final events = <String>[];
    final task = SyncCoordinator.runTask(
      onlyIfPending: false,
      work: (isStopped) async {
        while (!isStopped()) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        events.add('tarea terminó');
        return BackgroundSyncOutcome.retryLater;
      },
    );
    while (IsolateNameServer.lookupPortByName(SyncCoordinator.taskPortName) == null) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await SyncCoordinator.startApp(appSync);
    events.add('app sigue');
    expect(events, ['tarea terminó', 'app sigue']);
    expect(await task, BackgroundSyncOutcome.retryLater);
  });

  test('un registro viejo de la tarea no traba el arranque de la app', () async {
    IsolateNameServer.registerPortWithName(deadPort(), SyncCoordinator.taskPortName);
    await SyncCoordinator.startApp(appSync);
    expect(IsolateNameServer.lookupPortByName(SyncCoordinator.taskPortName), isNull);
  });

  test('dos tareas a la vez: la segunda no hace nada', () async {
    final first = SyncCoordinator.runTask(
      onlyIfPending: false,
      work: (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return BackgroundSyncOutcome.done;
      },
    );
    while (IsolateNameServer.lookupPortByName(SyncCoordinator.taskPortName) == null) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    var secondWorked = false;
    final second = await SyncCoordinator.runTask(
      onlyIfPending: false,
      work: (_) async {
        secondWorked = true;
        return BackgroundSyncOutcome.done;
      },
    );
    expect((secondWorked, second), (false, BackgroundSyncOutcome.retryLater));
    expect(await first, BackgroundSyncOutcome.done);
  });
}
