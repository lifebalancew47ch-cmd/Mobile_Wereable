import 'package:flutter/material.dart';

class ExecutiveNotificationsScreen extends StatelessWidget {
  const ExecutiveNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220), // Midnight Deep Navy
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=150'),
            ),
            const SizedBox(width: 12),
            const Text('Notificaciones'),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.done_all, size: 16, color: Colors.white70),
            label: const Text('Marcar todo como leído', style: TextStyle(color: Colors.white70, fontSize: 10)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('HOY', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          _buildNotificationCard(
            icon: Icons.warning_amber_rounded,
            iconColor: const Color(0xFFD68C5E),
            title: 'Alerta de Sedentarismo',
            time: 'Hace 15m',
            body: 'Has estado inactivo por más de 90 minutos. El flujo sanguíneo cerebral está disminuyendo. Es crítico levantarse ahora.',
            hasActions: true,
            isNew: true,
          ),
          const SizedBox(height: 16),
          _buildNotificationCard(
            icon: Icons.emoji_events_outlined,
            iconColor: const Color(0xFF00C2FF),
            title: 'Logro: Maestro de la Calma',
            time: 'Hace 2h',
            body: 'Has completado 7 días consecutivos de pausas de meditación programadas. Tu nivel de cortisol proyectado ha bajado un 12%.',
            isNew: true,
            showStar: true,
          ),
          const SizedBox(height: 16),
          _buildNotificationCard(
            icon: Icons.timer_outlined,
            iconColor: Colors.white70,
            title: 'Pausa Visual',
            time: 'Hace 4h',
            body: 'Recordatorio de la regla 20-20-20 para reducir la fatiga ocular digital. Mira a 6 metros por 20 segundos.',
          ),
          const SizedBox(height: 32),
          const Text('AYER', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          _buildNotificationCard(
            icon: Icons.analytics_outlined,
            iconColor: Colors.white70,
            title: 'Resumen Semanal Disponible',
            time: 'Ayer, 18:30',
            body: 'Tu análisis de equilibrio vida-trabajo está listo. Has mejorado tu consistencia de sueño en un 8.5% esta semana.',
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String time,
    required String body,
    bool hasActions = false,
    bool isNew = false,
    bool showStar = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161F30),
        borderRadius: BorderRadius.circular(20),
        border: isNew ? Border(left: BorderSide(color: iconColor, width: 3)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(time, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  ],
                ),
              ),
              if (isNew) Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF00C2FF), shape: BoxShape.circle)),
            ],
          ),
          const SizedBox(height: 12),
          Text(body, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
          if (hasActions) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A80FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Tomar Acción', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Ignorar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
          if (showStar) ...[
             const Align(
               alignment: Alignment.bottomRight,
               child: Icon(Icons.stars, color: Colors.white10, size: 40),
             )
          ]
        ],
      ),
    );
  }
}
