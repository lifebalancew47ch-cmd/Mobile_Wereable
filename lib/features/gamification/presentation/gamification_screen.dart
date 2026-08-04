import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/secure_database_service.dart';
import 'providers/gamification_provider.dart';
import '../data/gamification_api_service.dart';

class GamificationScreen extends ConsumerStatefulWidget {
  const GamificationScreen({super.key});

  @override
  ConsumerState<GamificationScreen> createState() => _GamificationScreenState();
}

class _GamificationScreenState extends ConsumerState<GamificationScreen> {
  final SecureDatabaseService _db = SecureDatabaseService.instance;
  bool _loading = true;

  List<Map<String, Object?>> _sessions = [];
  int _activeMinutes = 0;
  int _idleMinutes = 0;
  int _daysWithActivity = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final sessions = await _db.getAllActivitySessions(limit: 1000);

    var active = 0;
    var idle = 0;
    final activeDays = <String>{};

    for (final session in sessions) {
      final duration = (session['duration_minutes'] as int?) ?? 0;
      final type = (session['type'] as String?) ?? '';
      if (type == 'active') {
        active += duration;
        final start = DateTime.tryParse((session['start_time'] as String?) ?? '');
        if (start != null) {
          activeDays.add('${start.year}-${start.month}-${start.day}');
        }
      } else if (type == 'idle' || type == 'alert') {
        idle += duration;
      }
    }

    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _activeMinutes = active;
      _idleMinutes = idle;
      _daysWithActivity = activeDays.length;
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(gamificationProfileProvider);
    ref.invalidate(gamificationLeaderboardProvider);
    await _loadStats();
  }

  Widget _buildCloudProfileCard(ThemeData theme, ColorScheme colorScheme, AsyncValue<GamificationProfile> async) {
    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withAlpha(60),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: async.when(
          loading: () => const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No se pudo cargar tu perfil de la nube.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ref.invalidate(gamificationProfileProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
          data: (profile) => Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: colorScheme.primary,
                child: Icon(Icons.emoji_events, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Nivel ${profile.level}',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${profile.badgesUnlocked} medallas',
                            style: TextStyle(fontSize: 11, color: colorScheme.onPrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${profile.points} pts · racha de ${profile.currentStreakDays} días',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardCard(ThemeData theme, AsyncValue<List<LeaderboardItem>> async) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ranking',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            async.when(
              loading: () => const SizedBox(
                height: 60,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(
                'No se pudo cargar el ranking.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const Text('Sin participantes aún.',
                      style: TextStyle(color: Colors.grey));
                }
                return Column(
                  children: [
                    for (final item in items.take(10))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 32,
                              child: Text(
                                '${item.position}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: item.position <= 3
                                      ? theme.colorScheme.primary
                                      : Colors.grey,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _shortUserId(item.userId),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${item.points} pts',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _shortUserId(String userId) {
    if (userId.isEmpty) return 'Usuario';
    if (userId.length <= 12) return userId;
    return '${userId.substring(0, 8)}…';
  }

  List<_Achievement> _computeAchievements() {
    return [
      _Achievement(
        icon: Icons.directions_run,
        title: 'Primeros Pasos',
        description: 'Registra tus primeros 30 minutos activos',
        unlocked: _activeMinutes >= 30,
        progress: (_activeMinutes / 30).clamp(0.0, 1.0),
      ),
      _Achievement(
        icon: Icons.local_fire_department,
        title: 'En Racha',
        description: 'Acumula 100 minutos activos',
        unlocked: _activeMinutes >= 100,
        progress: (_activeMinutes / 100).clamp(0.0, 1.0),
      ),
      _Achievement(
        icon: Icons.calendar_month,
        title: 'Constancia',
        description: 'Actividad registrada en 3 días distintos',
        unlocked: _daysWithActivity >= 3,
        progress: (_daysWithActivity / 3).clamp(0.0, 1.0),
      ),
      _Achievement(
        icon: Icons.timer_outlined,
        title: 'Guardia Activa',
        description: 'Acumula 300 minutos de actividad total',
        unlocked: _activeMinutes >= 300,
        progress: (_activeMinutes / 300).clamp(0.0, 1.0),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profileAsync = ref.watch(gamificationProfileProvider);
    final leaderboardAsync = ref.watch(gamificationLeaderboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gamificación')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Perfil de gamificación desde la nube
                  _buildCloudProfileCard(theme, colorScheme, profileAsync),
                  const SizedBox(height: 16),
                  _buildLeaderboardCard(theme, leaderboardAsync),
                  const SizedBox(height: 16),
                  // Resumen de estadísticas
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.directions_run,
                          value: '$_activeMinutes',
                          label: 'min activos',
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.airline_seat_recline_normal,
                          value: '$_idleMinutes',
                          label: 'min inactivo',
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.calendar_month,
                          value: '$_daysWithActivity',
                          label: 'días activos',
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Logros',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  for (final achievement in _computeAchievements())
                    _buildAchievementCard(achievement, colorScheme),

                  const SizedBox(height: 24),

                  Text(
                    'Actividad reciente',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  if (_sessions.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.hourglass_empty, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            const Text(
                              'Aún no hay sesiones registradas',
                              style: TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Conecta tu wearable y muévete para empezar a ganar logros.',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Card(
                      child: Column(
                        children: [
                          for (final session in _sessions.take(5))
                            ListTile(
                              leading: Icon(
                                _sessionIcon(session['type'] as String?),
                                color: _sessionColor(session['type'] as String?),
                              ),
                              title: Text(_sessionTitle(session['type'] as String?)),
                              subtitle: Text(_formatSessionDate(session['start_time'] as String?)),
                              trailing: Text(
                                '${session['duration_minutes']} min',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      color: color.withAlpha(30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementCard(_Achievement achievement, ColorScheme colorScheme) {
    final progress = (achievement.progress * 100).round();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: achievement.unlocked
          ? colorScheme.primaryContainer.withAlpha(80)
          : colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: achievement.unlocked
                      ? colorScheme.primary
                      : Colors.grey.shade300,
                  child: Icon(
                    achievement.unlocked
                        ? Icons.emoji_events
                        : achievement.icon,
                    color: achievement.unlocked ? Colors.white : Colors.grey.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        achievement.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        achievement.description,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Text(
                  achievement.unlocked ? '✓' : '$progress%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: achievement.unlocked ? colorScheme.primary : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: achievement.unlocked ? 1.0 : achievement.progress,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _sessionIcon(String? type) {
    switch (type) {
      case 'active':
        return Icons.directions_run;
      case 'alert':
        return Icons.warning_amber;
      default:
        return Icons.airline_seat_recline_normal;
    }
  }

  Color _sessionColor(String? type) {
    switch (type) {
      case 'active':
        return Colors.green;
      case 'alert':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _sessionTitle(String? type) {
    switch (type) {
      case 'active':
        return 'Actividad';
      case 'alert':
        return 'Alerta de sedentarismo';
      default:
        return 'Inactividad';
    }
  }

  String _formatSessionDate(String? iso) {
    final date = DateTime.tryParse(iso ?? '');
    if (date == null) return '--';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '${date.year}-$month-$day $hh:$mm';
  }
}

class _Achievement {
  final IconData icon;
  final String title;
  final String description;
  final bool unlocked;
  final double progress;

  _Achievement({
    required this.icon,
    required this.title,
    required this.description,
    required this.unlocked,
    required this.progress,
  });
}
