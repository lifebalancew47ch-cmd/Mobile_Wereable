import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../fog/presentation/providers/fog_providers.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../wearable/presentation/wearable_provider.dart';
import '../providers/alert_settings_provider.dart';
import '../../domain/alert_settings.dart';

class AlertSettingsScreen extends ConsumerStatefulWidget {
  const AlertSettingsScreen({super.key});

  @override
  ConsumerState<AlertSettingsScreen> createState() => _AlertSettingsScreenState();
}

class _AlertSettingsScreenState extends ConsumerState<AlertSettingsScreen> {
  int _intervalMinutes = 45;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 18, minute: 0);
  Set<int> _activeDays = const {1, 2, 3, 4, 5};
  bool _criticalNotifications = false;
  bool _alertSound = true;

  late final TextEditingController _customMinutesController;

  static const List<String> _dayLetters = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  void initState() {
    super.initState();
    _customMinutesController = TextEditingController(text: _intervalMinutes.toString());
    _hydrateFromProvider();
  }

  @override
  void dispose() {
    _customMinutesController.dispose();
    super.dispose();
  }

  void _hydrateFromProvider() {
    final settings = ref.read(alertSettingsProvider).value;
    if (settings != null) {
      _apply(settings);
    }
  }

  void _apply(AlertSettings s) {
    setState(() {
      _intervalMinutes = s.intervalMinutes;
      _customMinutesController.text = s.intervalMinutes.toString();
      _start = TimeOfDay(hour: s.startHour, minute: s.startMinute);
      _end = TimeOfDay(hour: s.endHour, minute: s.endMinute);
      _activeDays = Set<int>.from(s.activeDays);
      _criticalNotifications = s.criticalNotifications;
      _alertSound = s.alertSound;
    });
  }

  Future<void> _pickTime(TimeOfDay current, ValueChanged<TimeOfDay> onPicked) async {
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked != null) {
      onPicked(picked);
    }
  }

  Future<void> _confirm() async {
    final customMins = int.tryParse(_customMinutesController.text.trim());
    if (customMins == null || customMins < 1 || customMins > 120) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, ingresa una duración entre 1 y 120 minutos (máximo 2 horas).'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    _intervalMinutes = customMins;

    final settings = AlertSettings(
      intervalMinutes: _intervalMinutes,
      startHour: _start.hour,
      startMinute: _start.minute,
      endHour: _end.hour,
      endMinute: _end.minute,
      activeDays: _activeDays,
      criticalNotifications: _criticalNotifications,
      alertSound: _alertSound,
    );

    await ref.read(alertSettingsProvider.notifier).save(settings);
    ref.read(fogEngineProvider).setAlertThreshold(settings.intervalMinutes);

    // NUEVO: Sincronizar al reloj vía DataClient
    final wearableService = ref.read(wearableCommunicationServiceProvider);
    wearableService.syncAlertInterval(settings.intervalMinutes);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuración guardada correctamente'),
          backgroundColor: Color(0xFF3E6F58),
        ),
      );
    }
  }

  String _fmt(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final period = t.period == DayPeriod.am ? 'a. m.' : 'p. m.';
    final min = t.minute.toString().padLeft(2, '0');
    return '$h:$min $period';
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    ref.listen(alertSettingsProvider, (previous, next) {
      final value = next.value;
      if (value != null) _apply(value);
    });

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1220) : Colors.white,
      appBar: AppBar(
        title: const Text('Configuración de Alertas'),
        actions: [
          IconButton(
            onPressed: () {
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
            Text(
              'Estas opciones controlan cuándo el FogEngine detecta inactividad y te notifica una alerta.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionTitle(Icons.timer_outlined, 'DURACIÓN DE INACTIVIDAD (1 - 120 MINUTOS)'),
            Row(
              children: [
                _buildChoiceChip('15m', 15),
                const SizedBox(width: 6),
                _buildChoiceChip('30m', 30),
                const SizedBox(width: 6),
                _buildChoiceChip('45m', 45),
                const SizedBox(width: 6),
                _buildChoiceChip('60m', 60),
                const SizedBox(width: 6),
                _buildChoiceChip('90m', 90),
                const SizedBox(width: 6),
                _buildChoiceChip('120m', 120),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customMinutesController,
              keyboardType: TextInputType.number,
              onChanged: (text) {
                final v = int.tryParse(text.trim());
                if (v != null && v >= 1 && v <= 120) {
                  setState(() => _intervalMinutes = v);
                }
              },
              decoration: InputDecoration(
                labelText: 'Minutos personalizados (1 a 120 min)',
                hintText: 'Ej: 15, 25, 40, 75, 100...',
                suffixText: 'min',
                prefixIcon: const Icon(Icons.edit_calendar, color: Color(0xFF3E6F58)),
                filled: true,
                fillColor: isDark ? const Color(0xFF162032) : const Color(0xFFF4F8F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF3E6F58), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionTitle(Icons.access_time, 'HORARIO DE OPERACIÓN'),
            Row(
              children: [
                Expanded(
                  child: _buildTimeInput(
                    'INICIO',
                    _fmt(_start),
                    () => _pickTime(_start, (t) => setState(() => _start = t)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTimeInput(
                    'FIN',
                    _fmt(_end),
                    () => _pickTime(_end, (t) => setState(() => _end = t)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            _buildSectionTitle(Icons.calendar_today, 'DÍAS DE LA SEMANA'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final isoDay = i + 1;
                final selected = _activeDays.contains(isoDay);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      final next = Set<int>.from(_activeDays);
                      if (selected) {
                        next.remove(isoDay);
                      } else {
                        next.add(isoDay);
                      }
                      _activeDays = next;
                    });
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF3E6F58).withValues(alpha: 0.25)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF3E6F58)
                            : Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _dayLetters[i],
                        style: TextStyle(
                          color: selected ? null : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

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

            ElevatedButton(
              onPressed: _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3E6F58),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Guardar Configuración', style: TextStyle(fontWeight: FontWeight.bold)),
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
          Icon(icon, size: 18, color: const Color(0xFF3E6F58)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.grey,
                letterSpacing: 1.0,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3E6F58)),
            ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip(String label, int minutes) {
    final isSelected = _intervalMinutes == minutes;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _intervalMinutes = minutes;
            _customMinutesController.text = minutes.toString();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF3E6F58) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF3E6F58) : Colors.grey.withValues(alpha: 0.3),
            ),
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

  Widget _buildTimeInput(String label, String time, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEDF2EE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(time, style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.bold)),
                const Icon(Icons.access_time, size: 16, color: Colors.black54),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3E6F58).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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