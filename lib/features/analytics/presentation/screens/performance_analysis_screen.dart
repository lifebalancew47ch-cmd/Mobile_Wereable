import 'package:flutter/material.dart';

class PerformanceAnalysisScreen extends StatelessWidget {
  const PerformanceAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F8F4), // Fondo Menta muy suave
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.only(left: 16.0),
          child: CircleAvatar(
            radius: 18,
            backgroundImage: NetworkImage('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=150'),
          ),
        ),
        title: const Text(
          'LifeBalance',
          style: TextStyle(
            color: Color(0xFF3E6F58),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none, color: Colors.black87),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            // Título de la Sección
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'ANÁLISIS DEL SISTEMA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Análisis de Rendimiento',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3E6F58),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 1. Card: Riesgo de Salud
            _buildRiskCard(),
            const SizedBox(height: 16),

            // 2. Card: División Diaria
            _buildDailyDivisionCard(),
            const SizedBox(height: 16),

            // 3. Card: Racha más Larga
            _buildStreakCard(),
            const SizedBox(height: 16),

            // 4. Card: Horas Sedentarias
            _buildWeeklyCard(),
            const SizedBox(height: 32),

            // 5. Sección: Sesiones de Enfoque
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Sesiones de Enfoque',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3E6F58),
                    ),
                  ),
                  Text(
                    'Últimas 24 Horas',
                    style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildFocusSessionItem(
              icon: Icons.computer_rounded,
              title: 'Bloque de Trabajo Profundo',
              time: '09:00 AM - 11:30 AM',
              duration: '2.5 Horas',
              intensity: 'Intensidad Alta',
              intensityColor: Colors.orange.shade700,
            ),
            const SizedBox(height: 12),
            _buildFocusSessionItem(
              icon: Icons.group_outlined,
              title: 'Sincronización Estratégica',
              time: '02:00 PM - 03:00 PM',
              duration: '1.0 Hora',
              intensity: 'Bajo Esfuerzo',
              intensityColor: const Color(0xFF3E6F58),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
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
                children: const [
                  Icon(Icons.trending_up, size: 14, color: Color(0xFFD68C5E)),
                  SizedBox(width: 4),
                  Text(
                    'Aumento del 12%',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD68C5E)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Riesgo de Salud\nMedio-Alto',
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
            children: const [
              Text('Umbral de Actividad', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text('68%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3E6F58))),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              value: 0.68,
              backgroundColor: Color(0xFFF2F8F4),
              color: Color(0xFF3E6F58),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Los patrones sedentarios han aumentado durante las horas de enfoque. Tu tasa metabólica ha caído por debajo de los niveles óptimos. Recomendamos un descanso activo de 5 minutos cada 50 minutos.',
            style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyDivisionCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
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
                  width: 130,
                  height: 130,
                  child: CircularProgressIndicator(
                    value: 0.65,
                    strokeWidth: 12,
                    backgroundColor: const Color(0xFFF2F8F4),
                    color: const Color(0xFF3E6F58),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      '65%',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF3E6F58)),
                    ),
                    Text(
                      'Sedentario',
                      style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegend(color: const Color(0xFF3E6F58), label: '35% Activo'),
              _buildLegend(color: const Color(0xFFD1DCD6), label: 'Meta: 45%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend({required Color color, required String label}) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStreakCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: const Color(0xFFFEF3EB), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.timer_off_outlined, size: 18, color: Color(0xFFD68C5E)),
              ),
              const SizedBox(width: 12),
              const Text(
                'RACHA MÁS LARGA',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '3h 10m',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF3E6F58)),
          ),
          const Text(
            'Sedentarismo ininterrumpido registrado a las 01:45 PM.',
            style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'HORAS SEDENTARIAS (ÚLTIMOS 7 DÍAS)',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              Text(
                'Informe Completo',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF3E6F58)),
              ),
            ],
          ),
          const SizedBox(height: 60), // Placeholder para gráfica
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['L', 'M', 'M', 'J', 'V', 'S', 'D']
                .map((d) => Text(d, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusSessionItem({
    required IconData icon,
    required String title,
    required String time,
    required String duration,
    required String intensity,
    required Color intensityColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF2F8F4), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: const Color(0xFF3E6F58), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(time, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(duration, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
              Text(
                intensity,
                style: TextStyle(color: intensityColor, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
