import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Explicación paso a paso (sin video simulado) de cómo funciona LifeBalance.
class VideoExplanationScreen extends StatelessWidget {
  const VideoExplanationScreen({super.key});

  static const List<({String title, String desc, IconData icon})> _steps = [
    (
      title: 'Vincula tu reloj',
      desc: 'Perfil > "Emparejar wearable". El teléfono escanea dispositivos Bluetooth y guarda tu reloj vinculado.',
      icon: Icons.watch_outlined,
    ),
    (
      title: 'El reloj mide tu movimiento',
      desc: 'El acelerómetro de tu Wear OS envía muestras al teléfono cada 5 segundos por la ruta de mensajes del wearable.',
      icon: Icons.sensors_outlined,
    ),
    (
      title: 'El FogEngine analiza',
      desc: 'Cada 30 segundos calcula la varianza de tu movimiento. Si es baja, marca la ventana como inactiva.',
      icon: Icons.memory,
    ),
    (
      title: 'Alerta de sedentarismo',
      desc: 'Tras el umbral configurado (por defecto 45 min) recibe una notificación para hacer una pausa activa.',
      icon: Icons.notifications_active_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Cómo funciona', style: theme.textTheme.titleLarge)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'LifeBalance monitorea tu inactividad con el reloj y un motor Fog local en tu teléfono.',
            style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 24),
          ...List.generate(_steps.length, (i) {
            final step = _steps[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3E6F58),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(step.icon, size: 20, color: const Color(0xFF3E6F58)),
                            const SizedBox(width: 8),
                            Text(step.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(step.desc, style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/fog'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3E6F58),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.memory),
            label: const Text('Ver el estado del Fog', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}