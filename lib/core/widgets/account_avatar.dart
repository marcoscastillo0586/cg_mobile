import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import '../constants/app_colors.dart';
import '../money/money.dart';
import '../network/dio_client.dart';

/// Íconos de cuenta de la API (`ACCOUNT_ICON_KEYS` de @cg/shared).
class AccountIcons {
  AccountIcons._();

  /// En este orden se muestran al elegir (igual que ACCOUNT_ICON_KEYS de @cg/shared en la web).
  /// `tarjeta_credito` se quitó: "Tarjeta" (`tarjeta_debito`) usa el ícono de tarjeta de crédito.
  static const Map<String, IconData> byKey = {
    'casa': Icons.home_rounded,
    'banco': Icons.account_balance_rounded,
    'alcancia': Icons.savings_rounded,
    'tarjeta_debito': Icons.credit_card_rounded,
    'inversiones': Icons.trending_up_rounded,
    'playa': Icons.beach_access_rounded,
    'plazo_fijo': Icons.lock_clock_rounded,
  };

  /// Íconos que se pueden elegir (ACCOUNT_ICON_SELECTABLE de @cg/shared); el resto se ve pero no se elige.
  static const Set<String> selectable = {'casa', 'banco', 'alcancia', 'tarjeta_debito'};

  static IconData forKey(String? key, Currency currency) =>
      byKey[key] ?? (currency == Currency.usd ? Icons.attach_money_rounded : Icons.wallet_rounded);
}

/// Imagen de una cuenta (`/api/v1/files/:id`, requiere el token) o su ícono.
class AccountAvatar extends ConsumerWidget {
  final String? imageUrl;
  final String? iconRef;
  final Currency currency;
  final double size;

  const AccountAvatar({super.key, this.imageUrl, this.iconRef, required this.currency, this.size = 40});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = currency == Currency.usd ? AppColors.emerald : AppColors.primary;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Icon(AccountIcons.forKey(iconRef, currency), color: color, size: size * 0.55),
    );
    final url = imageUrl;
    if (url == null || url.isEmpty) return fallback;
    final image = ref.watch(protectedImageProvider(url));
    return image.when(
      data: (bytes) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(bytes, width: size, height: size, fit: BoxFit.cover),
      ),
      loading: () => fallback,
      // Si la imagen no se puede bajar se muestra el ícono; el motivo queda registrado.
      error: (e, _) => fallback,
    );
  }
}

/// Descarga con autenticación una imagen servida por la API (se libera al dejar de usarse).
final protectedImageProvider = FutureProvider.autoDispose.family<Uint8List, String>((ref, path) async {
  final client = ref.watch(dioClientProvider);
  final uri = Uri.parse(ApiConfig.requireBaseUrl).replace(path: path).toString();
  try {
    final response = await client.dio.get<List<int>>(uri, options: Options(responseType: ResponseType.bytes));
    return Uint8List.fromList(response.data ?? const []);
  } on DioException catch (e) {
    final error = DioClient.mapDioError(e);
    debugPrint('[IMG] No se pudo descargar $path: $error');
    throw error;
  }
});
