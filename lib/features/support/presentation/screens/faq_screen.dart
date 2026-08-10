import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  Future<void> _launchVideo() async {
    final uri = Uri.parse('https://lifebalance-adv3.onrender.com/videos/VideoExplicativo_LifeBalance.mp4');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      } catch (_) {}
    }
  }

  static const List<({String q, String a})> _faqs = [
    (
      q: '¿Cómo detecta LifeBalance el sedentarismo?',
      a: 'Tu reloj Wear OS manda muestras de acelerómetro al teléfono cada 5 segundos. El motor Fog (FogEngine) agrupa las muestras en ventanas de 30 segundos y calcula su varianza: si la varianza es menor a 0.05, la ventana se marca como inactiva. Tras acumular las ventanas según tu tiempo personalizado (30s por ventana, configurable de 1 a 120 min) se dispara la alerta.',
    ),
    (
      q: '¿Por qué se me notifica una alerta de inactividad?',
      a: 'Para recordarte hacer una pausa activa de 2 minutos. La alerta se registra en tu historial local y aparece como notificación en tu teléfono.',
    ),
    (
      q: '¿Cómo conecto mi reloj Wear OS?',
      a: 'El emparejamiento se hace a nivel del sistema: en la app Wear OS de tu teléfono debes vincular el reloj por Bluetooth. La app LifeBalance detecta automáticamente esa conexión (Wearable Data Layer) y muestra el estado en Perfil > "Emparejar wearable". El reloj debe tener la app LifeBalance Wear instalada y el servicio de sensores activo.',
    ),
    (
      q: '¿Dónde se guardan mis datos de actividad?',
      a: 'En una base de datos local cifrada con SQLCipher (AES-256). Las sesiones de actividad, signos vitales y alertas se guardan en tu dispositivo y se sincronizan con la nube cada 15 minutos cuando hay conexión.',
    ),
    (
      q: '¿Qué significa el puntaje de sedentarismo?',
      a: 'Es la proporción entre tus minutos inactivos acumulados y el umbral de alerta (90 ventanas). 0 = activo, acercándose a 1 = riesgo alto de alerta inminente.',
    ),
    (
      q: '¿La app necesita internet?',
      a: 'El análisis Fog es 100% local: los datos del acelerómetro se procesan en tu teléfono sin salir de él. Solo el inicio de sesión, el perfil y las notificaciones requieren conexión a tu cuenta.',
    ),
    (
      q: '¿Cómo protejo mi cuenta?',
      a: 'Usa una contraseña de mínimo 8 caracteres. Puedes además activar la autenticación biométrica en Perfil > "Perfil Biométrico" para proteger tu acceso.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Centro de Ayuda', style: theme.textTheme.titleLarge)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _QuickAccessCard(
                  icon: Icons.play_circle_outline,
                  title: 'Ver explicación',
                  onTap: _launchVideo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickAccessCard(
                  icon: Icons.memory_outlined,
                  title: 'Estado del Fog',
                  onTap: () => context.push('/fog'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ..._faqs.map(
            (faq) => ExpansionTile(
              shape: const Border(),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: Text(
                faq.q,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(faq.a, style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _QuickAccessCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF3E6F58),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}