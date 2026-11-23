import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../errors/error_messages.dart';
import '../../l10n/l10n.dart';

/// Primera carga de una lista que falló: motivo (con su código) y "Reintentar". Es un ListView para que
/// también se pueda arrastrar para actualizar.
class LoadErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  final double top;
  const LoadErrorView({super.key, required this.error, required this.onRetry, this.top = 80});

  @override
  Widget build(BuildContext context) => ListView(
        children: [
          SizedBox(height: top),
          const Icon(Icons.cloud_off_rounded, size: 54, color: AppColors.rose),
          const SizedBox(height: 12),
          Text(
            ErrorMessages.withCode(error, context.l10n, sep: '\n'),
            key: const ValueKey('error-carga'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Center(child: ElevatedButton(onPressed: onRetry, child: Text(context.l10n.retry))),
        ],
      );
}
