import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/renglon_gasto.dart';
import '../../domain/entities/ticket_parse_result.dart';
import '../../domain/repositories/expense_repository.dart';
import '../../data/repositories/expense_repository_impl.dart';
import 'expense_form_state.dart';

final expenseFormNotifierProvider =
    StateNotifierProvider.autoDispose<ExpenseFormNotifier, ExpenseFormState>((ref) {
  final repository = ref.watch(expenseRepositoryProvider);
  return ExpenseFormNotifier(repository);
});

class ExpenseFormNotifier extends StateNotifier<ExpenseFormState> {
  final ExpenseRepository _repository;

  ExpenseFormNotifier(this._repository) : super(ExpenseFormState.initial()) {
    inicializar();
  }

  Future<void> inicializar() async {
    state = state.copyWith(status: ExpenseFormStatus.loadingData);
    try {
      final formData = await _repository.getFormData();

      final defaultCategoria = formData.categorias.isNotEmpty ? formData.categorias.first : null;

      final primerRenglon = RenglonGasto.nuevo(
        defaultCategoriaId: defaultCategoria?.idCategoria,
        defaultCategoria: defaultCategoria,
      );

      state = state.copyWith(
        status: ExpenseFormStatus.ready,
        formData: formData,
        selectedLugarId: null, // Punto 6.5: Inicia sin ninguna cuenta seleccionada en alta
        renglones: [primerRenglon],
      );
    } on Failure catch (e) {
      state = state.copyWith(
        status: ExpenseFormStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExpenseFormStatus.error,
        errorMessage: 'Error al inicializar formulario: $e',
      );
    }
  }

  void setLugar(int idLugar) {
    state = state.copyWith(selectedLugarId: idLugar);
  }

  void setFecha(DateTime fecha) {
    state = state.copyWith(fecha: fecha);
  }

  void setConceptoGeneral(String concepto) {
    state = state.copyWith(conceptoGeneral: concepto);
  }

  void agregarRenglon() {
    final defaultCategoria = state.formData?.categorias.isNotEmpty == true
        ? state.formData!.categorias.first
        : null;

    final nuevoRenglon = RenglonGasto.nuevo(
      defaultCategoriaId: defaultCategoria?.idCategoria,
      defaultCategoria: defaultCategoria,
    );

    state = state.copyWith(
      renglones: [...state.renglones, nuevoRenglon],
    );
  }

  void eliminarRenglon(String id) {
    if (state.renglones.length <= 1) return;

    final actualizados = state.renglones.where((r) => r.id != id).toList();
    state = state.copyWith(renglones: actualizados);
  }

  void actualizarConcepto(String id, String concepto) {
    final actualizados = state.renglones.map((r) {
      if (r.id == id) {
        return r.copyWith(concepto: concepto);
      }
      return r;
    }).toList();

    state = state.copyWith(renglones: actualizados);
    _verificarSugerenciaCategoria(id, concepto);
  }

  void actualizarMonto(String id, double monto) {
    final actualizados = state.renglones.map((r) {
      if (r.id == id) {
        return r.copyWith(monto: monto);
      }
      return r;
    }).toList();

    state = state.copyWith(renglones: actualizados);
  }

  void actualizarCategoria(String id, int categoriaId) {
    CategoryEntity? categoriaEntity;
    if (state.formData != null) {
      categoriaEntity = state.formData!.categorias.cast<CategoryEntity?>().firstWhere(
            (c) => c?.idCategoria == categoriaId,
            orElse: () => null,
          );
    }

    final actualizados = state.renglones.map((r) {
      if (r.id == id) {
        return r.copyWith(
          categoriaId: categoriaId,
          categoria: categoriaEntity,
        );
      }
      return r;
    }).toList();

    state = state.copyWith(renglones: actualizados);
  }

  Future<void> _verificarSugerenciaCategoria(String renglonId, String concepto) async {
    if (concepto.trim().length >= 3) {
      final sugerida = await _repository.suggestCategory(concepto);
      if (sugerida != null && mounted) {
        final index = state.renglones.indexWhere((r) => r.id == renglonId);
        if (index != -1) {
          actualizarCategoria(renglonId, sugerida);
        }
      }
    }
  }

