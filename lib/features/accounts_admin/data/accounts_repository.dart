import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/money/money.dart';
import '../../../core/network/dio_client.dart';
import '../domain/account_item.dart';

final accountsRepositoryProvider = Provider<AccountsRepository>((ref) {
  return AccountsRepository(ref.watch(dioClientProvider));
});

/// Cuentas (GET /accounts). Solo lectura: las escrituras pasan por la cola de
/// sincronización (etapas 5 a 8).
class AccountsRepository {
  final DioClient _client;
  AccountsRepository(this._client);

  Future<List<AccountItem>> getAccounts() async {
    final data = await _client.get('/accounts');
    if (data is! List) throw _bad('accounts');
    return data.map((e) => parse(e)).toList();
  }

  static AccountItem parse(Object? json) {
    if (json is! Map<String, dynamic>) throw _bad('account');
    final id = json['id'];
    if (id is! int) throw _bad('account.id');
    return AccountItem(
      id: id,
      name: json['name'] as String? ?? '',
      currency: Currency.parse(json['currency']),
      active: json['active'] == true,
      imageUrl: json['imageUrl'] as String?,
      iconRef: json['iconRef'] as String?,
      balanceCents: Money.centsFrom(json['balanceCents'], 'account.balanceCents'),
      movementsCount: json['movementsCount'] is int ? json['movementsCount'] as int : throw _bad('movementsCount'),
      version: json['version'] as int?,
    );
  }

  static ServerException _bad(String field) =>
      ServerException('Respuesta inesperada del servidor ($field)', null, 'UNEXPECTED_RESPONSE');
}
