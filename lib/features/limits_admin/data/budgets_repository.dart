import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/money/money.dart';
import '../../../core/network/dio_client.dart';
import '../domain/budget.dart';

final budgetsRepositoryProvider = Provider<BudgetsRepository>((ref) {
  return BudgetsRepository(ref.watch(dioClientProvider));
});

/// Presupuestos (GET /budgets). Solo lectura.
class BudgetsRepository {
  final DioClient _client;
  BudgetsRepository(this._client);

  Future<List<Budget>> getBudgets() async {
    final data = await _client.get('/budgets');
    if (data is! List) throw _bad('budgets');
    return data.map(parse).toList();
  }

  static Budget parse(Object? json) {
    if (json is! Map<String, dynamic>) throw _bad('budget');
    final id = json['id'];
    if (id is! int) throw _bad('budget.id');
    final percent = json['percent'];
    if (percent != null && percent is! num) throw _bad('budget.percent');
    return Budget(
      id: id,
      startDate: json['startDate'] as String? ?? (throw _bad('startDate')),
      endDate: json['endDate'] as String? ?? (throw _bad('endDate')),
      limitCents: Money.centsFrom(json['limitCents'], 'budget.limitCents'),
      consumedCents: Money.centsFrom(json['consumedCents'], 'budget.consumedCents'),
      remainingCents: Money.centsFrom(json['remainingCents'], 'budget.remainingCents'),
      percent: percent as num?,
      dueForRenewal: json['dueForRenewal'] == true,
      categories: _refs(json['categories'], 'categories'),
      accounts: _refs(json['accounts'], 'accounts'),
      version: json['version'] as int?,
    );
  }

  static List<BudgetRef> _refs(Object? list, String field) {
    if (list is! List) throw _bad(field);
    return list.map((e) {
      if (e is! Map<String, dynamic> || e['id'] is! int) throw _bad(field);
      return BudgetRef(e['id'] as int, e['name'] as String? ?? '');
    }).toList();
  }

  static ServerException _bad(String field) =>
      ServerException('Respuesta inesperada del servidor ($field)', null, 'UNEXPECTED_RESPONSE');
}
