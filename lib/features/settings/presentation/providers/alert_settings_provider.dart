import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/alert_settings_store.dart';
import '../../domain/alert_settings.dart';

final alertSettingsStoreProvider = Provider<AlertSettingsStore>((ref) {
  return AlertSettingsStore();
});

final alertSettingsProvider = StateNotifierProvider.autoDispose<AlertSettingsNotifier, AsyncValue<AlertSettings>>((ref) {
  final store = ref.watch(alertSettingsStoreProvider);
  return AlertSettingsNotifier(store);
});

class AlertSettingsNotifier extends StateNotifier<AsyncValue<AlertSettings>> {
  final AlertSettingsStore _store;

  AlertSettingsNotifier(this._store) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await _store.load();
      state = AsyncValue.data(settings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> save(AlertSettings settings) async {
    state = const AsyncValue.loading();
    try {
      await _store.save(settings);
      state = AsyncValue.data(settings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}