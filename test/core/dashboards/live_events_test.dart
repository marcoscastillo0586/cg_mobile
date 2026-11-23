// Avisos en vivo (Server-Sent Events) contra un servidor SIMULADO: lectura de eventos, avisos ilegibles,
// reconexión al cortarse y fin al pararlos.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/dashboards/live_events.dart';
import 'package:gastos_mobile/core/network/dio_client.dart';

class _Server implements HttpClientAdapter {
  final List<List<String>> streams;
  final requests = <RequestOptions>[];
  _Server(this.streams);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    requests.add(o);
    if (requests.length > streams.length) return Completer<ResponseBody>().future; // queda esperando
    final chunks = streams[requests.length - 1];
    return ResponseBody(Stream.fromIterable([for (final c in chunks) Uint8List.fromList(utf8.encode(c))]), 200,
        headers: {Headers.contentTypeHeader: ['text/event-stream']});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  DioClient client(_Server server) => DioClient(adapter: server)..dio.options.baseUrl = 'http://api.fake/api/v1';

  test('lee cada evento (tipo y dashboard); ignora ping, avisos sin datos o ilegibles; reconecta si se corta', () async {
    final server = _Server([
      [
        ': comentario\n\n',
        'event: invitation\ndata: {"dashboardId": 7}\n\n',
        'event: ping\ndata: {}\n\n',
        'event: notification\n\n',
        'data: {"dashboardId": 1}\n\n',
        'event: dashboard-changed\ndata: no es json\n\n',
        'event: dashboards-changed\ndata: {"dashboardId": "x"}\n',
        '\n',
      ],
      ['event: access-removed\ndata: {"dashboardId": 9}\n\n'],
    ]);
    final events = <LiveEvent>[];
    final done = Completer<void>();
    final live = LiveEvents(client(server), (e) {
      events.add(e);
      if (e.type == 'access-removed') done.complete();
    });
    live.start();
    live.start(); // ya está corriendo: no abre otra conexión
    await done.future.timeout(const Duration(seconds: 5));
    live.stop();
    expect([for (final e in events) (e.type, e.dashboardId)], [('invitation', 7), ('dashboards-changed', null), ('access-removed', 9)]);
    expect(server.requests, hasLength(2));
    expect(server.requests.first.path, '/events');
    expect(server.requests.first.headers['Accept'], 'text/event-stream');
  });

  test('parado no vuelve a conectar', () async {
    final server = _Server([[]]);
    final live = LiveEvents(client(server), (_) {});
    live.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    live.stop();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    expect(server.requests, hasLength(1));
  });
}
