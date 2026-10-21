import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiEndpoints {
  ApiEndpoints._();

  /// Detecta automáticamente el host adecuado:
  /// - En Android (Dispositivo físico o emulador en LAN): 'http://192.168.0.50/gastos2.0'
  /// - En iOS, Web o Desktop: 'http://localhost/gastos2.0'
  static String _resolveDefaultBaseUrl() {
    if (kIsWeb) return 'http://localhost/gastos2.0';
    try {
      if (Platform.isAndroid) {
        return 'http://192.168.0.50/gastos2.0';
      }
    } catch (_) {}
    return 'http://localhost/gastos2.0';
  }

  static String baseUrl = _resolveDefaultBaseUrl();

  // Auth
  static String get login => '$baseUrl/api/auth/login';
  static String get logout => '$baseUrl/api/auth/logout';
  static String get checkAuth => '$baseUrl/api/auth/me';

  // Dashboard & Saldos
  static String get dashboardSaldos => '$baseUrl/api/dashboard/saldos';
  static String get dashboardLimites => '$baseUrl/api/dashboard/limites';

  // Maestros / Catálogos & ABM Cuentas
  static String get lugares => '$baseUrl/api/lugares';
  static String get crearLugar => '$baseUrl/api/lugares/crear';
  static String get editarLugar => '$baseUrl/api/lugares/editar';
  static String get cambiarEstadoLugar => '$baseUrl/api/lugares/cambiar_estado';
  static String get eliminarLugar => '$baseUrl/api/lugares/eliminar';
  static String get categorias => '$baseUrl/api/categorias';
  static String get crearCategoria => '$baseUrl/api/categorias/crear';
  static String get editarCategoria => '$baseUrl/api/categorias/editar';
  static String get cambiarEstadoCategoria => '$baseUrl/api/categorias/cambiar_estado';
  static String get eliminarCategoria => '$baseUrl/api/categorias/eliminar';

  // Operaciones
  static String get formularioEgreso => '$baseUrl/api/egresos/formulario_data';
  static String get crearEgreso => '$baseUrl/api/egresos/crear';
  static String get sugerirCategoria => '$baseUrl/api/egresos/sugerir_categoria';
  static String get crearIngreso => '$baseUrl/api/ingresos/crear';
  static String get crearTransferencia => '$baseUrl/api/transferencias/crear';

  // Presupuestos & Límites de Gasto (ABM)
  static String get limites => '$baseUrl/api/limites';
  static String get crearLimite => '$baseUrl/api/limites/crear';
  static String get editarLimite => '$baseUrl/api/limites/editar';
  static String get renovarLimite => '$baseUrl/api/limites/renovar';
  static String get eliminarLimite => '$baseUrl/api/limites/eliminar';

  // Reportes y Analíticas (Analytics)
  static String get reporteGastosPorCategoria => '$baseUrl/api/reportes/gastos_por_categoria';
  static String get reporteComparativaMensual => '$baseUrl/api/reportes/comparativa_mensual';
  static String get reporteEvolucionDiaria => '$baseUrl/api/reportes/evolucion_diaria';
  static String get reportePreciosProductos => '$baseUrl/api/reportes/precios_productos';
  static String get reporteHistorialProducto => '$baseUrl/api/reportes/historial_producto';
  static String get reporteComparativaPrecios => '$baseUrl/api/reportes/comparativa_precios';

  // Movimientos e Historial
  static String get movimientos => '$baseUrl/api/movimientos';
  static String get movimientoDetalle => '$baseUrl/api/movimientos/detalle';
  static String get movimientosBuscar => '$baseUrl/api/movimientos/buscar';
  static String get editarMovimiento => '$baseUrl/api/movimientos/editar';
  static String get eliminarMovimiento => '$baseUrl/api/movimientos/eliminar';
}
