import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../data/datasources/secure_database_service.dart';
import '../../../../services/bluetooth_service.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  static const _kRealtimeAlerts = 'device_manage_realtime_alerts';
  static const _kAutoSync = 'device_manage_auto_sync';
  static const _kLowPower = 'device_manage_low_power';

  final BluetoothService _bluetooth = BluetoothService();
  fbp.BluetoothDevice? _device;
  bool _loading = true;
  bool _realtimeAlerts = true;
  bool _autoSync = true;
  bool _lowPower = false;
  String? _lastSyncLabel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await _bluetooth.getLinkedDeviceId();
    var lastSync = 'Nunca';
    if (deviceId != null) {
      final device = await _bluetooth.reconnectSavedDevice();
      if (device != null) {
        final lastSession = await _lastActivityTime();
        lastSync = lastSession ?? 'Hace un momento';
      } else {
        lastSync = 'Dispositivo no encontrado';
      }
    }
    if (!mounted) return;
    setState(() {
      _device = deviceId != null ? fbp.BluetoothDevice.fromId(deviceId) : null;
      _realtimeAlerts = prefs.getBool(_kRealtimeAlerts) ?? true;
      _autoSync = prefs.getBool(_kAutoSync) ?? true;
      _lowPower = prefs.getBool(_kLowPower) ?? false;
      _lastSyncLabel = lastSync;
      _loading = false;
    });
  }

  Future<String?> _lastActivityTime() async {
    try {
      final db = SecureDatabaseService.instance;
      final last = await db.getLastActivitySession();
      final start = DateTime.tryParse((last?['start_time'] as String?) ?? '');
      if (start == null) return null;
      final diff = DateTime.now().difference(start);
      if (diff.inMinutes < 1) return 'Hace un momento';
      if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
      return 'Hace ${diff.inDays} d';
    } catch (_) {
      return null;
    }
  }

  Future<void> _savePref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _disconnect() async {
    if (_device == null) return;
    try {
      await _bluetooth.unlinkDevice(_device!);
      if (!mounted) return;
      setState(() => _device = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dispositivo desconectado'),
          backgroundColor: Color(0xFFD68C5E),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al desconectar: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: const Color(0xFFD68C5E),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9F1EC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: const BackButton(color: Color(0xFF3E6F58)),
        title: const Text('Gestión de Dispositivo',
          style: TextStyle(color: Color(0xFF3E6F58), fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('DISPOSITIVO CONECTADO',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: _loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(color: Color(0xFF3E6F58)),
                      ),
                    )
                  : _device == null
                      ? Column(
                          children: [
                            const Icon(Icons.bluetooth_disabled, color: Colors.grey, size: 48),
                            const SizedBox(height: 12),
                            const Text(
                              'No hay dispositivo vinculado',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Escanea y vincula tu wearable desde la pantalla de dispositivos.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.bluetooth_searching, size: 16),
                              label: const Text('Ir a escanear'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3E6F58),
                                foregroundColor: Colors.white,
                                elevation: 0,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: const Color(0xFFF0F7F4), borderRadius: BorderRadius.circular(12)),
                                  child: const Icon(Icons.watch_rounded, color: Color(0xFF3E6F58), size: 28),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_device!.platformName.isNotEmpty ? _device!.platformName : 'Dispositivo vinculado',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                      Text(_device!.remoteId.str, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          if (_device!.isConnected)
                                            const Icon(Icons.bluetooth_connected, color: Color(0xFF3E6F58), size: 12),
                                          const SizedBox(width: 4),
                                          Text(
                                            _device!.isConnected ? 'Conectado via Bluetooth' : 'Guardado (offline)',
                                            style: TextStyle(
                                              color: _device!.isConnected ? const Color(0xFF3E6F58) : Colors.grey,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Última sinc.', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                    Text(_lastSyncLabel ?? 'Nunca', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                                ElevatedButton(
                                  onPressed: _disconnect,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFEF3EB),
                                    foregroundColor: const Color(0xFFD68C5E),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Desconectar', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
            ),

            const SizedBox(height: 32),
            const Text('SINCRONIZACIÓN',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  _buildSyncOption(Icons.notifications_active_outlined, 'Alertas en tiempo real', 'Notificaciones inmediatas de salud', _realtimeAlerts,
                      (v) { setState(() => _realtimeAlerts = v); _savePref(_kRealtimeAlerts, v); }),
                  const Divider(indent: 50),
                  _buildSyncOption(Icons.sync, 'Sincronización de datos', 'Cloud backup automático', _autoSync,
                      (v) { setState(() => _autoSync = v); _savePref(_kAutoSync, v); }),
                  const Divider(indent: 50),
                  _buildSyncOption(Icons.battery_saver_outlined, 'Modo de bajo consumo', 'Extiende la vida útil al 40%', _lowPower,
                      (v) { setState(() => _lowPower = v); _savePref(_kLowPower, v); }),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF3E6F58), size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(color: Colors.grey, fontSize: 11, height: 1.4),
                      children: [
                        TextSpan(text: 'Las configuraciones avanzadas de telemetría se encuentran disponibles en el portal web de '),
                        TextSpan(text: 'Executive Wellness.', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3E6F58))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncOption(IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFFF0F7F4), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: const Color(0xFF3E6F58), size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFF3E6F58),
      ),
    );
  }
}
