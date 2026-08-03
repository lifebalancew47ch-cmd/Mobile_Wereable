import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/datasources/secure_database_service.dart';
import '../../../fog/presentation/providers/fog_providers.dart';
import '../../presentation/providers/dashboard_provider.dart';
import '../../../../models/fog_state.dart';
import '../../../../models/vital_sign.dart';
import '../../../wearable/presentation/wearable_provider.dart';

class ExecutiveDashboardScreen extends ConsumerStatefulWidget {
  const ExecutiveDashboardScreen({super.key});

  @override
  ConsumerState<ExecutiveDashboardScreen> createState() => _ExecutiveDashboardScreenState();
}

class _ExecutiveDashboardScreenState extends ConsumerState<ExecutiveDashboardScreen> {
  static const int _goalPauses = 5;

  @override
  Widget build(BuildContext context) {
    final fogEngine = ref.watch(fogEngineProvider);
    final dashboardAsync = ref.watch(dashboardDataProvider);
    final liveSensor = ref.watch(sensorSampleProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F8F4),
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
            tooltip: 'Emparejar wearable',
            onPressed: () => context.push('/profile/wearable-scan'),
            icon: const Icon(Icons.bluetooth_searching, color: Colors.black87),
          ),
          IconButton(
            onPressed: () => context.push('/dashboard/notifications'),
            icon: const Icon(Icons.notifications_none, color: Colors.black87),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 32),
            StreamBuilder<FogState>(
              stream: fogEngine.stateStream,
              builder: (context, snapshot) {
                final state = snapshot.data ?? FogState(
                  status: ActivityStatus.active,
                  inactiveMinutes: 0,
                  lastMovement: DateTime.now(),
                );
                final score = (state.inactiveMinutes / 90.0).clamp(0.0, 1.0);
                final label = _riskLabel(state.inactiveMinutes);

                return Column(
                  children: [
                    _buildScoreGauge(score, state.inactiveMinutes, label),
                    const SizedBox(height: 24),
                    _buildTrendPill(),
                  ],
                );
              },
            ),
            const SizedBox(height: 40),

