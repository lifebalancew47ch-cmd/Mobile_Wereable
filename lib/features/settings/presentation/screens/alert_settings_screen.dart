import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_provider.dart';

class AlertSettingsScreen extends ConsumerStatefulWidget {
  const AlertSettingsScreen({super.key});

  @override
  ConsumerState<AlertSettingsScreen> createState() => _AlertSettingsScreenState();
}

class _AlertSettingsScreenState extends ConsumerState<AlertSettingsScreen> {
  String _selectedInterval = 'Cada 60 min';
  bool _criticalNotifications = false;
  bool _alertSound = true;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recordatorios'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none, size: 24),
          ),
          IconButton(
            onPressed: () {
              // Botón para cambiar el tema
              ref.read(themeModeProvider.notifier).state =
                isDark ? ThemeMode.light : ThemeMode.dark;
            },
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card con Imagen/Reloj
            Card(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                    image: const NetworkImage('https://images.unsplash.com/photo-1523275335684-37898b6baf30?q=80&w=400'),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.6),
                      BlendMode.darken,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Configuración de\nAlerta',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Optimiza tu productividad con pausas\nactivas.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 1. Intervalo de Movimiento
            _buildSectionTitle(Icons.timer_outlined, 'INTERVALO DE MOVIMIENTO'),
            Row(
              children: [
                _buildChoiceChip('Cada 30 min'),
                const SizedBox(width: 10),
                _buildChoiceChip('Cada 60 min'),
                const SizedBox(width: 10),
                _buildChoiceChip('Cada 90 min'),
              ],
            ),
            const SizedBox(height: 32),

            // 2. Horario de Operación
            _buildSectionTitle(Icons.access_time, 'HORARIO DE OPERACIÓN'),
            Row(
              children: [
                Expanded(child: _buildTimeInput('INICIO', '09:00 a. m.')),
                const SizedBox(width: 16),
                Expanded(child: _buildTimeInput('FIN', '06:00 p. m.')),
              ],
            ),
            const SizedBox(height: 32),

            // 3. Días de la Semana
            _buildSectionTitle(Icons.calendar_today, 'DÍAS DE LA SEMANA', trailing: 'Lun - Vie'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['L', 'M', 'X', 'J', 'V', 'S', 'D'].map((day) => _buildDayCircle(day)).toList(),
            ),
            const SizedBox(height: 32),

            // 4. Switches
            _buildSwitchTile(
              'Notificaciones Críticas',
              'Ignorar modo "No Molestar"',
              _criticalNotifications,
              (v) => setState(() => _criticalNotifications = v),
            ),
            const SizedBox(height: 16),
            _buildSwitchTile(
              'Sonido de Alerta',
              'Efecto "Zen Focus"',
              _alertSound,
              (v) => setState(() => _alertSound = v),
            ),
            const SizedBox(height: 32),

            // Botón Confirmar
            Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A80FF), Color(0xFF00C2FF)],
                ),
              ),
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Confirmar Configuración',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Los cambios se aplicarán en todos tus\ndispositivos sincronizados.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF4A80FF)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.0),
            ),
          ),
          if (trailing != null)
            Text(trailing, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4A80FF))),
        ],
      ),
    );
  }

  Widget _buildChoiceChip(String label) {
    final isSelected = _selectedInterval == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedInterval = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF161F30) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? const Color(0xFF00C2FF) : Colors.grey.withOpacity(0.2)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeInput(String label, String time) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF161F30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(time, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              const Icon(Icons.access_time, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDayCircle(String day) {
    final isSelected = day != 'S' && day != 'D';
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF4A80FF).withOpacity(0.2) : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: isSelected ? const Color(0xFF4A80FF) : Colors.grey.withOpacity(0.2)),
      ),
      child: Center(
        child: Text(
          day,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161F30),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
