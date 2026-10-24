import 'dart:async';
import 'package:gastos_mobile/core/network/transport_guard.dart';

/// Antes de cada archivo de tests: los servidores simulados usan HTTP.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TransportGuard.debugAllowedHosts.add('api.fake');
  await testMain();
}