            FutureBuilder<Map<String, dynamic>>(
              future: _loadLocalStats(),
              builder: (context, statsSnapshot) {
                final stats = statsSnapshot.data ?? {'active': 0, 'idle': 0, 'alerts': 0, 'todaySessions': 0, 'steps': 0, 'heartRate': 0.0};
                
                // Sobrescribir stats locales con datos EN VIVO del wearable si existen
                if (liveSensor.value != null) {
                  final live = liveSensor.value!;
                  if (live.steps > 0) stats['steps'] = live.steps;
                  if (live.heartRate > 0) stats['heartRate'] = live.heartRate;
                }

                return dashboardAsync.when(
                  loading: () => _buildMetricsGrid(stats),
                  error: (_, __) => _buildMetricsGrid(stats),
                  data: (data) => _buildMetricsGrid(stats, dashboard: data),
                );
              },
            ),
            const SizedBox(height: 24),
            _buildAnalysisCard(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _loadLocalStats() async {
    final db = SecureDatabaseService.instance;
    final today = await db.getActivitySessionsForDay(DateTime.now());
    var active = 0;
    var idle = 0;
    var alerts = 0;
    for (final session in today) {
      final duration = (session['duration_minutes'] as int?) ?? 0;
      final type = (session['type'] as String?) ?? '';
      if (type == 'active') {
        active += duration;
      } else if (type == 'idle') {
        idle += duration;
      } else if (type == 'alert') {
        alerts += duration;
      }
    }
    final todaySessions = await db.countActivitySessionsToday();
    
    final dbInstance = await db.database;
    final vitalRows = await dbInstance.query('vital_signs', orderBy: 'timestamp DESC', limit: 1);
    var localSteps = 0;
    var localHeartRate = 0.0;
    if (vitalRows.isNotEmpty) {
      localSteps = (vitalRows.first['steps'] as num?)?.toInt() ?? 0;
      localHeartRate = (vitalRows.first['heart_rate'] as num?)?.toDouble() ?? 0.0;
    }

    return {'active': active, 'idle': idle, 'alerts': alerts, 'todaySessions': todaySessions, 'steps': localSteps, 'heartRate': localHeartRate};
  }

  Widget _buildScoreGauge(double score, int minutes, String label) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: CircularProgressIndicator(
              value: score,
              strokeWidth: 14,
              backgroundColor: Colors.white,
              color: const Color(0xFF3E6F58),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'PUNTUACIÓN SEDENTARIA',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Color(0xFF3E6F58),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$minutes',
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A34),
                  height: 1,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
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
    );
  }

  String _riskLabel(int minutes) {
    if (minutes < 30) return 'BAJA';
    if (minutes < 60) return 'MODERADA';
    return 'ALTA';
  }

  Widget _buildTrendPill() {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: SecureDatabaseService.instance.getActivitySessionsLastDays(2),
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? [];
        final now = DateTime.now();
        var todayActive = 0;
        var yesterdayActive = 0;
        for (final session in sessions) {
          final start = DateTime.tryParse((session['start_time'] as String?) ?? '');
          final duration = (session['duration_minutes'] as int?) ?? 0;
          if (start == null) continue;
          if ((session['type'] as String?) == 'active') {
            final isToday = start.year == now.year && start.month == now.month && start.day == now.day;
            if (isToday) {
              todayActive += duration;
            } else {
              yesterdayActive += duration;
            }
          }
        }
        final pct = yesterdayActive > 0 ? ((todayActive - yesterdayActive) / yesterdayActive * 100).round() : 0;
        final up = pct >= 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(up ? Icons.trending_up : Icons.trending_down, size: 14, color: up ? const Color(0xFF3E6F58) : Colors.orange.shade700),
              const SizedBox(width: 6),
              Text(
                '${up ? '+' : ''}$pct% vs ayer',
                style: TextStyle(
                  fontSize: 11,
                  color: up ? const Color(0xFF3E6F58) : Colors.orange.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricsGrid(Map<String, dynamic> stats, {DashboardData? dashboard}) {
    final activeMinutes = (dashboard?.summary?.activeMinutes ?? stats['active'] ?? 0).round();
    final todaySessions = stats['todaySessions'] ?? 0;
    
    final cloudSteps = dashboard?.kpis?.dailySteps ?? dashboard?.summary?.dailySteps;
    final localSteps = stats['steps'] as int? ?? 0;
    final displaySteps = cloudSteps != null && cloudSteps > 0 ? cloudSteps : localSteps;

    final cloudHR = dashboard?.kpis?.heartRate;
    final localHR = stats['heartRate'] as double? ?? 0.0;
    final displayHR = cloudHR != null && cloudHR > 0 ? cloudHR : localHR;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.access_time,
                  label: 'DIARIO',
                  value: _formatMinutes(stats['idle'] ?? 0),
                  subtitle: 'Inactividad Total',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.chair_alt_outlined,
                  label: 'ALERTAS',
                  value: '${stats['alerts'] ?? 0}',
                  subtitle: 'Alertas de Sedentarismo',
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
                  label: 'ACTIVO',
                  value: _formatMinutes(activeMinutes),
                  subtitle: 'Minutos en Movimiento',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.directions_run,
                  label: 'META',
                  value: '$todaySessions/$_goalPauses',
                  subtitle: 'Pausas Activas',
                  showProgress: true,
                  progress: todaySessions / _goalPauses,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.directions_walk,
                  label: 'PASOS',
                  value: displaySteps > 0 ? '$displaySteps' : '--',
                  subtitle: 'Total del día',
                  labelColor: Colors.blue.shade700,
                  hasSideBorder: true,
                  borderColor: Colors.blue.shade700,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.favorite,
                  label: 'LATIDOS',
                  value: displayHR > 0 ? '${displayHR.toStringAsFixed(0)} bpm' : '--',
                  subtitle: 'Ritmo cardíaco',
                  labelColor: Colors.red.shade700,
                  hasSideBorder: true,
                  borderColor: Colors.red.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  Widget _buildAnalysisCard() {
    final fogEngine = ref.watch(fogEngineProvider);
    final notifications = ref.read(notificationServiceProvider);

    return StreamBuilder<FogState>(
      stream: fogEngine.stateStream,
      builder: (context, snapshot) {
        final state = snapshot.data ?? FogState(
          status: ActivityStatus.active,
          inactiveMinutes: 0,
          lastMovement: DateTime.now(),
        );
        final minutes = state.inactiveMinutes;

        return Container(
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
                child: Container(
                  height: 140,
                  color: const Color(0xFF1E3A34),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            minutes >= 45 ? Icons.warning_amber_rounded : Icons.monitor_heart_outlined,
                            color: minutes >= 45 ? const Color(0xFFD68C5E) : Colors.white70,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            minutes >= 45 ? 'Riesgo de inactividad' : 'Estado saludable',
                            style: TextStyle(
                              color: minutes >= 45 ? const Color(0xFFD68C5E) : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        minutes >= 45
                            ? '$minutes minutos inactivo. Una pausa activa de 2 min restaura tu rendimiento.'
                            : 'Monitorizando tu actividad en tiempo real. Pausas cada 45-50 min.',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.psychology_outlined, color: Color(0xFF3E6F58), size: 28),
                  const SizedBox(width: 10),
                  const Text(
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
              Text(
                minutes >= 45
                    ? 'Llevas $minutes minutos de inactividad continua. Tomar un descanso de movimiento de 2 minutos ahora aumentará tu rendimiento cognitivo durante la próxima hora.'
                    : 'Tu actividad actual es saludable ($minutes min inactivo). Sigue con pausas activas cada 45-50 minutos para mantener tu nivel óptimo.',
                style: const TextStyle(color: Colors.black54, fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  final now = DateTime.now().add(const Duration(minutes: 10));
                  await notifications.scheduleReminder(
                    hour: now.hour,
                    minute: now.minute,
                    title: 'Pausa Activa',
                    body: 'Es momento de levantarte y moverte 2 minutos.',
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pausa activa programada en 10 minutos'),
                      backgroundColor: Color(0xFF3E6F58),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3E6F58),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Programar Pausa Activa', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
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
    double? progress,
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
                    color: (labelColor ?? const Color(0xFF3E6F58)).withValues(alpha: 0.05),
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
              child: LinearProgressIndicator(
                value: (progress ?? 0).clamp(0.0, 1.0),
                backgroundColor: const Color(0xFFF2F8F4),
                color: const Color(0xFF3E6F58),
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
