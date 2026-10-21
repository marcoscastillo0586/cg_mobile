import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/date_utils.dart';
import '../../data/models/movement_detail_model.dart';
import '../../domain/entities/movement_detail_entity.dart';
import '../../domain/entities/movement_entity.dart';

class MovementCard extends StatefulWidget {
  final MovementEntity movement;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  final Future<MovementDetailEntity?> Function(int idMovimientoEnc)? onCargarDetalle;

  const MovementCard({
    super.key,
    required this.movement,
    required this.onEditar,
    required this.onEliminar,
    this.onCargarDetalle,
  });

  @override
  State<MovementCard> createState() => _MovementCardState();
}

class _MovementCardState extends State<MovementCard> {
  bool _isExpanded = false;
  bool _isLoadingDetail = false;
  MovementDetailEntity? _detail;

  String _formatearMonto(double monto, int tipo) {
    final formatted = AppCurrencyUtils.format(monto.abs(), symbol: '\$');
    if (tipo == 1) return '+$formatted';
    if (tipo == 2) return '-$formatted';
    return formatted;
  }

  Color _obtenerColor(int tipo) {
    if (tipo == 1) return AppColors.emerald;
    if (tipo == 2) return AppColors.rose;
    return AppColors.primary;
  }

  IconData _obtenerIcono(int tipo) {
    if (tipo == 1) return Icons.arrow_downward_rounded;
    if (tipo == 2) return Icons.arrow_upward_rounded;
    return Icons.swap_horiz_rounded;
  }

  String _normalizarTexto(String texto) {
    var str = texto.trim().toLowerCase();
    const conAcento = 'áàäâãÁÀÄÂÃéèëêÉÈËÊíìïîÍÌÏÎóòöôõÓÒÖÔÕúùüûÚÙÜÛñÑ';
    const sinAcento = 'aaaaaaaaaaeeeeeeeeiiiiiiiioooooooooouuuuuuuuuun';
    for (int i = 0; i < conAcento.length; i++) {
      str = str.replaceAll(conAcento[i], sinAcento[i]);
    }
    return str;
  }

