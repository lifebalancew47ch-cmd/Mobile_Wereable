import 'package:flutter/material.dart';

class PerformanceAnalysisScreen extends StatelessWidget {
  const PerformanceAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFE9F1EC), // Fondo Menta Claro
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header
              _buildHeader(),
              const SizedBox(height: 24),

              // Título de la Sección
              const Text(
                'ANÁLISIS DEL SISTEMA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3E6F58),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Análisis de\nRendimiento',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3E6F58),
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 24),

              // 2. Card: Riesgo de Salud Medio-Alto
              _buildRiskCard(),
              const SizedBox(height: 20),

              // 3. Card: División Diaria (Circular Progress)
              _buildDailyDivisionCard(),
              const SizedBox(height: 20),

              // 4. Card: Racha más Larga
              _buildStreakCard(),
              const SizedBox(height: 20),

              // 5. Card: Horas Sedentarias (7 días) - Placeholder/Minichart
              _buildWeeklySedentaryCard(),
              const SizedBox(height: 32),

              // 6. Sección: Sesiones de Enfoque
              _buildFocusSessionsHeader(),
              const SizedBox(height: 16),
              _buildFocusSessionItem(
                icon: Icons.computer_rounded,
                title: 'Bloque de Trabajo Profundo',
                time: '09:00 AM - 11:30 AM',
                duration: '2.5 Horas',
                intensity: 'Intensidad Alta',
              ),
              const SizedBox(height: 12),
              _buildFocusSessionItem(
                icon: Icons.group_outlined,
                title: 'Sincronización Estratégica',
                time: '02:00 PM - 03:00 PM',
                duration: '1.0 Hora',
                intensity: 'Bajo Esfuerzo',
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=150'),
            ),
            const SizedBox(width: 12),
            const Text(
              'LifeBalance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3E6F58),
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_none, color: Color(0xFF3E6F58)),
        ),
      ],
    );
  }

  Widget _buildRiskCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'EVALUACIÓN ACTUAL',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                Row(
                  children: [
                    const Icon(Icons.trending_up, size: 14, color: Color(0xFFD68C5E)),
                    const SizedBox(width: 4),
                    const Text(
                      'Aumento del 12%',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD68C5E)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Riesgo de\nSalud\nMedio-Alto',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3E6F58),
                height: 1.1,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Umbral de Actividad', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                const Text('68%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3E6F58))),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(
                value: 0.68,
                backgroundColor: Color(0xFFE0EAE4),
                color: Color(0xFF3E6F58),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Los patrones sedentarios han aumentado durante las horas de enfoque. Tu tasa metabólica ha caído por debajo de los niveles óptimos. Recomendamos un descanso activo de 5 minutos cada 50 minutos.',
              style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyDivisionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DIVISIÓN DIARIA',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: 0.65,
                      strokeWidth: 12,
                      backgroundColor: const Color(0xFFF2F6F4),
                      color: const Color(0xFF3E6F58),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '65%',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF3E6F58)),
                      ),
                      const Text(
                        'Sedentario',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSimpleLegend(color: const Color(0xFF3E6F58), label: '25% Activo'),
                _buildSimpleLegend(color: const Color(0xFFD1DCD6), label: 'Meta: 45%'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleLegend({required Color color, required String label}) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStreakCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: const Color(0xFFF0F7F4), borderRadius: BorderRadius.circular(4)),
                  child: const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF3E6F58)),
                ),
                const SizedBox(width: 8),
                const Text(
                  'RACHA MÁS LARGA',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '3h 10m',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF3E6F58)),
            ),
            const Text(
              'Sedentarismo ininterrumpido\nregistrado a las 01:45 PM.',
              style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklySedentaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'HORAS SEDENTARIAS\n(ÚLTIMOS 7 DÍAS)',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const Text(
                  'Informe\nCompleto',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 48), // Espacio para mini gráfica futura
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['L', 'M', 'M', 'J', 'V', 'S', 'D']
                  .map((d) => Text(d, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFocusSessionsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Sesiones de\nEnfoque',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF3E6F58), height: 1.1),
        ),
        const Text(
          'Últimas 24\nHoras',
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildFocusSessionItem({
    required IconData icon,
    required String title,
    required String time,
    required String duration,
    required String intensity,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7F4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE0EAE4)),
            ),
            child: Icon(icon, color: const Color(0xFF3E6F58), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(time, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(duration, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFD68C5E))),
              Text(intensity, style: const TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}
