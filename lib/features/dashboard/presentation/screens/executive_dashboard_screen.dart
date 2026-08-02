import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/datasources/secure_database_service.dart';
import '../../../auth/presentation/providers/profile_provider.dart';
import '../../../fog/presentation/providers/fog_providers.dart';
import '../../presentation/providers/dashboard_provider.dart';
import '../../../../models/fog_state.dart';

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

    return Scaffold(
      backgroundColor: const Color(0xFFE9F1EC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              _buildHeader(),
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
                      _buildScoreCircle(score, state.inactiveMinutes, label),
                      const SizedBox(height: 24),
                      _buildTrendBadge(),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              FutureBuilder<Map<String, int>>(
                future: _loadLocalStats(),
                builder: (context, statsSnapshot) {
                  final stats = statsSnapshot.data ?? {'active': 0, 'idle': 0, 'alerts': 0, 'todaySessions': 0};

                  return dashboardAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(color: Color(0xFF3E6F58)),
                      ),
                    ),
                    error: (_, __) => _buildMetricsGrid(stats),
                    data: (data) => _buildMetricsGrid(stats, dashboard: data),
                  );
                },
              ),
              const SizedBox(height: 24),

              _buildAnalysisCard(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<String, int>> _loadLocalStats() async {
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
    return {'active': active, 'idle': idle, 'alerts': alerts, 'todaySessions': todaySessions};
  }

  Widget _buildHeader() {
    final profileAsync = ref.watch(profileProvider);
    return Row(
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
        profileAsync.maybeWhen(
          data: (user) => CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF3E6F58),
            child: Text(
              (user.firstName.isNotEmpty ? user.firstName : user.username)
                  .substring(0, 1)
                  .toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
          orElse: () => IconButton(
            onPressed: () => context.push('/dashboard/notifications'),
            icon: const Icon(Icons.notifications_none, color: Color(0xFF3E6F58)),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreCircle(double score, int minutes, String label) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: CircularProgressIndicator(
              value: score,
              strokeWidth: 12,
              backgroundColor: Colors.white.withValues(alpha: 0.5),
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
              Text(
                '$minutes',
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3E6F58),
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

  Widget _buildTrendBadge() {
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
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(up ? Icons.trending_up : Icons.trending_down,
                    size: 14,
                    color: up ? const Color(0xFF3E6F58) : const Color(0xFFD68C5E)),
                const SizedBox(width: 6),
                Text(
                  '${up ? '+' : ''}$pct% vs ayer',
                  style: TextStyle(
                    fontSize: 11,
                    color: up ? const Color(0xFF3E6F58) : const Color(0xFFD68C5E),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricsGrid(Map<String, int> stats, {DashboardData? dashboard}) {
    final activeMinutes = (dashboard?.summary?.activeMinutes ?? stats['active'] ?? 0).round();
    final todaySessions = stats['todaySessions'] ?? 0;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.schedule,
                label: 'DIARIO',
                value: _formatMinutes(stats['idle'] ?? 0),
                description: 'Inactividad Total',
                color: const Color(0xFF3E6F58),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.chair_alt,
                label: 'ACTIVO',
                value: _formatMinutes(activeMinutes),
                description: 'Minutos en Movimiento',
                color: const Color(0xFF3E6F58),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.warning_amber_rounded,
                label: 'ALERTAS',
                value: '${stats['alerts'] ?? 0}',
                description: 'Alertas de Sedentarismo',
                color: const Color(0xFFD68C5E),
                hasSideBorder: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildProgressBarCard(
                icon: Icons.directions_walk,
                current: todaySessions,
                total: _goalPauses,
                description: 'Pausas Activas',
              ),
            ),
          ],
        ),
      ],
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

        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 90,
                    color: const Color(0xFF1E1E1E),
                    child: Center(
                      child: Text(
                        '${minutes >= 45 ? 'Riesgo de inactividad prolongada' : 'Estado de actividad saludable'}\nMonitorizando en tiempo real...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: minutes >= 45 ? const Color(0xFFD68C5E) : Colors.white54,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
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
                Text(
                  minutes >= 45
                      ? 'Llevas $minutes minutos de inactividad continua. Una pausa activa de 2 minutos ahora puede restablecer tu concentración y mejorar tu rendimiento.'
                      : 'Tu actividad actual es saludable ($minutes min de inactividad). Continúa con pausas activas cada 45-50 minutos para mantener tu nivel óptimo.',
                  style: const TextStyle(color: Colors.black54, fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 20),
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
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Programar Pausa Activa', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
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
              value: total > 0 ? current / total : 0,
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
