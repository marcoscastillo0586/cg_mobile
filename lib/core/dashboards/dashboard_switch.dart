import 'package:flutter/foundation.dart';
import '../database/local_database.dart';
import 'current_dashboard.dart';

/// Cambia el dashboard elegido. Cierra la base local del anterior, guarda la elección y cambia
/// [CurrentDashboard.id]: [SessionScope] descarta todo el estado y abre la base del nuevo.
class DashboardSwitch {
  DashboardSwitch._();

  /// Usuario de la sesión (para guardar la elección a su nombre).
  static int? userId;

  /// [dashboardId] null = el principal del usuario.
  static Future<void> select(int? dashboardId) async {
    if (CurrentDashboard.id.value == dashboardId) return;
    await LocalDatabase.close();
    final user = userId;
    if (user != null) {
      try {
        await CurrentDashboard.save(user, dashboardId);
      } catch (e) {
        // Se cambia igual; la próxima vez que se abra la app vuelve al principal.
        debugPrint('[DASHBOARD] No se pudo guardar el dashboard elegido: $e');
      }
    }
    CurrentDashboard.id.value = dashboardId;
  }

  /// El servidor respondió que ya no hay acceso a [dashboardId] (quitaron el acceso, salió o se
  /// eliminó): se borran sus datos del celular y, si era el elegido, se vuelve al principal.
  static Future<void> lost(int dashboardId) async {
    final wasCurrent = CurrentDashboard.id.value == dashboardId;
    if (wasCurrent) await select(null);
    try {
      await LocalDatabase.deleteFor(dashboardId);
    } catch (e) {
      debugPrint('[DASHBOARD] No se pudo borrar la base local del dashboard $dashboardId: $e');
    }
    if (wasCurrent) CurrentDashboard.notice.value = CurrentDashboard.accessLost;
  }
}
