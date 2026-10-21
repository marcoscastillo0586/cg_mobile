import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../limits_admin/data/repositories/limits_admin_repository_impl.dart';
import '../../../limits_admin/domain/entities/expense_limit_admin_entity.dart';
import '../../../limits_admin/domain/repositories/limits_admin_repository.dart';
import '../../domain/entities/novedad_entity.dart';

class NovedadesState {
  final bool isLoading;
  final List<NovedadEntity> novedades;
  final String? errorMessage;

  const NovedadesState({
    this.isLoading = false,
    this.novedades = const [],
    this.errorMessage,
  });

  List<NovedadEntity> get novedadesNoVistas =>
      novedades.where((n) => !n.vista).toList();

  bool get hasUnread => novedadesNoVistas.isNotEmpty;

  Color get gravedadMaxColor {
    final unread = novedadesNoVistas;
    if (unread.isEmpty) return Colors.grey;

    if (unread.any((n) => n.tipo == NovedadTipo.alcanzado)) {
      return AppColors.rose;
    }
    if (unread.any((n) => n.tipo == NovedadTipo.cerca)) {
      return AppColors.amber;
    }
    return AppColors.primary;
  }

  NovedadesState copyWith({
    bool? isLoading,
    List<NovedadEntity>? novedades,
    String? errorMessage,
  }) {
    return NovedadesState(
      isLoading: isLoading ?? this.isLoading,
      novedades: novedades ?? this.novedades,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final novedadesNotifierProvider =
    StateNotifierProvider<NovedadesNotifier, NovedadesState>((ref) {
  final limitsRepository = ref.watch(limitsAdminRepositoryProvider);
  final storageService = ref.watch(secureStorageServiceProvider);
  return NovedadesNotifier(limitsRepository, storageService, ref);
});

class NovedadesNotifier extends StateNotifier<NovedadesState> {
  final LimitsAdminRepository _limitsRepository;
  final SecureStorageService _storageService;
  final Ref _ref;

  NovedadesNotifier(
    this._limitsRepository,
    this._storageService,
    this._ref,
  ) : super(const NovedadesState()) {
    calcularNovedades();
  }

  /// Id del usuario autenticado. Sin usuario no hay novedades que mostrar.
  int? _resolverUserId() => _ref.read(authNotifierProvider).user?.idUsuario;

  Future<void> calcularNovedades() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final userId = _resolverUserId();
      if (userId == null) {
        state = state.copyWith(isLoading: false, novedades: []);
        return;
      }

      List<ExpenseLimitAdminEntity> limits = [];
      try {
        limits = await _limitsRepository.getLimits();
      } catch (_) {
        state = state.copyWith(isLoading: false, novedades: []);
        return;
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dateFormat = DateFormat('yyyy-MM-dd');

      final List<NovedadEntity> candidatas = [];
      final Set<String> keysActuales = {};

      for (final limit in limits) {
        final desdeDate = DateTime(
          limit.desde.year,
          limit.desde.month,
          limit.desde.day,
        );
        final hastaDate = DateTime(
          limit.hasta.year,
          limit.hasta.month,
          limit.hasta.day,
        );

        // Excluir límites futuros (desde > hoy)
        if (desdeDate.isAfter(today)) {
          continue;
        }

        final bool esVencido = today.isAfter(hastaDate);
        NovedadTipo? tipo;

        if (esVencido) {
          tipo = NovedadTipo.vencido;
        } else if (limit.montoLimite > 0) {
          final consumido = limit.montoConsumido;
          final limite = limit.montoLimite;

          if (consumido >= limite) {
            tipo = NovedadTipo.alcanzado;
          } else if (consumido * 100 >= limite * 75) {
            tipo = NovedadTipo.cerca;
          }
        }

        if (tipo != null) {
          final desdeStr = dateFormat.format(desdeDate);
          final hastaStr = dateFormat.format(hastaDate);
          final key = 'alerta_vista_${userId}_${limit.idLimiteGasto}_${tipo.name}_${desdeStr}_$hastaStr';
          keysActuales.add(key);

          final porcentajeInt = limit.montoLimite > 0
              ? ((limit.montoConsumido * 100) / limit.montoLimite).floor()
              : 0;

          final fueVista = await _checkIfKeySeen(key);

          candidatas.add(
            NovedadEntity(
              idKey: key,
              idLimiteGasto: limit.idLimiteGasto,
              titulo: limit.categoriasNombres,
              tipo: tipo,
              porcentaje: porcentajeInt,
              desde: desdeDate,
              hasta: hastaDate,
              vista: fueVista,
            ),
          );
        }
      }

      // Orden de prioridad: mayor porcentaje primero, empate A-Z, vencidos al final
      candidatas.sort((a, b) {
        if (a.tipo == NovedadTipo.vencido && b.tipo != NovedadTipo.vencido) {
          return 1;
        }
        if (a.tipo != NovedadTipo.vencido && b.tipo == NovedadTipo.vencido) {
          return -1;
        }
        if (a.porcentaje != b.porcentaje) {
          return b.porcentaje.compareTo(a.porcentaje);
        }
        return a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
      });

      unawaited(_limpiarClavesHuerfanas(userId, keysActuales));

      state = state.copyWith(
        isLoading: false,
        novedades: candidatas,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, novedades: []);
    }
  }

  Future<bool> _checkIfKeySeen(String key) async {
    try {
      final val = await _storageService.readValue(key);
      return val == '1';
    } catch (_) {}
    return false;
  }

  Future<void> marcarComoVista(NovedadEntity novedad) async {
    try {
      // Guardado seguro e independiente por clave única
      await _storageService.writeValue(novedad.idKey, '1');

      final actualizadas = state.novedades.map((n) {
        if (n.idKey == novedad.idKey) {
          return n.copyWith(vista: true);
        }
        return n;
      }).toList();

      state = state.copyWith(novedades: actualizadas);
    } catch (_) {}
  }

  Future<void> _limpiarClavesHuerfanas(int userId, Set<String> keysValidas) async {
    try {
      final allStorage = await _storageService.readAllKeys();
      final prefix = 'alerta_vista_${userId}_';

      for (final key in allStorage.keys) {
        if (key.startsWith(prefix) && !keysValidas.contains(key)) {
          await _storageService.deleteValue(key);
        }
      }
    } catch (_) {}
  }
}
