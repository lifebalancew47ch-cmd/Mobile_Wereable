import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothScreen extends StatefulWidget {
  const BluetoothScreen({super.key});

  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<bool>? _isScanningSubscription;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isScanningSubscription = FlutterBluePlus.isScanning.listen((scanning) {
      if (mounted) {
        setState(() => _isScanning = scanning);
      }
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _isScanningSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _requestPermissionsAndScan() async {
    // Solicitar permisos de Bluetooth
    final bluetoothScan = await Permission.bluetoothScan.request();
    final bluetoothConnect = await Permission.bluetoothConnect.request();
    final location = await Permission.locationWhenInUse.request();

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

    setState(() {
      _error = null;
      _scanResults = [];
    });

    _startScan();
  }

  void _startScan() {
    _scanSubscription?.cancel();
    _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      if (mounted) {
        setState(() {
          // Filtrar dispositivos sin nombre
          _scanResults = results
              .where((r) => r.device.platformName.isNotEmpty)
              .toList()
            ..sort((a, b) => b.rssi.compareTo(a.rssi));
        });
      }
    });

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      FlutterBluePlus.stopScan();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Conectando a ${device.platformName}...')),
        );
      }

      await device.connect(timeout: const Duration(seconds: 10));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conectado a ${device.platformName}'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al conectar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  int _getSignalStrength(int rssi) {
    if (rssi >= -50) return 3;
    if (rssi >= -70) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar dispositivo'),
      ),
      body: Column(
        children: [
          // Botón de escaneo
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isScanning ? null : _requestPermissionsAndScan,
                icon: _isScanning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.bluetooth_searching),
                label: Text(_isScanning ? 'Escaneando...' : 'Iniciar escaneo'),
              ),
            ),
          ),

          // Error
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

          // Indicador de escaneo
          if (_isScanning)
            const LinearProgressIndicator(),

          // Lista de dispositivos
          Expanded(
            child: _scanResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isScanning
                              ? 'Buscando dispositivos cercanos...'
                              : 'Presiona "Iniciar escaneo" para buscar',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: _scanResults.length,
                    itemBuilder: (context, index) {
                      final result = _scanResults[index];
                      final device = result.device;
                      final signalStrength = _getSignalStrength(result.rssi);

                      return Card(
                        child: ListTile(
                          leading: Icon(
                            Icons.watch,
                            color: colorScheme.primary,
                            size: 32,
                          ),
                          title: Text(
                            device.platformName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(device.remoteId.toString()),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Indicador de señal
                              Icon(
                                signalStrength >= 3
                                    ? Icons.signal_cellular_alt
                                    : signalStrength >= 2
                                        ? Icons.signal_cellular_alt_2_bar
                                        : Icons.signal_cellular_alt_1_bar,
                                color: signalStrength >= 3
                                    ? Colors.green
                                    : signalStrength >= 2
                                        ? Colors.orange
                                        : Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: () => _connectToDevice(device),
                                child: const Text('Vincular'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
