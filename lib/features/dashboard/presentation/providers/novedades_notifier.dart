import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../../core/sync/local_ops.dart';
import '../../../limits_admin/data/local_budgets_repository.dart';
import '../../../limits_admin/domain/budget.dart';
import '../../domain/entities/novedad_entity.dart';

class NovedadesState {
  final bool isLoading;
  final List<NovedadEntity> novedades;

  /// Error de la última carga (se registra; la campana queda sin novedades).
  final Object? error;

  const NovedadesState({this.isLoading = false, this.novedades = const [], this.error});

  List<NovedadEntity> get novedadesNoVistas => novedades.where((n) => !n.vista).toList();

  bool get hasUnread => novedadesNoVistas.isNotEmpty;

  Color get gravedadMaxColor {
    final unread = novedadesNoVistas;
    if (unread.isEmpty) return Colors.grey;
    if (unread.any((n) => n.tipo == NovedadTipo.alcanzado)) return AppColors.rose;
    if (unread.any((n) => n.tipo == NovedadTipo.cerca)) return AppColors.amber;
    return AppColors.primary;
  }

  NovedadesState copyWith({bool? isLoading, List<NovedadEntity>? novedades, Object? error, bool clearError = false}) {
    return NovedadesState(
      isLoading: isLoading ?? this.isLoading,
      novedades: novedades ?? this.novedades,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final novedadesNotifierProvider = StateNotifierProvider<NovedadesNotifier, NovedadesState>((ref) {
  return NovedadesNotifier(ref.watch(localBudgetsRepositoryProvider), ref.watch(secureStorageServiceProvider), ref);
});

/// Tipo de novedad de un presupuesto, derivado de percent y dueForRenewal (misma regla que
/// el servidor, calculados en la base local): vencido si `dueForRenewal`; alcanzado si
/// percent ≥ 100; cerca si percent ≥ 75. Sin fechas inventadas.
NovedadTipo? tipoNovedad(Budget b) {
  if (b.dueForRenewal) return NovedadTipo.vencido;
  final p = b.percentHundredths;
  if (p == null) return null;
  if (p >= 10000) return NovedadTipo.alcanzado;
  if (p >= 7500) return NovedadTipo.cerca;
  return null;
}

class NovedadesNotifier extends StateNotifier<NovedadesState> {
  final Future<LocalBudgetsRepository> _budgets;
  final SecureStorageService _storage;
  final Ref _ref;

  NovedadesNotifier(this._budgets, this._storage, this._ref) : super(const NovedadesState()) {
    calcularNovedades();
  }

  int? _userId() => _ref.read(authNotifierProvider).user?.idUsuario;

  Future<void> calcularNovedades() async {
    final userId = _userId();
    if (userId == null) {
      state = const NovedadesState();
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final budgets = await (await _budgets).list();
      final hoy = LocalOps.todayAr();
      final candidatas = <NovedadEntity>[];
      final keys = <String>{};
      for (final b in budgets) {
        if (b.startDate.compareTo(hoy) > 0) continue; // presupuestos futuros
        final tipo = tipoNovedad(b);
        if (tipo == null) continue;
        // Clave estable: id del servidor (o el local si el límite todavía no se sincronizó).
        final key = 'alerta_vista_${userId}_${b.serverId ?? 'l${b.id}'}_${tipo.name}_${b.startDate}_${b.endDate}';
        keys.add(key);
        candidatas.add(NovedadEntity(
          idKey: key,
          idLimiteGasto: b.id,
          titulo: b.title,
          tipo: tipo,
          porcentaje: (b.percentHundredths ?? 0) ~/ 100,
          desde: DateTime.parse(b.startDate),
          hasta: DateTime.parse(b.endDate),
          vista: await _storage.readValue(key) == '1',
        ));
      }
      // Mayor porcentaje primero, empate A-Z, vencidos al final.
      candidatas.sort((a, b) {
        final av = a.tipo == NovedadTipo.vencido, bv = b.tipo == NovedadTipo.vencido;
        if (av != bv) return av ? 1 : -1;
        if (a.porcentaje != b.porcentaje) return b.porcentaje.compareTo(a.porcentaje);
        return a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
      });
      await _limpiarClavesHuerfanas(userId, keys);
      if (mounted) state = state.copyWith(isLoading: false, novedades: candidatas);
    } catch (e) {
      debugPrint('[NOVEDADES] No se pudieron calcular: $e');
      if (mounted) state = state.copyWith(isLoading: false, novedades: [], error: e);
    }
  }

  Future<void> marcarComoVista(NovedadEntity novedad) async {
    try {
      await _storage.writeValue(novedad.idKey, '1');
      state = state.copyWith(
        novedades: state.novedades.map((n) => n.idKey == novedad.idKey ? n.copyWith(vista: true) : n).toList(),
      );
    } catch (e) {
      debugPrint('[NOVEDADES] No se pudo marcar como vista: $e');
      state = state.copyWith(error: e);
    }
  }

  Future<void> _limpiarClavesHuerfanas(int userId, Set<String> validas) async {
    final prefix = 'alerta_vista_${userId}_';
    final todas = await _storage.readAllKeys();
    for (final key in todas.keys) {
      if (key.startsWith(prefix) && !validas.contains(key)) await _storage.deleteValue(key);
    }
  }
}
