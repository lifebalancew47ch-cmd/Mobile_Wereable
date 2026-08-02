import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/fog/presentation/providers/fog_providers.dart';
import '../../../../models/fog_state.dart';
import '../../../../services/notification_service.dart';

class WatchAlertScreen extends ConsumerStatefulWidget {
  const WatchAlertScreen({super.key});

  @override
  ConsumerState<WatchAlertScreen> createState() => _WatchAlertScreenState();
}

class _WatchAlertScreenState extends ConsumerState<WatchAlertScreen> {
  final NotificationService _notifications = NotificationService();
  static const int _reminderId = 1002;

  Future<void> _takeBreak() async {
    final engine = ref.read(fogEngineProvider);
    engine.resume();
    await _notifications.cancelReminder(id: _reminderId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('¡Pausa activa registrada!'), duration: Duration(seconds: 2)),
    );
  }

  Future<void> _snooze() async {
    final now = DateTime.now().add(const Duration(minutes: 10));
    await _notifications.scheduleReminder(
      hour: now.hour,
      minute: now.minute,
      id: _reminderId,
      title: '¡Hora de moverse!',
      body: 'Recordatorio: realiza una pausa activa de 2 minutos.',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recordatorio en 10 min'), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final engine = ref.watch(fogEngineProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          width: screenSize.width * 0.95,
          height: screenSize.height * 0.95,
          decoration: const BoxDecoration(
            color: Color(0xFFE9F1EC),
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: StreamBuilder<FogState>(
                  stream: engine.stateStream,
                  builder: (context, snapshot) {
                    final state = snapshot.data ?? FogState(
                      status: ActivityStatus.active,
                      inactiveMinutes: 0,
                      lastMovement: DateTime.now(),
                    );
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 10),
                        const Text(
                          '¡Es hora de\nmoverse!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A34),
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Llevas ${state.inactiveMinutes} min sentado',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: screenSize.width * 0.6,
                          height: 40,
                          child: ElevatedButton(
                            onPressed: _takeBreak,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3E6F58),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: const StadiumBorder(),
                            ),
                            child: const Text(
                              'Hacer Pausa',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _snooze,
                          child: const Text(
                            'Posponer 10 min',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Positioned(
                top: 15,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD68C5E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'MONITORING',
                    style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
