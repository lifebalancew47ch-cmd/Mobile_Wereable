import 'package:flutter/material.dart';

class ExecutiveDashboardScreen extends StatelessWidget {
  const ExecutiveDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFE9F1EC), // Fondo Menta Claro
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // 1. Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF3E6F58),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.bar_chart, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 8),
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
                  const Icon(Icons.notifications_none, color: Color(0xFF3E6F58)),
                ],
              ),
              const SizedBox(height: 40),

              // 2. Main Sedentary Score Circle
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: CircularProgressIndicator(
                        value: 0.45,
                        strokeWidth: 12,
                        backgroundColor: Colors.white.withOpacity(0.5),
                        color: const Color(0xFF3E6F58),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'PUNTUACIÓN SEDENTARIA',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: Color(0xFF3E6F58),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '45',
                          style: TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3E6F58),
                            height: 1,
                          ),
                        ),
                        const Text(
                          'MODERADA',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3E6F58),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 3. Trend Badge
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.trending_up, size: 14, color: Color(0xFF3E6F58)),
                      SizedBox(width: 6),
                      Text(
                        '+5% mejor que ayer',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF3E6F58),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // 4. Activity Grid (2x2)
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.schedule,
                      label: 'DIARIO',
                      value: '5h 24m',
                      description: 'Inactividad Total',
                      color: const Color(0xFF3E6F58),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.chair_alt,
                      label: 'RIESGO ALTO',
                      value: '1h 15m',
                      description: 'Sentado Actual',
                      color: const Color(0xFFD68C5E), // Tono naranja/alerta
                      hasSideBorder: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.bolt,
                      label: '',
                      value: '42m',
                      description: 'Minutos Activos',
                      color: const Color(0xFF3E6F58),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildProgressBarCard(
                      icon: Icons.directions_walk,
                      current: 3,
                      total: 5,
                      description: 'Pausas Activas',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 5. Executive Analysis Card
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Graph Placeholder
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 120,
                          color: const Color(0xFF1E1E1E), // Fondo oscuro para la gráfica
                          child: const Center(
                            child: Icon(Icons.analytics_outlined, color: Colors.white54, size: 48),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Icon(Icons.psychology_outlined, color: Color(0xFF3E6F58), size: 32),
                          const SizedBox(width: 12),
                          const Text(
                            'Análisis\nEjecutivo',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3E6F58),
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.5),
                          children: [
                            TextSpan(text: 'Tus niveles de concentración suelen disminuir después de '),
                            TextSpan(text: '90 minutos ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD68C5E))),
                            TextSpan(text: 'sentado de forma continua. Tomar un descanso de movimiento de 2 minutos ahora probablemente aumentará tu rendimiento cognitivo en un '),
                            TextSpan(text: '12% ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3E6F58))),
                            TextSpan(text: 'durante la próxima hora.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () {},
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF3E6F58),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Programar Pausa Activa', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required String description,
    required Color color,
    bool hasSideBorder = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: hasSideBorder ? Border(left: BorderSide(color: color, width: 4)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              if (label.isNotEmpty)
                Text(
                  label,
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBarCard({
    required IconData icon,
    required int current,
    required int total,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF3E6F58), size: 20),
          const SizedBox(height: 12),
          Text(
            '$current/$total',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: current / total,
              minHeight: 4,
              backgroundColor: const Color(0xFFE9F1EC),
              color: const Color(0xFF3E6F58),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
