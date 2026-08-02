import 'package:flutter/material.dart';
import '../../../data/datasources/secure_database_service.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  final SecureDatabaseService _db = SecureDatabaseService.instance;
  bool _loading = true;
  List<Map<String, Object?>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessions = await _db.getAllActivitySessions(limit: 200);
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de actividad'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Sin sesiones registradas',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Conecta tu wearable y muévete para registrar tu actividad.',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _sessions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      final type = (session['type'] as String?) ?? 'idle';
                      final duration = (session['duration_minutes'] as int?) ?? 0;
                      final startTime =
                          DateTime.tryParse((session['start_time'] as String?) ?? '');

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _typeColor(type).withAlpha(40),
                          child: Icon(_typeIcon(type), color: _typeColor(type)),
                        ),
                        title: Text(
                          _typeLabel(type),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(_formatDate(startTime)),
                        trailing: Text(
                          '$duration min',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'active':
        return Icons.directions_run;
      case 'alert':
        return Icons.warning_amber;
      default:
        return Icons.airline_seat_recline_normal;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'active':
        return Colors.green;
      case 'alert':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'active':
        return 'Actividad';
      case 'alert':
        return 'Alerta de sedentarismo';
      default:
        return 'Inactividad';
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '--';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '${date.year}-$month-$day $hh:$mm';
  }
}
