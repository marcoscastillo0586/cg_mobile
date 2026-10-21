import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../domain/category_item.dart';

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return CategoriesRepository(ref.watch(dioClientProvider));
});

/// Para qué se piden las categorías (F2.7): la API excluye las reservadas según el uso.
enum CategoryPurpose { all, expense, budget, movements }

/// Categorías (GET /categories). Solo lectura.
class CategoriesRepository {
  final DioClient _client;
  CategoriesRepository(this._client);

  Future<List<CategoryItem>> getCategories({CategoryPurpose purpose = CategoryPurpose.all}) async {
    final data = await _client.get('/categories', queryParameters: {'purpose': purpose.name});
    if (data is! List) throw _bad('categories');
    return data.map(parse).toList();
  }

  static CategoryItem parse(Object? json) {
    if (json is! Map<String, dynamic>) throw _bad('category');
    final id = json['id'];
    if (id is! int) throw _bad('category.id');
    return CategoryItem(
      id: id,
      name: json['name'] as String? ?? '',
      active: json['active'] == true,
      role: CategoryRole.parse(json['role']),
      movementsCount: json['movementsCount'] is int ? json['movementsCount'] as int : throw _bad('movementsCount'),
      version: json['version'] as int?,
    );
  }

  static ServerException _bad(String field) =>
      ServerException('Respuesta inesperada del servidor ($field)', null, 'UNEXPECTED_RESPONSE');
}
