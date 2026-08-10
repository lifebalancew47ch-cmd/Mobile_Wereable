import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/dynamic_onboarding_service.dart';
import '../../../../data/datasources/secure_database_service.dart';
import '../../../auth/presentation/providers/profile_provider.dart';
import '../../../fog/presentation/providers/fog_providers.dart';
import '../../presentation/providers/dashboard_provider.dart';
import '../../../../models/fog_state.dart';
import '../../../wearable/presentation/wearable_provider.dart';
import '../../../settings/domain/alert_settings.dart';
import '../../../settings/presentation/providers/alert_settings_provider.dart';
import '../../../../core/security/secure_storage.dart';

class ExecutiveDashboardScreen extends ConsumerStatefulWidget {
  const ExecutiveDashboardScreen({super.key});

  @override
  ConsumerState<ExecutiveDashboardScreen> createState() => _ExecutiveDashboardScreenState();
}

class _ExecutiveDashboardScreenState extends ConsumerState<ExecutiveDashboardScreen> {
  static const int _goalPauses = 5;
  Future<Map<String, dynamic>>? _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadLocalStats();
  }

  @override
  Widget build(BuildContext context) {
    final fogEngine = ref.watch(fogEngineProvider);
    final dashboardAsync = ref.watch(dashboardDataProvider);
    final liveSensor = ref.watch(sensorSampleProvider);
    final wearableState = ref.watch(wearableProvider);
    final alertSettings = ref.watch(alertSettingsProvider).value ??
        const AlertSettings(intervalMinutes: 45);
    final profileAsync = ref.watch(profileProvider);

    final userName = profileAsync.maybeWhen(
      data: (user) => user.firstName.isNotEmpty
          ? user.firstName
          : (user.username.isNotEmpty ? user.username : 'Usuario'),
      orElse: () => 'Usuario',
    );

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
            const SizedBox(height: 16),
            _buildDynamicWelcomeBanner(userName),
            const SizedBox(height: 16),
            _buildWearableStatus(wearableState),
            const SizedBox(height: 24),
            StreamBuilder<FogState>(
              stream: fogEngine.stateStream,
              builder: (context, snapshot) {
                final state = snapshot.data ?? FogState(
                  status: ActivityStatus.active,
                  inactiveMinutes: 0,
                  lastMovement: DateTime.now(),
                );
                final score = (state.inactiveMinutes / alertSettings.intervalMinutes)
                    .clamp(0.0, 1.0);
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
              future: _statsFuture,
              builder: (context, statsSnapshot) {
                final stats = statsSnapshot.data ?? {'active': 0, 'idle': 0, 'alerts': 0, 'todaySessions': 0, 'steps': 0, 'heartRate': 0.0};
                
                // Sobrescribir stats locales con datos EN VIVO del wearable si existen
                final live = liveSensor.value ?? wearableState.lastSample;
                if (live != null) {
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
    final heightStr = await secureStorage.read(key: 'biometric_height_cm');
    final weightStr = await secureStorage.read(key: 'biometric_weight_kg');
    final bmiStr    = await secureStorage.read(key: 'biometric_bmi');
    var localBmi = 0.0;
    if (bmiStr != null && bmiStr.isNotEmpty) {
      localBmi = double.tryParse(bmiStr) ?? 0.0;
    }
    if (localBmi <= 0 && heightStr != null && weightStr != null) {
      final h = double.tryParse(heightStr);
      final w = double.tryParse(weightStr);
      if (h != null && w != null && h > 0 && w > 0) {
        localBmi = w / ((h / 100.0) * (h / 100.0));
      }
    }

    return {
      'active': active,
      'idle': idle,
      'alerts': alerts,
      'todaySessions': todaySessions,
      'steps': localSteps,
      'heartRate': localHeartRate,
      'bmi': localBmi,
    };
  }

  Widget _buildWearableStatus(WearableState state) {
    final connected = state.isConnected;
    final last = state.lastData;
    final lastTime = last != null
        ? DateTime.fromMillisecondsSinceEpoch(last.timestamp)
        : null;
    final timeLabel = lastTime != null
        ? '${lastTime.hour.toString().padLeft(2, '0')}:${lastTime.minute.toString().padLeft(2, '0')}:${lastTime.second.toString().padLeft(2, '0')}'
        : '--';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: connected ? const Color(0xFFE4F1EA) : const Color(0xFFF5EFE8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              connected ? Icons.watch : Icons.watch_off,
              color: connected ? const Color(0xFF3E6F58) : const Color(0xFFD68C5E),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    connected ? 'Reloj conectado' : 'Reloj desconectado',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: connected ? const Color(0xFF1E3A34) : const Color(0xFF8A6A4A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    connected
                        ? 'Datos en vivo · último lote $timeLabel'
                        : 'Vincula tu reloj Wear OS para datos en vivo',
                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                ],
              ),
            ),
            if (connected)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF52C480),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
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
    final displaySteps = localSteps > 0 ? localSteps : (cloudSteps != null && cloudSteps > 0 ? cloudSteps : 0);

    final cloudHR = dashboard?.kpis?.heartRate;
    final localHR = stats['heartRate'] as double? ?? 0.0;
    final displayHR = localHR > 0 ? localHR : (cloudHR != null && cloudHR > 0 ? cloudHR : 0.0);

    final cloudCalories = dashboard?.kpis?.caloriesBurned;
    final calculatedCalories = (activeMinutes * 5.0) + (displaySteps * 0.04);
    final displayCalories = (cloudCalories != null && cloudCalories > 0) ? cloudCalories : calculatedCalories;

    final cloudBmi = dashboard?.kpis?.bmi;
    final localBmi = (stats['bmi'] as num?)?.toDouble() ?? 0.0;
    final displayBmi = (cloudBmi != null && cloudBmi > 0) ? cloudBmi : localBmi;

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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.local_fire_department,
                  label: 'CALORÍAS',
                  value: displayCalories > 0 ? '${displayCalories.toStringAsFixed(0)} kcal' : '--',
                  subtitle: 'Energía quemada',
                  labelColor: Colors.deepOrange.shade700,
                  hasSideBorder: true,
                  borderColor: Colors.deepOrange.shade700,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.monitor_weight_outlined,
                  label: 'IMC',
                  value: displayBmi > 0 ? displayBmi.toStringAsFixed(1) : '--',
                  subtitle: 'Índice masa corporal',
                  labelColor: Colors.teal.shade700,
                  hasSideBorder: true,
                  borderColor: Colors.teal.shade700,
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

  Widget _buildDynamicWelcomeBanner(String userName) {
    final phase = DynamicOnboardingService.getTimePhase();
    final service = DynamicOnboardingService();
    final welcomePhrase = service.getRandomWelcomePhrase(userName);

    IconData phaseIcon;
    switch (phase) {
      case TimePhase.madrugada:
        phaseIcon = Icons.bedtime;
        break;
      case TimePhase.manana:
        phaseIcon = Icons.wb_sunny;
        break;
      case TimePhase.mediodia:
        phaseIcon = Icons.wb_twilight;
        break;
      case TimePhase.tarde:
        phaseIcon = Icons.nature_people;
        break;
      case TimePhase.noche:
        phaseIcon = Icons.nightlight_round;
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3E6F58), Color(0xFF2C5240)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3E6F58).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(phaseIcon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DynamicOnboardingService.getPhaseTitle(phase),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withValues(alpha: 0.9),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'LifeBalance',
                        style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  welcomePhrase,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
