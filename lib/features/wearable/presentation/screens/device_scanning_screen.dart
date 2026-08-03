import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../wearable_provider.dart';

/// Estado real del wearable: conexión Wear OS (Wearable Data Layer) y último
/// lote de datos recibido. La vinculación se hace a nivel de sistema (app
/// Wear OS del teléfono); aquí solo se muestra el estado en vivo del reloj.
class DeviceScanningScreen extends ConsumerStatefulWidget {
  const DeviceScanningScreen({super.key});

  @override
  ConsumerState<DeviceScanningScreen> createState() => _DeviceScanningScreenState();
}

class _DeviceScanningScreenState extends ConsumerState<DeviceScanningScreen> {
  @override
  Widget build(BuildContext context) {
    final wearableState = ref.watch(wearableProvider);
    final connected = wearableState.isConnected;
    final liveSensor = ref.watch(sensorSampleProvider);
    final sample = liveSensor.value;

    return Scaffold(
      backgroundColor: const Color(0xFFE9F1EC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('EXECUTIVE\nWELLNESS',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF3E6F58), letterSpacing: 1.5)
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF3E6F58).withValues(alpha: connected ? 0.25 : 0.1),
                      const Color(0xFFE9F1EC),
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    connected ? Icons.watch : Icons.watch_off,
                    color: connected ? const Color(0xFF3E6F58) : const Color(0xFFD68C5E),
                    size: 64,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              connected ? 'Reloj conectado' : 'Reloj no detectado',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF3E6F58)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Conectado vía Wear OS (Bluetooth). Asegúrate de que el reloj tenga la app LifeBalance abierta y el monitoreo activo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DATOS EN VIVO',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                  const SizedBox(height: 16),
                  if (sample == null)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            CircularProgressIndicator(color: Color(0xFF3E6F58)),
                            SizedBox(height: 12),
                            Text('Esperando datos del reloj...',
                              style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        _buildDataRow('Pasos Acumulados', sample.steps > 0 ? '${sample.steps}' : '--'),
                        const SizedBox(height: 12),
                        _buildDataRow('Ritmo Cardíaco', sample.heartRate > 0 ? '${sample.heartRate.toStringAsFixed(0)} bpm' : '--'),
                        const SizedBox(height: 12),
                        _buildDataRow('VFC (Variabilidad)', sample.hrv > 0 ? '${sample.hrv.toStringAsFixed(1)} ms' : '--'),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F7F4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF3E6F58), size: 18),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'El emparejamiento se realiza desde la app Wear OS del teléfono (no desde esta app). '
                      'Una vez vinculado, los datos del acelerómetro aparecerán aquí automáticamente.',
                      style: TextStyle(color: Colors.grey, fontSize: 11, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E3A34))),
      ],
    );
  }
}
