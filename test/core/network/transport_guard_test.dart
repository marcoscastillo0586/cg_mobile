// HTTPS siempre; HTTP solo hacia hosts permitidos. La PC de casa (192.168.0.50) solo en debug: el
// APK release no acepta HTTP hacia ningún host (los tests corren en debug).
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/core/network/dio_client.dart';
import 'package:gastos_mobile/core/network/transport_guard.dart';

class _Ok implements HttpClientAdapter {
  final hosts = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    hosts.add(o.uri.host);
    return ResponseBody.fromString('{}', 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  Future<Object?> call(String base, _Ok adapter) async {
    final c = DioClient(adapter: adapter)..dio.options.baseUrl = base;
    try {
      await c.get('/x');
      return null;
    } catch (e) {
      return e;
    }
  }

  test('HTTP a un host no permitido no sale: INSECURE_TRANSPORT', () async {
    final a = _Ok();
    final e = await call('http://otro.host/api/v1', a);
    expect(e, isA<ServerException>().having((x) => x.code, 'code', 'INSECURE_TRANSPORT'));
    expect(a.hosts, isEmpty, reason: 'la petición no llegó a la red');
  });

  test('HTTPS siempre; HTTP solo hacia un host permitido', () async {
    final a = _Ok();
    expect(await call('https://otro.host/api/v1', a), isNull);
    expect(await call('http://192.168.0.50:3000/api/v1', a), isNull);
    expect(a.hosts, ['otro.host', '192.168.0.50']);
  });

  test('producción (VPS) por HTTPS pasa', () async {
    final a = _Ok();
    expect(await call('https://controldegastos.codigo15.com.ar/api/v1', a), isNull);
    expect(a.hosts, ['controldegastos.codigo15.com.ar']);
  });

  test('la PC de casa con HTTP solo figura en debug', () {
    expect(kDebugMode, isTrue, reason: 'flutter test corre en debug');
    expect(TransportGuard.httpAllowedHosts.contains(TransportGuard.devLanHost), kDebugMode);
  });
}
