import 'package:flutter/material.dart';

class ExecutiveDashboardScreen extends StatelessWidget {
  const ExecutiveDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F8F4), // Fondo Menta Ultra-Suave
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.only(left: 16.0),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFF3E6F58),
            child: Icon(Icons.person, color: Colors.white, size: 18),
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
          children: [
            const SizedBox(height: 32),
            // 1. Sedentary Score Gauge
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: CircularProgressIndicator(
                      value: 0.65, // Ajustado visualmente al arco de la imagen
                      strokeWidth: 14,
                      backgroundColor: Colors.white,
                      color: const Color(0xFF3E6F58),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'PUNTUACIÓN SEDENTARIA',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Color(0xFF3E6F58),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '45',
                        style: TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A34),
                          height: 1,
                        ),
                      ),
                      Text(
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

            // 2. Trend Pill Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))
                ],
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
            const SizedBox(height: 40),

            // 3. Metrics Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          icon: Icons.access_time,
                          label: 'DIARIO',
                          value: '5h 24m',
                          subtitle: 'Inactividad Total',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildMetricCard(
                          icon: Icons.chair_alt_outlined,
                          label: 'RIESGO ALTO',
                          value: '1h 15m',
                          subtitle: 'Sentado Actual',
                          labelColor: Colors.orange.shade700,
                          hasSideBorder: true,
                          borderColor: Colors.orange.shade700,
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
                          subtitle: 'Minutos Activos',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildMetricCard(
                          icon: Icons.directions_run,
                          label: 'META',
                          value: '3/5',
                          subtitle: 'Pausas Activas',
                          showProgress: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. Executive Analysis Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      'https://images.unsplash.com/photo-1551288049-bebda4e38f71?q=80&w=400',
                      height: 140,
                      fit: BoxCover.cover,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: const [
                      Icon(Icons.psychology_outlined, color: Color(0xFF3E6F58), size: 28),
                      SizedBox(width: 10),
                      Text(
                        'Análisis Ejecutivo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E6F58),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.black54, fontSize: 12, height: 1.5),
                      children: [
                        const TextSpan(text: 'Tus niveles de concentración suelen disminuir después de '),
                        TextSpan(text: '90 minutos ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800)),
                        const TextSpan(text: 'sentado de forma continua. Tomar un descanso de movimiento de 2 minutos ahora probablemente aumentará tu rendimiento cognitivo en un '),
                        TextSpan(text: '12% ', style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFF3E6F58))),
                        const TextSpan(text: 'durante la próxima hora.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF3E6F58),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Programar Pausa Activa', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    Color? labelColor,
    bool hasSideBorder = false,
    Color? borderColor,
    bool showProgress = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: hasSideBorder ? Border(left: BorderSide(color: borderColor!, width: 4)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: const Color(0xFF3E6F58), size: 20),
              if (label.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (labelColor ?? const Color(0xFF3E6F58)).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: labelColor ?? const Color(0xFF3E6F58)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E3A34)),
          ),
          if (showProgress) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(
                value: 0.6,
                backgroundColor: Color(0xFFF2F8F4),
                color: Color(0xFF3E6F58),
                minHeight: 4,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
