import 'package:flutter/material.dart';

class HeatmapScreen extends StatelessWidget {
  const HeatmapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFE9F1EC), // Fondo Menta Claro
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header (Sección Superior)
              _buildHeader(),
              const SizedBox(height: 24),

              // 2. Selector de Fecha y Filtros
              _buildDateSelector(),
              const SizedBox(height: 12),
              _buildToggleSwitch(),
              const SizedBox(height: 24),

              // 3. Card: Mapa de Calor Conductual
              _buildHeatmapCard(theme),
              const SizedBox(height: 20),

              // 4. Cards de Métricas (Movimiento y Sedentario)
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'MOVIMIENTO',
                      value: '1h 15m',
                      subtitle: '+12% desde ayer',
                      icon: Icons.directions_run,
                      borderColor: const Color(0xFF3E6F58),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'SEDENTARIO',
                      value: '6h 42m',
                      subtitle: '-5% desde ayer',
                      icon: Icons.airline_seat_recline_normal,
                      borderColor: const Color(0xFFD68C5E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 5. Card: Compromiso Metabólico (Gráfica de Barras)
              _buildMetabolicEngagementCard(theme),
              const SizedBox(height: 20),

              // 6. Sección: Perspectiva de Patrones (Insights)
              _buildInsightsSection(theme),
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

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          const Text('24 oct, 2023', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 8),
          const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildToggleSwitch() {
    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF3E6F58),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Día', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Semana', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Mapa de Calor\nConductual', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3E6F58), height: 1.1)),
                Icon(Icons.info_outline, color: Colors.blue.withOpacity(0.5), size: 20),
              ],
            ),
            const SizedBox(height: 24),
            // Time Labels
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _TimeLabel(label: '12 AM'),
                _TimeLabel(label: '6 AM'),
                _TimeLabel(label: '12 PM'),
                _TimeLabel(label: '6 PM'),
                _TimeLabel(label: '11 PM'),
              ],
            ),
            const SizedBox(height: 8),
            // Heatmap Grid
            _buildHeatmapGrid(),
            const SizedBox(height: 24),
            // Legend
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _LegendItem(color: Color(0xFF3E6F58), label: 'Caminando'),
                _LegendItem(color: Color(0xFFD68C5E), label: 'De Pie'),
                _LegendItem(color: Color(0xFFE0EAE4), label: 'Sentado'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmapGrid() {
    // Generando cajas de colores simuladas
    final List<Color> colors = [
      ...List.generate(6, (_) => const Color(0xFFF2F6F4)), // Noche
      const Color(0xFFD1DCD6), const Color(0xFFD1DCD6), // Madrugada
      const Color(0xFF3E6F58), const Color(0xFF5A8B73), const Color(0xFF3E6F58), // Actividad mañana
      const Color(0xFFD68C5E), const Color(0xFFE4A47E), const Color(0xFFD68C5E), // Tarde activa
      const Color(0xFFD1DCD6), const Color(0xFFD1DCD6),
      const Color(0xFF3E6F58), const Color(0xFF3E6F58),
      ...List.generate(4, (_) => const Color(0xFFF2F6F4)), // Noche final
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: colors.map((color) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      )).toList(),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: borderColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: borderColor, letterSpacing: 1.1)),
              Icon(icon, size: 16, color: borderColor.withOpacity(0.5)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildMetabolicEngagementCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('COMPROMISO\nMETABÓLICO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3E6F58))),
                    ],
                  ),
                ),
                RichText(
                  textAlign: TextAlign.right,
                  text: const TextSpan(
                    children: [
                      TextSpan(text: '78% ', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF3E6F58))),
                      TextSpan(text: 'Pico\nSedentario', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD68C5E))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Simulación de Gráfica de Barras
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildBar(height: 40, label: 'L'),
                _buildBar(height: 60, label: 'M'),
                _buildBar(height: 80, label: 'M', isPeak: true),
                _buildBar(height: 50, label: 'J'),
                _buildBar(height: 70, label: 'V'),
                _buildBar(height: 90, label: 'S'),
                _buildBar(height: 65, label: 'D'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBar({required double height, required String label, bool isPeak = false}) {
    return Column(
      children: [
        Container(
          width: 30,
          height: height,
          decoration: BoxDecoration(
            color: isPeak ? const Color(0xFFD68C5E) : const Color(0xFF5A8B73),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              Container(height: 10, decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)))),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildInsightsSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7F4), // Fondo menta suave de la imagen
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Color(0xFFD1DCD6), shape: BoxShape.circle),
            child: const Icon(Icons.lightbulb_outline, color: Color(0xFF3E6F58), size: 24),
          ),
          const SizedBox(height: 16),
          const Text(
            'Perspectiva de Patrones',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3E6F58)),
          ),
          const SizedBox(height: 12),
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(color: Colors.black54, height: 1.5, fontSize: 13),
              children: [
                TextSpan(text: 'Tu compromiso metabólico cae significativamente entre las '),
                TextSpan(text: '2 PM y las 4 PM', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD68C5E))),
                TextSpan(text: '. Recomendamos un estiramiento dinámico de 5 minutos a las 1:55 PM para prevenir el pico sedentario observado en tu mapa de calor.'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3E6F58),
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Configurar Recordatorio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _TimeLabel extends StatelessWidget {
  final String label;
  const _TimeLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold));
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
