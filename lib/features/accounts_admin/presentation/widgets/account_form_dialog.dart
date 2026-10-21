import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../domain/entities/account_admin_entity.dart';

class AccountFormDialog extends StatefulWidget {
  final AccountAdminEntity? cuenta;
  final Future<bool> Function({
    required String nombre,
    required int tipoMoneda,
    required bool activo,
    String? img,
  }) onGuardar;

  const AccountFormDialog({
    super.key,
    this.cuenta,
    required this.onGuardar,
  });

  @override
  State<AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends State<AccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;
  late int _tipoMoneda;
  late bool _activo;
  int _selectedIconIndex = 0;
  bool _isSaving = false;

  static const List<IconData> _iconosDisponibles = [
    Icons.account_balance_wallet_rounded,
    Icons.account_balance_rounded,
    Icons.credit_card_rounded,
    Icons.savings_rounded,
    Icons.attach_money_rounded,
    Icons.storefront_rounded,
    Icons.payments_rounded,
    Icons.wallet_rounded,
    Icons.monetization_on_rounded,
  ];

  bool get isEditing => widget.cuenta != null;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.cuenta?.nombre ?? '');
    _tipoMoneda = widget.cuenta?.tipoMoneda ?? 1; // Por defecto: 1 (ARS)
    _activo = widget.cuenta?.activo ?? true;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    AppFeedback.light();

    final ok = await widget.onGuardar(
      nombre: _nombreController.text.trim(),
      tipoMoneda: _tipoMoneda,
      activo: _activo,
      img: 'icon_$_selectedIconIndex',
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isEditing ? Icons.edit_note_rounded : Icons.account_balance_wallet_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isEditing ? 'Editar Cuenta' : 'Nueva Cuenta',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Nombre de la cuenta (Máximo 20 caracteres alfanuméricos)
              const Text(
                'Nombre (máx. 20 alfanuméricos)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nombreController,
                maxLength: 20,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(20),
                ],
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Ej: Mercado Pago',
                  prefixIcon: Icon(Icons.label_outline_rounded, size: 20),
                  counterText: '',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Ingresa un nombre para la cuenta';
                  }
                  final trimmed = val.trim();
                  if (trimmed.length < 2) {
                    return 'El nombre debe tener al menos 2 caracteres';
                  }
                  if (trimmed.length > 20) {
                    return 'El nombre no puede superar los 20 caracteres';
                  }
                  final alphaNumericRegex = RegExp(r'^[a-zA-Z0-9áéíóúÁÉÍÓÚñÑ\s]+$');
                  if (!alphaNumericRegex.hasMatch(trimmed)) {
                    return 'Solo se permiten caracteres alfanuméricos';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 2. Moneda principal (Preseleccionada y resaltada por defecto en ARS)
              const Text(
                'Moneda principal',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            r'Pesos (ARS $)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                      selected: _tipoMoneda == 1,
                      selectedColor: AppColors.primary.withValues(alpha: 0.25),
                      checkmarkColor: AppColors.primary,
                      side: BorderSide(
                        color: _tipoMoneda == 1 ? AppColors.primary : (isDark ? Colors.white24 : Colors.black12),
                        width: _tipoMoneda == 1 ? 2 : 1,
                      ),
                      onSelected: (_) {
                        AppFeedback.selection();
                        setState(() => _tipoMoneda = 1);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            r'Dólares (USD $)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                      selected: _tipoMoneda == 2,
                      selectedColor: AppColors.emerald.withValues(alpha: 0.25),
                      checkmarkColor: AppColors.emerald,
                      side: BorderSide(
                        color: _tipoMoneda == 2 ? AppColors.emerald : (isDark ? Colors.white24 : Colors.black12),
                        width: _tipoMoneda == 2 ? 2 : 1,
                      ),
                      onSelected: (_) {
                        AppFeedback.selection();
                        setState(() => _tipoMoneda = 2);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 3. Selector de Iconos (Wrap limpio en lugar de GridView)
              const Text(
                'Icono de la cuenta',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_iconosDisponibles.length, (index) {
                  final icon = _iconosDisponibles[index];
                  final isSelected = _selectedIconIndex == index;

                  return InkWell(
                    onTap: () {
                      AppFeedback.selection();
                      setState(() => _selectedIconIndex = index);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: isSelected ? AppColors.primary : (isDark ? Colors.white70 : Colors.black54),
                        size: 22,
                      ),
                    ),
                  );
                }),
              ),

              // 4. Estado Activo (solo al editar)
              if (isEditing) ...[
                const SizedBox(height: 14),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Cuenta Activa',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    _activo
                        ? 'Visible en formularios y saldos'
                        : 'Oculta en nuevos egresos e ingresos',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  value: _activo,
                  activeThumbColor: AppColors.emerald,
                  onChanged: (val) {
                    AppFeedback.selection();
                    setState(() => _activo = val);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(isEditing ? 'Guardar Cambios' : 'Crear Cuenta'),
        ),
      ],
    );
  }
}
