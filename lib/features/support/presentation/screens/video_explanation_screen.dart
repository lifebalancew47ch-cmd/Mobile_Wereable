import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Explicación paso a paso de cómo funciona LifeBalance con acceso directo al video web.
class VideoExplanationScreen extends StatelessWidget {
  const VideoExplanationScreen({super.key});

  static const List<({String title, String desc, IconData icon})> _steps = [
    (
      title: 'Vincula tu reloj',
      desc: 'Empareja tu reloj desde la app Wear OS del teléfono (Bluetooth). LifeBalance detecta la conexión automáticamente.',
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
      desc: 'Tras tu tiempo personalizado de inactividad (configurable de 1 a 120 min) recibes una notificación para hacer una pausa activa.',
      icon: Icons.notifications_active_outlined,
    ),
  ];

  Future<void> _launchVideo() async {
    final uri = Uri.parse('https://lifebalance-adv3.onrender.com/videos/VideoExplicativo_LifeBalance.mp4');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

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
          ElevatedButton.icon(
            onPressed: _launchVideo,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3E6F58),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.play_circle_fill),
            label: const Text('Ver video explicativo en la web', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                    decoration: const BoxDecoration(
                      color: Color(0xFF3E6F58),
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
                        Text(step.desc, style: const TextStyle(color: Colors.black54, fontSize: 13, height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => context.push('/fog'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF3E6F58),
              side: const BorderSide(color: Color(0xFF3E6F58)),
              minimumSize: const Size(double.infinity, 52),
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