  void aplicarResultadoTicket(TicketParseResult parseResult) {
    final List<RenglonGasto> renglonesNuevos = [];
    int idx = 0;

    for (final item in parseResult.items) {
      idx++;
      final catId = item.idCategoriaSugerida ??
          (state.formData?.categorias.isNotEmpty == true
              ? state.formData!.categorias.first.idCategoria
              : 3);
      final catEntity = state.formData?.categorias.cast<CategoryEntity?>().firstWhere(
            (c) => c?.idCategoria == catId,
            orElse: () => null,
          );

      renglonesNuevos.add(
        RenglonGasto(
          id: 'ocr_${DateTime.now().microsecondsSinceEpoch}_$idx',
          concepto: item.nombre,
          monto: item.precio,
          categoriaId: catId,
          categoria: catEntity,
        ),
      );
    }

    final suma = parseResult.sumaRenglones;
    final totalD = parseResult.totalDetectado;

    String feedback;
    if (totalD != null) {
      if (parseResult.tieneDiferenciaTotal) {
        feedback = 'Suma de renglones (\$${suma.toStringAsFixed(2)}) difiere del total detectado (\$$totalD). Verifica los montos.';
      } else {
        feedback = 'Ticket leído: Suma \$${suma.toStringAsFixed(2)} | Total \$${totalD.toStringAsFixed(2)}';
      }
    } else {
      feedback = 'Suma de renglones: \$${suma.toStringAsFixed(2)} (No se detectó un total explícito en el ticket).';
    }

    state = state.copyWith(
      status: ExpenseFormStatus.ready,
      ticketParseResult: parseResult,
      renglones: renglonesNuevos.isNotEmpty ? renglonesNuevos : [RenglonGasto.nuevo()],
      qrFeedback: feedback,
    );
  }

  void limpiarItemsTicket() {
    final defaultCat = state.formData?.categorias.isNotEmpty == true
        ? state.formData!.categorias.first
        : null;

    state = state.copyWith(
      ticketParseResult: null,
      renglones: [
        RenglonGasto.nuevo(
          defaultCategoriaId: defaultCat?.idCategoria,
          defaultCategoria: defaultCat,
        )
      ],
      qrFeedback: null,
    );
  }

  /// Valida y registra o actualiza el gasto con todos sus renglones en el backend
  Future<bool> guardarEgreso() async {
    if (state.selectedLugarId == null) {
      state = state.copyWith(errorMessage: 'Debes seleccionar una cuenta de origen');
      return false;
    }

    if (state.conceptoGeneral.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'El Concepto General es obligatorio');
      return false;
    }

    if (state.renglones.isEmpty) {
      state = state.copyWith(errorMessage: 'Debes ingresar al menos un renglón de gasto');
      return false;
    }

    for (int i = 0; i < state.renglones.length; i++) {
      final r = state.renglones[i];
      final numRenglon = i + 1;

      if (r.monto <= 0) {
        state = state.copyWith(
          errorMessage: 'El Renglón #$numRenglon debe tener un monto válido mayor a 0',
        );
        return false;
      }

      if (r.categoriaId == null || r.categoriaId! <= 0) {
        state = state.copyWith(
          errorMessage: 'Debes seleccionar una categoría para el Renglón #$numRenglon',
        );
        return false;
      }
    }

    final fechaStr = DateFormat('yyyy-MM-dd').format(state.fecha);
    final conceptoGral = state.conceptoGeneral.trim().isEmpty ? 'Gasto' : state.conceptoGeneral.trim();

    final itemsAEnviar = state.renglones.map((r) {
      return r.toExpenseItemEntity(fallbackConcepto: conceptoGral);
    }).toList();

    state = state.copyWith(status: ExpenseFormStatus.submitting, errorMessage: null);

    try {
      final ok = await _repository.createExpense(
        idLugar: state.selectedLugarId!,
        fecha: fechaStr,
        conceptoGeneral: conceptoGral,
        items: itemsAEnviar,
      );

      if (ok) {
        state = state.copyWith(status: ExpenseFormStatus.success);
        return true;
      } else {
        state = state.copyWith(
          status: ExpenseFormStatus.ready,
          errorMessage: 'No se pudo guardar el egreso en el servidor',
        );
        return false;
      }
    } on Failure catch (e) {
      state = state.copyWith(
        status: ExpenseFormStatus.ready,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: ExpenseFormStatus.ready,
        errorMessage: 'Error al registrar: $e',
      );
      return false;
    }
  }
}
