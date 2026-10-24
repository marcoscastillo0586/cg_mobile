// HTTP solo hacia hosts permitidos (igual en debug y release); el resto exige HTTPS.
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/core/network/dio_client.dart';

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
}
