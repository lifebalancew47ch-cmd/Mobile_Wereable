import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Mantiene un identificador de dispositivo estable para la sincronización.
/// Se persiste en SharedPreferences para no regenerarlo en cada arranque.
class DeviceIdentityService {
  static const _kDeviceId = 'lifebalance_device_id';
  String? _cached;

  Future<String> getDeviceId() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kDeviceId);
    if (id == null || id.isEmpty) {
      id = _generate();
      await prefs.setString(_kDeviceId, id);
    }
    _cached = id;
    return id;
  }

  String _generate() {
    final rnd = Random.secure();
    final time = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    final rand = rnd.nextInt(0xFFFFFF).toRadixString(16);
    return 'dev-$time-$rand';
  }
}