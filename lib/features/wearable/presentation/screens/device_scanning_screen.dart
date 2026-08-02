import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import '../../../../services/bluetooth_service.dart';

class DeviceScanningScreen extends StatefulWidget {
  const DeviceScanningScreen({super.key});

  @override
  State<DeviceScanningScreen> createState() => _DeviceScanningScreenState();
}

class _DeviceScanningScreenState extends State<DeviceScanningScreen> {
  final BluetoothService _bluetooth = BluetoothService();
  StreamSubscription? _resultsSub;
  StreamSubscription? _scanningSub;
  bool _isScanning = false;
  List<fbp.ScanResult> _devices = [];
  String? _linkedDeviceId;
  bool _isPairing = false;

  @override
  void initState() {
    super.initState();
    _resultsSub = _bluetooth.scanResults.listen((results) {
      if (!mounted) return;
      setState(() {
        _devices = results.where((r) => r.device.platformName.isNotEmpty).toList();
      });
    });
    _scanningSub = _bluetooth.isScanning.listen((value) {
      if (!mounted) return;
      setState(() => _isScanning = value);
    });
    _loadLinkedDevice();
  }

  Future<void> _loadLinkedDevice() async {
    final id = await _bluetooth.getLinkedDeviceId();
    if (!mounted) return;
    setState(() => _linkedDeviceId = id);
  }

  Future<void> _toggleScan() async {
    if (_isScanning) {
      await _bluetooth.stopScan();
      return;
    }
    if (!mounted) return;
    setState(() => _devices = []);
    try {
      await _bluetooth.startScan();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo iniciar el escaneo: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: const Color(0xFFD68C5E),
        ),
      );
    }
  }

  Future<void> _pairDevice(fbp.BluetoothDevice device) async {
    if (_isPairing) return;
    setState(() => _isPairing = true);
    try {
      await _bluetooth.linkDevice(device);
      await _bluetooth.stopScan();
      if (!mounted) return;
      setState(() => _linkedDeviceId = device.remoteId.str);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vinculado: ${device.platformName}'),
          backgroundColor: const Color(0xFF3E6F58),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo vincular: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: const Color(0xFFD68C5E),
        ),
      );
    } finally {
      if (mounted) setState(() => _isPairing = false);
    }
  }

  @override
  void dispose() {
    _resultsSub?.cancel();
    _scanningSub?.cancel();
    _bluetooth.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9F1EC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('EXECUTIVE\nWELLNESS',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF3E6F58), letterSpacing: 1.5)
        ),
        actions: [
          IconButton(
            onPressed: _toggleScan,
            icon: Icon(
              _isScanning ? Icons.stop_circle_outlined : Icons.bluetooth_searching,
              color: _isScanning ? const Color(0xFFD68C5E) : const Color(0xFF3E6F58),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF3E6F58).withValues(alpha: _isScanning ? 0.2 : 0.1),
                        const Color(0xFFE9F1EC),
                      ],
                    ),
                  ),
                ),
                ...List.generate(3, (index) => AnimatedOpacity(
                  opacity: _isScanning ? 1.0 : 0.3,
                  duration: Duration(milliseconds: 500 + index * 200),
                  child: Container(
                    width: 80.0 + (index * 60),
                    height: 80.0 + (index * 60),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF3E6F58).withValues(alpha: 0.2)),
                    ),
                  ),
                )),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Icon(
                    _linkedDeviceId != null ? Icons.bluetooth_connected : Icons.bluetooth,
                    color: _linkedDeviceId != null ? const Color(0xFF3E6F58) : const Color(0xFFD68C5E),
                    size: 40,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Text(_isScanning ? 'Buscando dispositivos...' : (_linkedDeviceId != null ? 'Dispositivo vinculado' : 'Inicia el escaneo'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF3E6F58))),
          const SizedBox(height: 8),
          const Text('Asegúrate de que tu dispositivo esté en\nmodo emparejamiento.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13)),

          const SizedBox(height: 40),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DISPOSITIVOS CERCANOS',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                  const SizedBox(height: 16),
                  if (_devices.isEmpty && !_isScanning)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Text(
                        'Ningún dispositivo detectado.\nPulsa el ícono para escanear.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.5),
                      ),
                    )
                  else
                    ..._devices.map((result) => _buildDeviceItem(result)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(fbp.ScanResult result) {
    final device = result.device;
    final isLinked = device.remoteId.str == _linkedDeviceId;
    final rssi = result.rssi;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFF0F7F4), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.watch_rounded, color: Color(0xFF3E6F58), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.platformName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(_signalLabel(rssi), style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          isLinked
              ? const Icon(Icons.check_circle, color: Color(0xFF3E6F58), size: 24)
              : ElevatedButton(
                  onPressed: _isPairing ? null : () => _pairDevice(device),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3E6F58),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Pair', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
        ],
      ),
    );
  }

  String _signalLabel(int rssi) {
    if (rssi >= -60) return 'Señal fuerte';
    if (rssi >= -80) return 'Señal media';
    return 'Señal débil';
  }
}
