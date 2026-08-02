import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../services/bluetooth_service.dart' as service;

class BluetoothScreen extends StatefulWidget {
  const BluetoothScreen({super.key});

  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  final service.BluetoothService _bluetoothService = service.BluetoothService();
  BluetoothDevice? _connectedDevice;
  String? _savedDeviceId;
  bool _isInitReconnecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkSavedDevice();
  }

  Future<void> _checkSavedDevice() async {
    setState(() => _isInitReconnecting = true);
    _savedDeviceId = await _bluetoothService.getLinkedDeviceId();
    if (_savedDeviceId != null) {
      _connectedDevice = await _bluetoothService.reconnectSavedDevice();
    }
    setState(() => _isInitReconnecting = false);
  }

  Future<void> _requestPermissionsAndScan() async {
    final bluetoothScan = await Permission.bluetoothScan.request();
    final bluetoothConnect = await Permission.bluetoothConnect.request();
    await Permission.locationWhenInUse.request();

    if (bluetoothScan.isDenied || bluetoothConnect.isDenied) {
      setState(() => _error = 'Se necesitan permisos de Bluetooth para escanear.');
      return;
    }

    // Verificar que Bluetooth esté encendido
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      setState(() => _error = 'Por favor, enciende el Bluetooth.');
      return;
    }

    setState(() => _error = null);
    await _bluetoothService.startScan();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de Dispositivo'),
      ),
      body: Column(
        children: [
          _buildStatusCard(colorScheme),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                color: colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Dispositivos cercanos', style: theme.textTheme.titleMedium),
                StreamBuilder<bool>(
                  stream: _bluetoothService.isScanning,
                  initialData: false,
                  builder: (context, snapshot) {
                    if (snapshot.data == true) {
                      return const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    return TextButton.icon(
                      onPressed: _requestPermissionsAndScan,
                      icon: const Icon(Icons.search),
                      label: const Text('Buscar'),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ScanResult>>(
              stream: _bluetoothService.scanResults,
              initialData: const [],
              builder: (context, snapshot) {
                final results = snapshot.data!
                    .where((r) => r.device.platformName.isNotEmpty)
                    .toList();

                if (results.isEmpty) {
                  return const Center(
                    child: Text('No hay dispositivos encontrados', style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final result = results[index];
                    final device = result.device;

                    return ListTile(
                      leading: const Icon(Icons.watch),
                      title: Text(device.platformName),
                      subtitle: Text(device.remoteId.str),
                      trailing: FilledButton(
                        onPressed: () async {
                          try {
                            await _bluetoothService.linkDevice(device);
                            _checkSavedDevice();
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error al vincular: $e')),
                            );
                          }
                        },
                        child: const Text('Vincular'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(ColorScheme colorScheme) {
    String statusText = 'No Vinculado';
    IconData statusIcon = Icons.bluetooth_disabled;
    Color statusColor = colorScheme.error;

    if (_isInitReconnecting) {
      statusText = 'Buscando dispositivo vinculado...';
      statusIcon = Icons.sync;
      statusColor = colorScheme.primary;
    } else if (_connectedDevice != null) {
      statusText = 'Conectado: ${_connectedDevice!.platformName}';
      statusIcon = Icons.bluetooth_connected;
      statusColor = Colors.green;
    } else if (_savedDeviceId != null) {
      statusText = 'Vinculado: $_savedDeviceId';
      statusIcon = Icons.bluetooth_searching;
      statusColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.all(16),
      color: statusColor.withValues(alpha: 0.1),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor, size: 32),
        title: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
        trailing: _savedDeviceId != null
          ? IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('linked_device_id');
                if (_connectedDevice != null) {
                  await _connectedDevice!.disconnect();
                  _connectedDevice = null;
                }
                _checkSavedDevice();
              },
            )
          : null,
      ),
    );
  }
}
