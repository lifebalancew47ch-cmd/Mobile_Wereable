import 'package:flutter/material.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  static const List<({String q, String a})> _faqs = [
    (
      q: '¿Cómo detecta LifeBalance el sedentarismo?',
      a: 'Tu reloj Wear OS manda muestras de acelerómetro al teléfono cada 5 segundos. El motor Fog (FogEngine) agrupa las muestras en ventanas de 30 segundos y calcula su varianza: si la varianza es menor a 0.05, la ventana se marca como inactiva. Tras 90 ventanas consecutivas (unos 45 minutos, configurable) se dispara la alerta.',
    ),
    (
      q: '¿Por qué se me notifica una alerta de inactividad?',
      a: 'Para recordarte hacer una pausa activa de 2 minutos. La alerta se registra en tu historial local y aparece como notificación en tu teléfono.',
    ),
    (
      q: '¿Cómo emparejo mi reloj Wear OS?',
      a: 'Ve a Perfil > "Emparejar wearable". El teléfono escaneará dispositivos Bluetooth cercanos; selecciona tu reloj para vincularlo. El reloj debe tener la app LifeBalance Wear instalada y el servicio de sensores activo.',
    ),
    (
      q: '¿Dónde se guardan mis datos de actividad?',
      a: 'En una base de datos local cifrada con SQLCipher (AES-256). Las sesiones de actividad, signos vitales y alertas se guardan en tu dispositivo. La sincronización con la nube está pendiente de implementarse.',
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
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _faqs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final faq = _faqs[index];
          return ExpansionTile(
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
          );
        },
      ),
    );
  }
}