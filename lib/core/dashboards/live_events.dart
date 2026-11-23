import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/dio_client.dart';

/// Crea la conexión de avisos en vivo de la pantalla principal (en los tests, una que no se conecta).
final liveEventsProvider =
    Provider<LiveEvents Function(void Function(LiveEvent event))>((ref) => (onEvent) => LiveEvents(ref.read(dioClientProvider), onEvent));

/// Evento en vivo de GET /events (DashboardEventDto de la API).
class LiveEvent {
  /// invitation | notification | dashboard-changed | dashboards-changed | access-removed
  final String type;
  final int? dashboardId;
  const LiveEvent(this.type, this.dashboardId);
}

/// Avisos en vivo (Server-Sent Events) mientras la app está en primer plano: invitaciones al instante y
/// cambios de otros integrantes del dashboard. Si se corta, reconecta con espera creciente; sin conexión
/// no avisa nada (la sincronización periódica cubre lo que se pierda).
class LiveEvents {
  final DioClient _client;
  final void Function(LiveEvent event) _onEvent;
  CancelToken? _cancel;
  var _running = false;

  LiveEvents(this._client, this._onEvent);

  /// El servidor manda un comentario cada 25 s: más de eso sin datos es una conexión caída.
  static const _idle = Duration(seconds: 60);

  void start() {
    if (_running) return;
    _running = true;
    unawaited(_loop());
  }

  void stop() {
    _running = false;
    _cancel?.cancel('stop');
    _cancel = null;
  }

  Future<void> _loop() async {
    var wait = const Duration(seconds: 1);
    while (_running) {
      final cancel = _cancel = CancelToken();
      try {
        final res = await _client.dio.get<ResponseBody>(
          '/events',
          cancelToken: cancel,
          options: Options(responseType: ResponseType.stream, receiveTimeout: _idle, headers: {'Accept': 'text/event-stream'}),
        );
        wait = const Duration(seconds: 1);
        await _listen(res.data!.stream.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()));
      } catch (e) {
        if (!_running) return;
        debugPrint('[EVENTS] Conexión de avisos en vivo cortada; se reintenta: $e');
      }
      if (!_running) return;
      await Future<void>.delayed(wait);
      wait = _backoff(wait);
    }
  }

  /// Espera creciente entre reconexiones: el doble cada vez, hasta 30 s.
  static Duration _backoff(Duration wait) => wait * 2 > const Duration(seconds: 30) ? const Duration(seconds: 30) : wait * 2;

  /// Lee el stream SSE: cada evento termina con una línea vacía.
  Future<void> _listen(Stream<String> lines) async {
    String? type;
    String? data;
    await for (final line in lines) {
      if (!_running) return;
      if (line.startsWith('event:')) type = line.substring(6).trim();
      if (line.startsWith('data:')) data = line.substring(5).trim();
      if (line.isEmpty) {
        _emit(type, data);
        (type, data) = (null, null);
      }
    }
  }

  void _emit(String? type, String? data) {
    if (type == null || type == 'ping' || data == null) return;
    try {
      final json = jsonDecode(data);
      final id = json is Map ? json['dashboardId'] : null;
      _onEvent(LiveEvent(type, id is int ? id : null));
    } catch (e) {
      debugPrint('[EVENTS] Aviso ilegible, se ignora: $e');
    }
  }
}
