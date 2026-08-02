import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Adaptador HTTP falsificado para pruebas de seguridad de red.
/// Captura las RequestOptions reales (URL, headers, body) y responde
/// según una función programable, sin tocar la red.
class FakeHttpClientAdapter implements HttpClientAdapter {
  FakeHttpClientAdapter({this.onRequest});

  /// Devuelve la ResponseBody a entregar. Si es null, responde 200 OK.
  Future<ResponseBody> Function(RequestOptions options)? onRequest;

  final List<RequestOptions> captured = [];
  int requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured.add(options);
    requestCount++;
    if (onRequest != null) {
      return onRequest!(options);
    }
    return ResponseBody.fromString(
      '{"success":true,"data":{}}',
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Añade un encabezado JSON al body si está ausente.
Map<String, List<String>> jsonHeaders([Map<String, List<String>>? extra]) {
  return {
    Headers.contentTypeHeader: [Headers.jsonContentType],
    ...?extra,
  };
}
