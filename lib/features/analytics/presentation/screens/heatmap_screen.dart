import 'package:flutter/material.dart';
import '../../../../data/datasources/secure_database_service.dart';
import '../../../../services/notification_service.dart';

class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  final SecureDatabaseService _db = SecureDatabaseService.instance;
  final NotificationService _notifications = NotificationService();

  List<Map<String, Object?>> _todaySessions = [];
  List<Map<String, Object?>> _weekSessions = [];
  bool _loading = true;
  DateTime _selectedDate = DateTime.now();
  bool _isDayView = true;

  // Estado para el diálogo de recordatorio
  TimeOfDay? _reminderTime;
  bool _reminderScheduled = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final today = await _db.getActivitySessionsForDay(_selectedDate);
    final week = await _db.getActivitySessionsLastDays(7);
    if (!mounted) return;
    setState(() {
      _todaySessions = today;
      _weekSessions = week;
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  Future<void> _scheduleReminder() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? const TimeOfDay(hour: 13, minute: 55),
      helpText: 'Hora del recordatorio de pausa activa',
    );
    if (picked == null) return;

    try {
      await _notifications.requestPermissions();
      await _notifications.scheduleReminder(
        hour: picked.hour,
        minute: picked.minute,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo programar el recordatorio. Verifica los permisos de notificaciones.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _reminderTime = picked;
      _reminderScheduled = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Recordatorio programado para las ${picked.format(context)}',
        ),
      ),
    );
  }

  // ---- Cálculos reales sobre las sesiones de la BD ----

  /// Minutos activos (sesiones tipo 'active') del día seleccionado.
  int _activeMinutesToday() {
    return _todaySessions
        .where((s) => s['type'] == 'active')
        .fold<int>(0, (sum, s) => sum + ((s['duration_minutes'] as int?) ?? 0));
  }

  /// Minutos sedentarios (sesiones tipo 'idle'/'alert') del día seleccionado.
  int _sedentaryMinutesToday() {
    return _todaySessions
        .where((s) => s['type'] == 'idle' || s['type'] == 'alert')
        .fold<int>(0, (sum, s) => sum + ((s['duration_minutes'] as int?) ?? 0));
  }

  /// Intensidad (0-4) por hora del día, basada en las sesiones registradas.
  List<int> _hourlyActivity() {
    final hours = List<int>.filled(24, 0);
    for (final session in _todaySessions) {
      final start = DateTime.tryParse((session['start_time'] as String?) ?? '');
      final duration = (session['duration_minutes'] as int?) ?? 0;
      if (start == null || duration <= 0) continue;
      final type = (session['type'] as String?) ?? 'idle';
      final weight = type == 'active' ? 4 : (type == 'alert' ? 3 : 1);
      final hour = start.hour;
      hours[hour] = (hours[hour] + weight).clamp(0, 4);
    }
    return hours;
  }

  /// Minutos activos por día (últimos 7 días) para el gráfico semanal.
  List<int> _weekActiveMinutes() {
    final now = DateTime.now();
    final byDay = List<int>.filled(7, 0);
    for (final session in _weekSessions) {
      final start = DateTime.tryParse((session['start_time'] as String?) ?? '');
      final duration = (session['duration_minutes'] as int?) ?? 0;
      if (start == null || (session['type'] as String?) != 'active') continue;
      final dayIndex = now.difference(DateTime(start.year, start.month, start.day)).inDays;
      if (dayIndex >= 0 && dayIndex < 7) {
        byDay[6 - dayIndex] += duration;
      }
    }
    return byDay;
  }

  /// Horas con mayor sedentarismo (para el insight).
  String _peakSedentaryWindow() {
    if (_todaySessions.isEmpty) return '8 AM - 12 PM';
    final hours = _hourlyActivity();
    var peakHour = 0;
    var minIntensity = hours[0];
    for (var h = 1; h < 24; h++) {
      if (hours[h] < minIntensity) {
        minIntensity = hours[h];
        peakHour = h;
      }
    }
    final start = _formatHour(peakHour);
    final end = _formatHour((peakHour + 2) % 24);
    return '$start - $end';
  }

  String _formatHour(int hour) {
    final h = hour % 24;
    if (h == 0) return '12 AM';
    if (h == 12) return '12 PM';
    return h < 12 ? '$h AM' : '${h - 12} PM';
  }

  Color _intensityColor(int intensity) {
    switch (intensity) {
      case 0:
        return const Color(0xFFF2F6F4); // Noche / sin datos
      case 1:
        return const Color(0xFFD1DCD6); // Sedentario
      case 2:
        return const Color(0xFFD68C5E); // De pie / baja actividad
      case 3:
        return const Color(0xFF5A8B73); // Actividad moderada
      default:
        return const Color(0xFF3E6F58); // Actividad alta
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFE9F1EC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildDateSelector(),
              const SizedBox(height: 12),
              _buildToggleSwitch(),
              const SizedBox(height: 24),
              _buildHeatmapCard(theme),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'MOVIMIENTO',
                      value: _formatDuration(_activeMinutesToday()),
                      subtitle: '${_todaySessions.length} sesiones registradas',
                      icon: Icons.directions_run,
                      borderColor: const Color(0xFF3E6F58),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'SEDENTARIO',
                      value: _formatDuration(_sedentaryMinutesToday()),
                      subtitle: _todaySessions.isEmpty ? 'Sin registros' : 'Incluye alertas',
                      icon: Icons.airline_seat_recline_normal,
                      borderColor: const Color(0xFFD68C5E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildMetabolicEngagementCard(theme),
              const SizedBox(height: 20),
              _buildInsightsSection(theme),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes <= 0) return '0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  Widget _buildHeader() {
    final canPop = Navigator.canPop(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (canPop) ...[
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF3E6F58)),
                onPressed: () => Navigator.maybePop(context),
                tooltip: 'Regresar',
              ),
              const SizedBox(width: 4),
            ],
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFF3E6F58),
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            const Text(
              'Mapa de calor',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3E6F58),
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: () => _pickDate(),
          icon: const Icon(Icons.calendar_month, color: Color(0xFF3E6F58)),
          tooltip: 'Seleccionar fecha',
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    const weekDays = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final dayLabel = '${weekDays[_selectedDate.weekday - 1]} ${_selectedDate.day} '
        '${const ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'][_selectedDate.month - 1]}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: _pickDate,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(dayLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleSwitch() {
    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _isDayView = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _isDayView ? const Color(0xFF3E6F58) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Día',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isDayView ? Colors.white : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _isDayView = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !_isDayView ? const Color(0xFF3E6F58) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Semana',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !_isDayView ? Colors.white : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
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
                Icon(Icons.info_outline, color: Colors.blue.withValues(alpha: 0.5), size: 20),
              ],
            ),
            const SizedBox(height: 24),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              _buildHeatmapGrid(),
            const SizedBox(height: 24),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _LegendItem(color: Color(0xFF3E6F58), label: 'Activo'),
                _LegendItem(color: Color(0xFF5A8B73), label: 'Moderado'),
                _LegendItem(color: Color(0xFFD68C5E), label: 'De Pie'),
                _LegendItem(color: Color(0xFFD1DCD6), label: 'Sentado'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmapGrid() {
    if (_isDayView) {
      final hours = _hourlyActivity();
      return Column(
        children: [
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: hours.indexed.map((entry) {
              final hour = entry.$1;
              final intensity = entry.$2;
              return Tooltip(
                message: '${_formatHour(hour)}: ${_intensityToLabel(intensity)}',
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _intensityColor(intensity),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      );
    } else {
      final grid = _weeklyActivityMap();
      final weekDays = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
      final nowWeekday = DateTime.now().weekday; // 1 (Mon) to 7 (Sun)
      
      return Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(width: 16),
              _TimeLabel(label: '12 AM'),
              _TimeLabel(label: '6 AM'),
              _TimeLabel(label: '12 PM'),
              _TimeLabel(label: '6 PM'),
              _TimeLabel(label: '11 PM'),
            ],
          ),
          const SizedBox(height: 8),
          ...grid.indexed.map((rowEntry) {
            final rowIndex = rowEntry.$1;
            final hoursRow = rowEntry.$2;
            
            final daysAgo = 6 - rowIndex;
            final wdIndex = (nowWeekday - 1 - daysAgo) % 7;
            final wdLabel = weekDays[wdIndex < 0 ? wdIndex + 7 : wdIndex];

            return Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 16,
                    child: Text(wdLabel, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                  ...hoursRow.indexed.map((hourEntry) {
                    final hour = hourEntry.$1;
                    final intensity = hourEntry.$2;
                    return Tooltip(
                      message: '$wdLabel, ${_formatHour(hour)}: ${_intensityToLabel(intensity)}',
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _intensityColor(intensity),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      );
    }
  }

  List<List<int>> _weeklyActivityMap() {
    final now = DateTime.now();
    final List<List<int>> grid = List.generate(7, (_) => List.filled(24, 0));
    
    for (final s in _weekSessions) {
      final start = DateTime.tryParse((s['start_time'] as String?) ?? '');
      if (start == null) continue;
      
      final startDay = DateTime(start.year, start.month, start.day);
      final nowDay = DateTime(now.year, now.month, now.day);
      final daysAgo = nowDay.difference(startDay).inDays;
      
      if (daysAgo >= 0 && daysAgo < 7) {
        final rowIndex = 6 - daysAgo; // 6 is today
        final type = (s['type'] as String?) ?? '';
        
        int intensity = 0;
        switch (type) {
          case 'idle': intensity = 1; break;
          case 'alert': intensity = 2; break;
          case 'active': intensity = 4; break;
        }
        
        if (intensity > grid[rowIndex][start.hour]) {
          grid[rowIndex][start.hour] = intensity;
        }
      }
    }
    return grid;
  }

  String _intensityToLabel(int intensity) {
    switch (intensity) {
      case 1: return 'Sentado';
      case 2: return 'De Pie';
      case 3: return 'Moderado';
      case 4: return 'Activo';
      default: return 'Sin registro';
    }
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
              Icon(icon, size: 16, color: borderColor.withValues(alpha: 0.5)),
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
    final week = _weekActiveMinutes();
    final totalWeek = week.fold<int>(0, (a, b) => a + b);
    final maxWeek = week.fold<int>(0, (a, b) => a > b ? a : b);
    final peak = maxWeek > 0 ? (maxWeek / (totalWeek > 0 ? totalWeek : 1) * 100).round() : 0;
    final hasWeekData = totalWeek > 0;

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
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: hasWeekData ? '$peak% ' : '0% ',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF3E6F58)),
                      ),
                      const TextSpan(
                        text: 'Día Pico\nActividad',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD68C5E)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++)
                  _buildBar(
                    height: hasWeekData && maxWeek > 0 ? (week[i] / maxWeek * 90).clamp(4.0, 90.0) : 4,
                    label: const ['L', 'M', 'M', 'J', 'V', 'S', 'D'][i],
                    isPeak: week[i] == maxWeek && maxWeek > 0,
                    minutes: week[i],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBar({required double height, required String label, bool isPeak = false, required int minutes}) {
    return Tooltip(
      message: '$label: $minutes min activos',
      child: Column(
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
                Container(height: 10, decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.05), borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildInsightsSection(ThemeData theme) {
    final peakWindow = _peakSedentaryWindow();
    final totalToday = _todaySessions.isNotEmpty ? _todaySessions.length : 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7F4),
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
            text: TextSpan(
              style: const TextStyle(color: Colors.black54, height: 1.5, fontSize: 13),
              children: [
                TextSpan(
                  text: totalToday > 0
                      ? 'Basado en tus $totalToday sesiones registradas hoy, tu menor actividad se concentra entre las '
                      : 'Aún no hay sesiones registradas hoy. La menor actividad suele concentrarse entre las ',
                ),
                TextSpan(
                  text: peakWindow,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD68C5E)),
                ),
                TextSpan(
                  text: totalToday > 0
                      ? '. Recomendamos una pausa activa de 5 minutos en ese horario para prevenir el pico sedentario de tu mapa de calor.'
                      : '. Conecta tu wearable y muévete para generar tu mapa de calor real.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _scheduleReminder,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3E6F58),
              minimumSize: const Size(double.infinity, 48),
            ),
            child: Text(
              _reminderScheduled
                  ? 'Recordatorio: ${_reminderTime!.format(context)} (Cambiar)'
                  : 'Configurar Recordatorio',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
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
