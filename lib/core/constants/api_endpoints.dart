import '../config/api_config.dart';

class ApiEndpoints {
  ApiEndpoints._();

  /// Base de la API nueva (`/api/v1`), fijada al compilar con `--dart-define=API_BASE_URL`.
  static String get baseUrl => ApiConfig.baseUrl;

  // Auth (API nueva; rutas relativas a la base del cliente)
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  // ---------------------------------------------------------------------------
  // CONTRATO PHP VIEJO. Estas rutas no existen en /api/v1 (responden 404) y se
  // reemplazan función por función a partir de la etapa 2.
  // ---------------------------------------------------------------------------

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
