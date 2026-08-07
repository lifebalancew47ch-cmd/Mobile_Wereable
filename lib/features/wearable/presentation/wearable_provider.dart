import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/wearable_communication_service.dart';
import '../../../core/utils/app_log.dart';

class WearableState {
  final bool isConnected;
  final AccelerometerData? lastData;
  final WearableSensorSample? lastSample;

  WearableState({
    this.isConnected = false,
    this.lastData,
    this.lastSample,
  });

  WearableState copyWith({
    bool? isConnected,
    AccelerometerData? lastData,
    WearableSensorSample? lastSample,
  }) {
    return WearableState(
      isConnected: isConnected ?? this.isConnected,
      lastData: lastData ?? this.lastData,
      lastSample: lastSample ?? this.lastSample,
    );
  }

  factory WearableState.initial() => WearableState();
}

class WearableNotifier extends StateNotifier<WearableState> {
  final WearableCommunicationService _service;
  StreamSubscription? _sub;
  Timer? _disconnectTimer;

  WearableNotifier(this._service) : super(WearableState.initial()) {
    _initStream();
  }

  void _initStream() {
    debugPrint('[Wearable] WearableNotifier suscribiendo sensorStreamThrottled');
    _sub = _service.sensorStreamThrottled.listen((sample) {
      AppLog.d('[Wearable] Notifier sample: ts=${sample.timestamp} '
          'steps=${sample.steps} hr=${sample.heartRate}');
      _resetDisconnectTimer();
      final accelData = AccelerometerData(
        sample.x,
        sample.y,
        sample.z,
        sample.timestamp,
      );
      state = state.copyWith(
        isConnected: true,
        lastData: accelData,
        lastSample: sample,
      );
    }, onError: (e) {
      debugPrint('[Wearable] Notifier error: $e');
      state = state.copyWith(isConnected: false);
    });
  }

  void _resetDisconnectTimer() {
    _disconnectTimer?.cancel();
    _disconnectTimer = Timer(const Duration(seconds: 15), () {
      if (mounted) {
        debugPrint('[Wearable] Timeout 15s sin lotes -> Reloj desconectado');
        state = state.copyWith(isConnected: false);
      }
    });
  }

  @override
  void dispose() {
    _disconnectTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}

final wearableCommunicationServiceProvider = Provider((ref) => WearableCommunicationService());

final wearableProvider = StateNotifierProvider<WearableNotifier, WearableState>((ref) {
  return WearableNotifier(ref.watch(wearableCommunicationServiceProvider));
});

final sensorSampleProvider = StreamProvider<WearableSensorSample>((ref) {
  final service = ref.watch(wearableCommunicationServiceProvider);
  return service.sensorStreamThrottled;
});
