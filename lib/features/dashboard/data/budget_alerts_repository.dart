import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';

final budgetAlertsRepositoryProvider = Provider<BudgetAlertsRepository>(
  (ref) => BudgetAlertsRepository(ref.watch(dioClientProvider)),
);

/// Novedades de límites que el usuario ya vio, guardadas en el servidor para compartirlas con la web
/// (CG: /budget-alerts/seen). Requieren conexión; sin ella la marca queda en el celular y se envía después.
class BudgetAlertsRepository {
  final DioClient _client;
  BudgetAlertsRepository(this._client);

  /// Clave de una novedad vista: límite del servidor, tipo y período.
  static String key(int budgetId, String kind, String startDate, String endDate) => '${budgetId}_${kind}_${startDate}_$endDate';

  Future<Set<String>> seen() async {
    final body = await _client.get('/budget-alerts/seen');
    if (body is! List) return const {};
    return body
        .cast<Map<String, dynamic>>()
        .map((r) => key(r['budgetId'] as int, r['kind'] as String, r['startDate'] as String, r['endDate'] as String))
        .toSet();
  }

  Future<void> markSeen(int budgetId, String kind, String startDate, String endDate) => _client.post(
        '/budget-alerts/seen',
        data: {'budgetId': budgetId, 'kind': kind, 'startDate': startDate, 'endDate': endDate},
      );
}
