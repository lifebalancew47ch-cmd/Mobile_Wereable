import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/wearable_communication_service.dart';

class WearableState {
  final bool isConnected;
  final AccelerometerData? lastData;

  WearableState({this.isConnected = false, this.lastData});

  WearableState copyWith({bool? isConnected, AccelerometerData? lastData}) {
    return WearableState(
      isConnected: isConnected ?? this.isConnected,
      lastData: lastData ?? this.lastData,
    );
  }

  factory WearableState.initial() => WearableState();
}

class WearableNotifier extends StateNotifier<WearableState> {
  final WearableCommunicationService _service;
  StreamSubscription? _sub;

  WearableNotifier(this._service) : super(WearableState.initial()) {
    _initStream();
  }

  void _initStream() {
    _sub = _service.accelerometerStreamThrottled.listen((data) {
      state = state.copyWith(isConnected: true, lastData: data);
    }, onError: (e) {
      state = state.copyWith(isConnected: false);
    });
  }

  @override
  void dispose() {
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
