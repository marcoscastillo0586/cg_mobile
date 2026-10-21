import '../entities/movement_detail_entity.dart';
import '../entities/movement_entity.dart';

abstract class MovementRepository {
  Future<({List<MovementEntity> movimientos, MovementsSummaryEntity resumen})> getMovements({
    String? desde,
    String? hasta,
    int? idLugar,
    int? idCategoria,
    int limit = 50,
    int offset = 0,
  });

  Future<({List<MovementEntity> movimientos, Map<int, MovementDetailEntity> detallesSearchResult})> searchMovements({
    required String query,
    String? desde,
    String? hasta,
    int? idLugar,
  });

  Future<MovementDetailEntity> getMovementDetail(int id);

  Future<bool> updateMovement(Map<String, dynamic> data);

  Future<bool> deleteMovement(int id);
}
