import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';
import 'sync_service.dart';

const String kPeriodicSyncTask = 'periodicSyncTask';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      debugPrint('[WORKMANAGER-BG] Ejecutando tarea periódica en segundo plano: $task');
      return true;
    } catch (e) {
      debugPrint('[WORKMANAGER-BG] Error en tarea de fondo: $e');
      return true;
    }
  });
}

final backgroundSyncServiceProvider = Provider<BackgroundSyncService>((ref) {
  return BackgroundSyncService(ref);
});

class BackgroundSyncService with WidgetsBindingObserver {
  final Ref _ref;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _debounceTimer;

  BackgroundSyncService(this._ref);

  void initialize() {
    WidgetsBinding.instance.addObserver(this);
    _initConnectivityListener();
    _initWorkmanager();
  }

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      if (results.contains(ConnectivityResult.wifi)) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(seconds: 8), () {
          debugPrint('[CONNECTIVITY-LISTENER] Conexión Wi-Fi detectada. Disparando sincronización silenciosa...');
          _ref.read(syncServiceProvider.notifier).runFullSync(silent: true);
        });
      }
    });
  }

  void _initWorkmanager() {
    try {
      Workmanager().initialize(callbackDispatcher);
      Workmanager().registerPeriodicTask(
        kPeriodicSyncTask,
        kPeriodicSyncTask,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.unmetered,
        ),
      );
      debugPrint('[WORKMANAGER] Tarea periódica de 15 min registrada con restricción Wi-Fi');
    } catch (e) {
      debugPrint('[WORKMANAGER] Error al registrar tarea de fondo: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[APP-LIFECYCLE] App reanudada en primer plano. Disparando sincronización silenciosa...');
      _ref.read(syncServiceProvider.notifier).runFullSync(silent: true);
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _debounceTimer?.cancel();
  }
}
