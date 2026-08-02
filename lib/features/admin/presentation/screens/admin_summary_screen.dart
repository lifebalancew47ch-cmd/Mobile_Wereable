import 'package:flutter/material.dart';

class AdminSummaryScreen extends StatelessWidget {
  const AdminSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9F1EC), // Fondo Menta Claro
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header Administrativo
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Resumen\nAdministrativo',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3E6F58),
                      height: 1.1,
                    ),
                  ),
                  Row(
                    children: [
                      Stack(
                        children: [
                          const Icon(Icons.notifications_none, color: Color(0xFF3E6F58), size: 28),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      const CircleAvatar(
                        radius: 18,
                        backgroundImage: NetworkImage('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=150'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 2. Barra de Búsqueda
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar usuario global...',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                    icon: Icon(Icons.search, color: Colors.grey),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 3. Lista de Tarjetas de Métricas
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                children: [
                  // Tarjeta: Usuarios Activos
                  _buildAdminMetricCard(
                    icon: Icons.person_outline,
                    iconBgColor: const Color(0xFFF0F7F4),
                    title: 'Usuarios Activos Totales',
                    value: '1,240',
                    trendLabel: '+12.5%',
                    trendColor: const Color(0xFF3E6F58),
                  ),
                  const SizedBox(height: 16),

                  // Tarjeta: Índice Sedentario
                  _buildAdminMetricCard(
                    icon: Icons.timer_outlined,
                    iconBgColor: const Color(0xFFFEF3EB),
                    title: 'Índice Sedentario Promedio',
                    value: '64',
                    trendLabel: '+4% Riesgo',
                    trendColor: const Color(0xFFD68C5E),
                  ),
                  const SizedBox(height: 16),

                  // Tarjeta: Riesgo Organizacional
                  _buildAdminMetricCard(
                    icon: Icons.warning_amber_rounded,
                    iconBgColor: const Color(0xFFFEF3EB),
                    title: 'Riesgo Organizacional',
                    value: 'Moderado',
                    valueColor: const Color(0xFFD68C5E),
                    statusLabel: 'Activo',
                    statusColor: Colors.grey,
                  ),
                  const SizedBox(height: 16),

                  // Tarjeta: Meta (Parte inferior visible en la imagen)
                  _buildAdminMetricCard(
                    icon: Icons.directions_run,
                    iconBgColor: const Color(0xFFF0F7F4),
                    title: 'Meta de Actividad',
                    value: '86%',
                    trendLabel: '92% Meta',
                    trendColor: const Color(0xFF3E6F58),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminMetricCard({
    required IconData icon,
    required Color iconBgColor,
    required String title,
    required String value,
    Color? valueColor,
    String? trendLabel,
    Color? trendColor,
    String? statusLabel,
    Color? statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: trendColor ?? const Color(0xFF3E6F58), size: 24),
              ),
              if (trendLabel != null)
                Text(
                  trendLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: trendColor ?? const Color(0xFF3E6F58),
                  ),
                ),
              if (statusLabel != null)
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor ?? Colors.grey,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: valueColor ?? const Color(0xFF3E6F58),
            ),
          ),
        ],
      ),
    );
  }
}
