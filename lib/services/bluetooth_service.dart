import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BluetoothService {
  static const String _storageKey = 'linked_device_id';

  // Streams for UI
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;
  Stream<bool> get isScanning => FlutterBluePlus.isScanning;

  /// Starts scanning for Wear OS devices
  Future<void> startScan() async {
    if (await FlutterBluePlus.isSupported == false) return;

    // Scan configuration
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 15),
      androidUsesFineLocation: true,
    );
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  /// Links a device and saves its ID locally
  Future<void> linkDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, device.remoteId.str);
    } catch (e) {
      rethrow;
    }
  }

  /// Unlinks the device
  Future<void> unlinkDevice(BluetoothDevice device) async {
    await device.disconnect();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  /// Gets the saved device ID
  Future<String?> getLinkedDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_storageKey);
  }

  /// Attempts to reconnect to the saved device to verify presence
  Future<BluetoothDevice?> reconnectSavedDevice() async {
    final deviceId = await getLinkedDeviceId();
    if (deviceId == null) return null;

    final device = BluetoothDevice.fromId(deviceId);
    try {
      await device.connect(autoConnect: true, timeout: const Duration(seconds: 5));
      return device;
    } catch (e) {
      return null;
    }
  }
}