  void _toggleExpansion() async {
    setState(() {
      _isExpanded = !_isExpanded;
    });

    if (_isExpanded && _detail == null && widget.onCargarDetalle != null) {
      setState(() => _isLoadingDetail = true);
      try {
        final res = await widget.onCargarDetalle!(widget.movement.idMovimientoEnc);
        if (mounted) {
          setState(() {
            _detail = res;
            _isLoadingDetail = false;
          });
        }
      } catch (e, stack) {
        debugPrint('--> [MovementCard] Error al cargar detalle: $e\n$stack');
        if (mounted) {
          setState(() => _isLoadingDetail = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final movement = widget.movement;
    final color = _obtenerColor(movement.tipoMovimiento);
    final icon = _obtenerIcono(movement.tipoMovimiento);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fechaFormateada = AppDateUtils.formatDateString(movement.fecha);

    final titulo = movement.isTransfer
        ? 'Transferencia ${AppCurrencyUtils.format(movement.monto.abs(), symbol: '\$')}'
        : movement.conceptoGeneral;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        children: [
          InkWell(
            onTap: _toggleExpansion,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
              child: Row(
                children: [
                  // Icono del tipo de movimiento
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),

                  // Concepto/Título y Subtítulo
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$fechaFormateada • ${movement.lugarNombre.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.lightTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Monto e indicador de acordeón
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatearMonto(movement.monto, movement.tipoMovimiento),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: AppColors.lightTextSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Acordeón Desplegable (Detalle de renglones o transferencia)
          if (_isExpanded) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : AppColors.primary.withValues(alpha: 0.02),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoadingDetail)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (movement.isTransfer) ...[
                    _buildTransferDetail(_detail, fechaFormateada, isDark),
                  ] else ...[
                    _buildRenglonesDetail(_detail, isDark),
                  ],

                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 4),

                  // Botones de acción (Editar / Eliminar)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: widget.onEditar,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Editar', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: widget.onEliminar,
                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                        label: const Text('Eliminar', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.rose,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransferDetail(MovementDetailEntity? detail, String fechaFallback, bool isDark) {
    final fecha = detail != null ? AppDateUtils.formatDateString(detail.fecha) : fechaFallback;

    String origen = widget.movement.lugarNombre.isNotEmpty ? widget.movement.lugarNombre : 'Cuenta Origen';
    String destino = 'Cuenta Destino';

    if (detail != null && detail.detalles.isNotEmpty) {
      final detallesModel = detail.detalles.cast<MovementItemDetailModel>();
      final itemOrigen = detallesModel.firstWhere(
        (d) => d.signo < 0,
        orElse: () => detallesModel.first,
      );
      final itemDestino = detallesModel.firstWhere(
        (d) => d.signo > 0,
        orElse: () => detallesModel.length > 1 ? detallesModel.last : detallesModel.first,
      );
      if (itemOrigen.lugarNombre.isNotEmpty) {
        origen = itemOrigen.lugarNombre;
      }
      if (itemDestino.lugarNombre.isNotEmpty && itemDestino.idMovimientoDet != itemOrigen.idMovimientoDet) {
        destino = itemDestino.lugarNombre;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              'Fecha: $fecha',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.arrow_upward_rounded, size: 16, color: AppColors.rose),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Salió de: $origen',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6.0),
                child: Icon(Icons.arrow_downward_rounded, size: 16, color: AppColors.primary),
              ),
              Row(
                children: [
                  const Icon(Icons.arrow_downward_rounded, size: 16, color: AppColors.emerald),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ingresó en: $destino',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRenglonesDetail(MovementDetailEntity? detail, bool isDark) {
    final detalles = detail?.detalles ?? [];

    final itemsAMostrar = detalles.isNotEmpty
        ? detalles
        : [
            MovementItemDetailEntity(
              idMovimientoDet: 0,
              idLugar: widget.movement.idLugar,
              lugarNombre: widget.movement.lugarNombre,
              idCategoria: widget.movement.idCategoria,
              categoriaNombre: widget.movement.categoriaNombre,
              concepto: widget.movement.conceptoGeneral,
              monto: widget.movement.monto.abs(),
              signo: -1,
              cantidad: 1.0,
              codigo: '',
              img: '',
            ),
          ];

    // Ordenamiento dinámico según las 3 reglas especificadas:
    // 1. Categoría A-Z (sin mayúsculas ni tildes)
    // 2. Monto absoluto de mayor a menor (de más caro a más barato)
    // 3. Desempate por concepto A-Z (sin mayúsculas ni tildes)
    final itemsOrdenados = List<MovementItemDetailEntity>.from(itemsAMostrar);
    itemsOrdenados.sort((a, b) {
      final catA = _normalizarTexto(a.categoriaNombre);
      final catB = _normalizarTexto(b.categoriaNombre);
      final compCat = catA.compareTo(catB);
      if (compCat != 0) return compCat;

      final montoA = a.monto.abs();
      final montoB = b.monto.abs();
      final compMonto = montoB.compareTo(montoA); // De mayor a menor
      if (compMonto != 0) return compMonto;

      final concA = _normalizarTexto(a.concepto.isNotEmpty ? a.concepto : widget.movement.conceptoGeneral);
      final concB = _normalizarTexto(b.concepto.isNotEmpty ? b.concepto : widget.movement.conceptoGeneral);
      return concA.compareTo(concB);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: itemsOrdenados.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 2.0),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white10 : Colors.black12,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // 1. Imagen / Thumbnail
              _buildItemThumbnail(item.img, isDark),
              const SizedBox(width: 10),

              // 2. Categoría
              SizedBox(
                width: 90,
                child: Text(
                  item.categoriaNombre,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),

              // 3. Concepto del Renglón
              Expanded(
                child: Text(
                  item.concepto.isNotEmpty ? item.concepto : widget.movement.conceptoGeneral,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),

              // 4. Monto del Renglón
              Text(
                AppCurrencyUtils.format(-item.monto.abs(), symbol: '\$'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildItemThumbnail(String imgUrl, bool isDark) {
    if (imgUrl.isNotEmpty) {
      if (imgUrl.startsWith('data:image') || imgUrl.startsWith('http')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(
            imgUrl,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallbackThumbnail(isDark),
          ),
        );
      }
    }
    return _fallbackThumbnail(isDark);
  }

  Widget _fallbackThumbnail(bool isDark) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.shopping_bag_outlined, size: 18, color: AppColors.primary),
    );
  }
}
