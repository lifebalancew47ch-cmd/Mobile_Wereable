import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/datasources/secure_database_service.dart';
import '../../../auth/presentation/providers/profile_provider.dart';

class PerformanceAnalysisScreen extends ConsumerStatefulWidget {
  const PerformanceAnalysisScreen({super.key});

  @override
  ConsumerState<PerformanceAnalysisScreen> createState() => _PerformanceAnalysisScreenState();
}

class _PerformanceAnalysisScreenState extends ConsumerState<PerformanceAnalysisScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9F1EC),
      body: SafeArea(
        child: FutureBuilder<Map<String, Object?>>(
          future: _loadAnalysis(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF3E6F58)),
              );
            }
            final data = snapshot.data ?? const {'activePct': 0.0, 'idlePct': 0.0};
            final activePct = (data['activePct'] as num?)?.toDouble() ?? 0.0;
            final idlePct = (data['idlePct'] as num?)?.toDouble() ?? 0.0;
            final maxIdleMinutes = (data['maxIdleMinutes'] as int?) ?? 0;
            final maxIdleTime = data['maxIdleTime'] as String? ?? '';
            final weekly = (data['weekly'] as List<Map<String, Object?>>?) ?? [];
            final todaySessions = (data['todaySessions'] as List<Map<String, Object?>>?) ?? [];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildCloudInsightsRow(context),
                  const SizedBox(height: 24),
                  const Text(
                    'ANÁLISIS DEL SISTEMA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3E6F58),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Análisis de\nRendimiento',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3E6F58),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildRiskCard(activePct),
                  const SizedBox(height: 20),
                  _buildDailyDivisionCard(activePct, idlePct),
                  const SizedBox(height: 20),
                  _buildStreakCard(maxIdleMinutes, maxIdleTime),
                  const SizedBox(height: 20),
                  _buildWeeklySedentaryCard(weekly),
                  const SizedBox(height: 32),
                  _buildFocusSessionsHeader(),
                  const SizedBox(height: 16),
                  if (todaySessions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Sin sesiones registradas hoy. Actívate y el sistema las registrará aquí.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    )
                  else
                    ...todaySessions.map((session) => _buildFocusSessionItem(session)),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<Map<String, Object?>> _loadAnalysis() async {
    final db = SecureDatabaseService.instance;
    final all = await db.getAllActivitySessions(limit: 500);
    final weekly = await db.getActivitySessionsLastDays(7);
    final today = await db.getActivitySessionsForDay(DateTime.now());

    var totalActive = 0;
    var totalIdle = 0;
    var maxIdleMinutes = 0;
    String maxIdleTime = '';
    for (final session in all) {
      final duration = (session['duration_minutes'] as int?) ?? 0;
      final type = (session['type'] as String?) ?? '';
      final start = session['start_time'] as String? ?? '';
      if (type == 'active') {
        totalActive += duration;
      } else if (type == 'idle' || type == 'alert') {
        totalIdle += duration;
        if (duration > maxIdleMinutes) {
          maxIdleMinutes = duration;
          maxIdleTime = start;
        }
      }
    }

    final total = totalActive + totalIdle;
    final activePct = total > 0 ? totalActive / total : 0.0;
    final idlePct = total > 0 ? totalIdle / total : 0.0;

    return {
      'activePct': activePct,
      'idlePct': idlePct,
      'maxIdleMinutes': maxIdleMinutes,
      'maxIdleTime': maxIdleTime,
      'weekly': weekly,
      'todaySessions': today,
    };
  }

  Widget _buildHeader() {
    final profileAsync = ref.watch(profileProvider);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            profileAsync.maybeWhen(
              data: (user) => CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF3E6F58),
                child: Text(
                  (user.firstName.isNotEmpty ? user.firstName : user.username)
                      .substring(0, 1)
                      .toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              orElse: () => const CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFF3E6F58),
                child: Icon(Icons.person, color: Colors.white, size: 20),
              ),
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
          onPressed: () => context.push('/dashboard/notifications'),
          icon: const Icon(Icons.notifications_none, color: Color(0xFF3E6F58)),
        ),
      ],
    );
  }

  Widget _buildCloudInsightsRow(BuildContext context) {
    final chipWidth = (MediaQuery.of(context).size.width - 20 * 2 - 12 * 3) / 4;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: chipWidth,
              child: _buildCloudChip(
                icon: Icons.grid_view,
                label: 'Mapa de\ncalor',
                onTap: () => context.push('/analytics/heatmap'),
              ),
            ),
            SizedBox(
              width: chipWidth,
              child: _buildCloudChip(
                icon: Icons.speed,
                label: 'Riesgo\nsedentario',
                onTap: () => context.push('/analytics/sedentary'),
              ),
            ),
            SizedBox(
              width: chipWidth,
              child: _buildCloudChip(
                icon: Icons.psychology_alt_outlined,
                label: 'Predicción\nML',
                onTap: () => context.push('/analytics/prediction'),
              ),
            ),
            SizedBox(
              width: chipWidth,
              child: _buildCloudChip(
                icon: Icons.monitor_heart_outlined,
                label: 'Datos\nmédicos',
                onTap: () => context.push('/analytics/medical'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCloudChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF3E6F58),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 26),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRiskCard(double activePct) {
    final riskLabel = activePct >= 0.4
        ? 'Riesgo de\nSalud\nBajo'
        : activePct >= 0.25
            ? 'Riesgo de\nSalud\nMedio'
            : 'Riesgo de\nSalud\nAlto';
    final percent = (activePct * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'EVALUACIÓN ACTUAL',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Text(
              riskLabel,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3E6F58),
                height: 1.1,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Umbral de Actividad', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                Text('$percent%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3E6F58))),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: activePct.clamp(0.0, 1.0),
                backgroundColor: const Color(0xFFE0EAE4),
                color: const Color(0xFF3E6F58),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Tu umbral de actividad es del $percent% sobre el tiempo registrado. ${activePct >= 0.4 ? 'Mantén este ritmo para conservar un riesgo bajo.' : activePct >= 0.25 ? 'Incrementa tus pausas activas para bajar el riesgo a nivel bajo.' : 'Tus patrones sedentarios predominan. Te recomendamos una pausa activa de 5 minutos cada 50.'}',
              style: const TextStyle(color: Colors.black54, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyDivisionCard(double activePct, double idlePct) {
    final active = (activePct * 100).round();
    final sedentary = (idlePct * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DIVISIÓN DIARIA',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: (activePct / 0.45).clamp(0.0, 1.0),
                      strokeWidth: 12,
                      backgroundColor: const Color(0xFFF2F6F4),
                      color: const Color(0xFF3E6F58),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$active%',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF3E6F58)),
                      ),
                      const Text(
                        'Activo',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSimpleLegend(color: const Color(0xFF3E6F58), label: '$active% Activo'),
                _buildSimpleLegend(color: const Color(0xFFD1DCD6), label: '$sedentary% Sedentario'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleLegend({required Color color, required String label}) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStreakCard(int maxIdleMinutes, String maxIdleTime) {
    final time = DateTime.tryParse(maxIdleTime);
    final timeLabel = time != null
        ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
        : '--:--';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: const Color(0xFFF0F7F4), borderRadius: BorderRadius.circular(4)),
                  child: const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF3E6F58)),
                ),
                const SizedBox(width: 8),
                const Text(
                  'RACHA MÁS LARGA',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _formatMinutes(maxIdleMinutes),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF3E6F58)),
            ),
            Text(
              'Sedentarismo ininterrumpido\nregistrado a las $timeLabel.',
              style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.4, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m';
  }

  Widget _buildWeeklySedentaryCard(List<Map<String, Object?>> weekly) {
    final perDay = <int>[0, 0, 0, 0, 0, 0, 0];
    final now = DateTime.now();
    for (final session in weekly) {
      final start = DateTime.tryParse((session['start_time'] as String?) ?? '');
      final duration = (session['duration_minutes'] as int?) ?? 0;
      final type = (session['type'] as String?) ?? '';
      if (start == null) continue;
      if (type != 'active') {
        final dayDiff = now.difference(DateTime(start.year, start.month, start.day)).inDays;
        if (dayDiff >= 0 && dayDiff < 7) {
          perDay[6 - dayDiff] += duration;
        }
      }
    }
    final max = perDay.reduce((a, b) => a > b ? a : b);
    const dayLetters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'HORAS SEDENTARIAS\n(ÚLTIMOS 7 DÍAS)',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 80,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (index) {
                  final value = perDay[index];
                  final height = max > 0 ? (value / max) * 70.0 : 4.0;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            value > 0 ? _shortHours(value) : '',
                            style: const TextStyle(fontSize: 8, color: Colors.grey),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            height: height.clamp(4.0, 70.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3E6F58).withValues(alpha: value > 0 ? 1.0 : 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: dayLetters
                  .map((d) => Text(d, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _shortHours(int minutes) {
    final h = minutes ~/ 60;
    return h > 0 ? '${h}h' : '${minutes}m';
  }

  Widget _buildFocusSessionsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Sesiones de\nEnfoque',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF3E6F58), height: 1.1),
        ),
        const Text(
          'Hoy',
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildFocusSessionItem(Map<String, Object?> session) {
    final type = (session['type'] as String?) ?? '';
    final duration = (session['duration_minutes'] as int?) ?? 0;
    final start = DateTime.tryParse((session['start_time'] as String?) ?? '');
    final end = DateTime.tryParse((session['end_time'] as String?) ?? '');

    final (icon, title) = switch (type) {
      'active' => (Icons.directions_run, 'Sesión Activa'),
      'alert' => (Icons.warning_amber_rounded, 'Alerta de Sedentarismo'),
      _ => (Icons.chair_alt, 'Período Sedentario'),
    };
    final startLabel = start != null
        ? '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}'
        : '--:--';
    final endLabel = end != null
        ? '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}'
        : '--:--';

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7F4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE0EAE4)),
            ),
            child: Icon(icon, color: const Color(0xFF3E6F58), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('$startLabel - $endLabel', style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_formatMinutes(duration), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFD68C5E))),
              Text(_typeLabel(type), style: const TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    return switch (type) {
      'active' => 'Movimiento',
      'alert' => 'Riesgo',
      _ => 'Inactivo',
    };
  }
}
