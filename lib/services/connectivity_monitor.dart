import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Monitor de conectividad para disparar la sincronización inmediata al
/// recuperar internet (Offline-First).
class ConnectivityMonitor {
  final Connectivity _connectivity;
  StreamController<bool>? _controller;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  ConnectivityMonitor([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  /// Stream de `true/false` según haya o no conexión a internet.
  Stream<bool> get onlineStream {
    _controller ??= StreamController<bool>.broadcast();
    _sub ??= _connectivity.onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (!_controller!.isClosed) {
        _controller!.add(online);
      }
    });
    return _controller!.stream;
  }

  void dispose() {
    _sub?.cancel();
    _controller?.close();
  }
}