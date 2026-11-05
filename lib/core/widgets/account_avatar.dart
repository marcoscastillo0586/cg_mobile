import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import '../network/dio_client.dart';
import 'account_icon_catalog.dart';

/// Resuelve claves del catálogo de íconos (generado desde @cg/shared; ver tools/sync_account_icons.mjs).
class AccountIcons {
  AccountIcons._();

  static final Map<String, AccountIconEntry> _byKey = {for (final e in accountIconCatalog) e.key: e};

  static bool isKnown(String? key) => _byKey.containsKey(key);

  /// La clave si está en el catálogo; si no (o si falta), el ícono de respaldo.
  static String normalize(String? key) => isKnown(key) ? key! : defaultAccountIconKey;

  static String assetFor(String? key) => _byKey[normalize(key)]!.asset;
}

/// Única pieza que resuelve una clave a su imagen: clave desconocida o imagen que no carga → ícono de respaldo.
class AccountAvatar extends StatelessWidget {
  final String? iconRef;
  final double size;

  const AccountAvatar({super.key, this.iconRef, this.size = 40});

  @override
  Widget build(BuildContext context) => Image.asset(
        AccountIcons.assetFor(iconRef),
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Image.asset(
          AccountIcons.assetFor(defaultAccountIconKey),
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      );
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
