import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/datasources/secure_database_service.dart';
import '../providers/system_status_provider.dart';

class AdminSummaryScreen extends ConsumerStatefulWidget {
  const AdminSummaryScreen({super.key});

  @override
  ConsumerState<AdminSummaryScreen> createState() => _AdminSummaryScreenState();
}

class _AdminSummaryScreenState extends ConsumerState<AdminSummaryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, Object?>> _allSessions = [];
  List<Map<String, Object?>> _filteredSessions = [];
  Map<String, int> _stats = {'active': 0, 'idle': 0, 'alerts': 0, 'sessionsToday': 0, 'vitalsToday': 0, 'alertsToday': 0};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = SecureDatabaseService.instance;
    final all = await db.getAllActivitySessions(limit: 1000);
    final todaySessions = await db.countActivitySessionsToday();
    final vitalsToday = await db.countVitalSignsToday();
    final alertsToday = await db.countAlertsToday();

    var active = 0;
    var idle = 0;
    var alerts = 0;
    for (final session in all) {
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

    if (!mounted) return;
    setState(() {
      _allSessions = all;
      _filteredSessions = all;
      _stats = {
        'active': active,
        'idle': idle,
        'alerts': alerts,
        'sessionsToday': todaySessions,
        'vitalsToday': vitalsToday,
        'alertsToday': alertsToday,
      };
    });
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredSessions = _allSessions;
        return;
      }
      _filteredSessions = _allSessions.where((session) {
        final type = ((session['type'] as String?) ?? '').toLowerCase();
        final start = (session['start_time'] as String?) ?? '';
        return type.contains(q) || start.toLowerCase().contains(q);
      }).toList();
    });
  }

  int _riskScore() {
    final idleMinutes = _stats['idle'] ?? 0;
    final activeMinutes = _stats['active'] ?? 0;
    final total = idleMinutes + activeMinutes;
    if (total == 0) return 0;
    return ((idleMinutes / total) * 100).round();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sedentaryIndex = _riskScore();
    final riskLabel = sedentaryIndex >= 60
        ? 'Alto'
        : sedentaryIndex >= 30
            ? 'Moderado'
            : 'Bajo';
    final sessionsToday = _stats['sessionsToday'] ?? 0;
    final metaPct = sessionsToday >= 5 ? 100 : (sessionsToday / 5 * 100).round();

    return Scaffold(
      backgroundColor: const Color(0xFFE9F1EC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF3E6F58),
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      'LB',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearch,
                  decoration: const InputDecoration(
                    hintText: 'Buscar sesión (activa, alerta, sedentaria)...',
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

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                children: [
                  _buildAdminMetricCard(
                    icon: Icons.person_outline,
                    iconBgColor: const Color(0xFFF0F7F4),
                    title: 'Sesiones Registradas Hoy',
                    value: '${_stats['sessionsToday'] ?? 0}',
                    trendLabel: '${_stats['vitalsToday'] ?? 0} signos vitales',
                    trendColor: const Color(0xFF3E6F58),
                  ),
                  const SizedBox(height: 16),
                  _buildAdminMetricCard(
                    icon: Icons.timer_outlined,
                    iconBgColor: const Color(0xFFFEF3EB),
                    title: 'Índice Sedentario',
                    value: '$sedentaryIndex%',
                    trendLabel: '${_stats['alerts'] ?? 0} min en alertas',
                    trendColor: const Color(0xFFD68C5E),
                  ),
                  const SizedBox(height: 16),
                  _buildAdminMetricCard(
                    icon: Icons.warning_amber_rounded,
                    iconBgColor: const Color(0xFFFEF3EB),
                    title: 'Riesgo de Sedentarismo',
                    value: riskLabel,
                    valueColor: sedentaryIndex >= 60 ? const Color(0xFFD68C5E) : const Color(0xFF3E6F58),
                    statusLabel: '${_stats['alertsToday'] ?? 0} alertas hoy',
                    statusColor: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  _buildAdminMetricCard(
                    icon: Icons.directions_run,
                    iconBgColor: const Color(0xFFF0F7F4),
                    title: 'Meta de Actividad',
                    value: '$metaPct%',
                    trendLabel: '5 pausas diarias',
                    trendColor: const Color(0xFF3E6F58),
                  ),
                  const SizedBox(height: 24),

                  _buildSystemStatusCard(),
                  const SizedBox(height: 24),

                  const Text(
                    'Resultados de búsqueda',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3E6F58)),
                  ),
                  const SizedBox(height: 12),
                  if (_filteredSessions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Sin resultados',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    )
                  else
                    ..._filteredSessions.take(10).map(_buildSessionTile),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionTile(Map<String, Object?> session) {
    final type = (session['type'] as String?) ?? '';
    final duration = (session['duration_minutes'] as int?) ?? 0;
    final start = DateTime.tryParse((session['start_time'] as String?) ?? '');

    final (icon, label) = switch (type) {
      'active' => (Icons.directions_run, 'Sesión Activa'),
      'alert' => (Icons.warning_amber_rounded, 'Alerta de Sedentarismo'),
      _ => (Icons.chair_alt, 'Período Sedentario'),
    };
    final dateLabel = start != null
        ? '${start.day}/${start.month} ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}'
        : '--';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF3E6F58), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$duration min', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD68C5E), fontSize: 12)),
              Text(dateLabel, style: const TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
        ],
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
            color: Colors.black.withValues(alpha: 0.03),
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

  Widget _buildSystemStatusCard() {
    final statusAsync = ref.watch(systemStatusProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dns_outlined, color: Color(0xFF3E6F58), size: 22),
              const SizedBox(width: 10),
              const Text(
                'Estado del Sistema',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF3E6F58)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          statusAsync.when(
            loading: () => const SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text(
              'No se pudo consultar el estado.\n$e',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            data: (status) {
              if (!status.loaded) {
                return const Text(
                  'No hay información de servicios disponible.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                );
              }
              final health = status.health;
              final system = status.system;
              final version = status.version;

              final serviceName = system['serviceName']?.toString() ?? system['name']?.toString();
              final statusValue = system['status']?.toString();
              final healthy = health['status'].toString().toLowerCase() == 'healthy';
              final versionValue = version['version']?.toString();

              return Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        healthy ? Icons.check_circle : Icons.error_outline,
                        color: healthy ? Colors.green : Colors.orange,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        healthy ? 'Servicios saludables' : 'Servicios con problemas',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (serviceName != null || statusValue != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const SizedBox(width: 26),
                        Expanded(
                          child: Text(
                            'Servicio: ${serviceName ?? '--'} · Estado: ${statusValue ?? '--'}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (versionValue != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const SizedBox(width: 26),
                        Expanded(
                          child: Text(
                            'Versión: $versionValue',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
