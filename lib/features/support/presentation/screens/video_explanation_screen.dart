import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class VideoExplanationScreen extends StatelessWidget {
  const VideoExplanationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('LifeBalance Watch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: CircleAvatar(radius: 14, backgroundImage: NetworkImage('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=150')),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Center(
              child: Column(
                children: [
                  Text('INTELIGENCIA ARTIFICIAL ACTIVA', style: TextStyle(color: Color(0xFF00C2FF), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  SizedBox(height: 12),
                  Text(
                    'Vea LifeBalance en Acción',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, height: 1.1),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Descubra cómo nuestra tecnología de visión computacional detecta micro-patrones de sedentarismo en tiempo real.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Simulación de Reproductor de Video
            Container(
              height: 240,
              decoration: BoxDecoration(
                color: const Color(0xFF161F30),
                borderRadius: BorderRadius.circular(24),
                image: const DecorationImage(
                  image: NetworkImage('https://images.unsplash.com/photo-1497366216548-37526070297c?q=80&w=600'),
                  fit: BoxFit.cover,
                  opacity: 0.3,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(color: const Color(0xFF4A80FF), shape: BoxShape.circle),
                    padding: const EdgeInsets.all(16),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Row(
                      children: [
                        const Icon(Icons.pause, color: Colors.white, size: 16),
                        const SizedBox(width: 12),
                        Expanded(
                          child: LinearProgressIndicator(value: 0.3, backgroundColor: Colors.white12, color: const Color(0xFF4A80FF)),
                        ),
                        const SizedBox(width: 12),
                        const Text('02:45 / 08:12', style: TextStyle(color: Colors.white, fontSize: 10)),
                        const SizedBox(width: 12),
                        const Icon(Icons.volume_up, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Feature Highlights (Sidebar style adapted)
            _buildFeatureHighlight(
              number: '01',
              title: 'Visión Espacial',
              desc: 'Mapeo 3D del entorno para identificar posturas que comprometen la circulación.',
              icon: Icons.visibility_outlined,
            ),
            const SizedBox(height: 16),
            _buildFeatureHighlight(
              number: '02',
              title: 'Métricas de Fatiga',
              desc: 'Algoritmos avanzados que predicen el agotamiento cognitivo antes de que ocurra.',
              icon: Icons.psychology_outlined,
              isActive: true,
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () => context.push('/fog'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A80FF),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Ver Demo en Vivo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  SizedBox(width: 12),
                  Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // Value Propositions Grid
            Row(
              children: [
                Expanded(child: _buildPropItem(Icons.security, 'Privacidad por Diseño', 'Procesamiento local sin almacenamiento de imágenes.')),
                const SizedBox(width: 16),
                Expanded(child: _buildPropItem(Icons.bolt, 'Latencia Cero', 'Notificaciones instantáneas vía wearable.')),
              ],
            ),
            const SizedBox(height: 16),
            _buildPropItem(Icons.account_tree_outlined, 'Ecosistema Abierto', 'Integración nativa con Slack, Teams y herramientas de RRHH.', isFull: true),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureHighlight({required String number, required String title, required String desc, required IconData icon, bool isActive = false}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161F30),
        borderRadius: BorderRadius.circular(20),
        border: isActive ? Border.all(color: const Color(0xFF00C2FF).withOpacity(0.3)) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF00C2FF), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
          Text(number, style: const TextStyle(color: Colors.white10, fontSize: 32, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPropItem(IconData icon, String title, String desc, {bool isFull = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161F30).withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white24, size: 24),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(desc, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white24, fontSize: 10, height: 1.4)),
        ],
      ),
    );
  }
}
