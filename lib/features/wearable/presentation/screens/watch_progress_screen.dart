import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/datasources/secure_database_service.dart';
import '../../../../features/fog/presentation/providers/fog_providers.dart';
import '../../../../models/fog_state.dart';

class WatchProgressScreen extends ConsumerStatefulWidget {
  const WatchProgressScreen({super.key});

  @override
  ConsumerState<WatchProgressScreen> createState() => _WatchProgressScreenState();
}

class _WatchProgressScreenState extends ConsumerState<WatchProgressScreen> {
  static const int _goalPauses = 5;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double padding = screenSize.width * 0.1;
    final engine = ref.watch(fogEngineProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFE9F1EC),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD1DCD6), width: 2),
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: StreamBuilder<FogState>(
            stream: engine.stateStream,
            builder: (context, snapshot) {
              final state = snapshot.data ?? FogState(
                status: ActivityStatus.active,
                inactiveMinutes: 0,
                lastMovement: DateTime.now(),
              );
              final score = (state.inactiveMinutes / 90.0).clamp(0.0, 1.0);

              return FutureBuilder<int>(
                future: SecureDatabaseService.instance.countActivitySessionsToday(),
                builder: (context, countSnapshot) {
                  final pauses = countSnapshot.data ?? 0;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'META DIARIA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF3E6F58),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: screenSize.width * 0.6,
                              height: screenSize.width * 0.6,
                              child: CircularProgressIndicator(
                                value: score,
                                strokeWidth: 10,
                                backgroundColor: const Color(0xFFE9F1EC),
                                color: const Color(0xFF3E6F58),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${state.inactiveMinutes}',
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3A34),
                                    height: 1,
                                  ),
                                ),
                                const Text(
                                  'MIN INACTIVO',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$pauses/$_goalPauses Pausas',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A34),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildDots(pauses),
                      const SizedBox(height: 4),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDots(int pauses) {
    final filled = pauses.clamp(0, 4);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: 4,
        height: 4,
        decoration: BoxDecoration(
          color: index < filled ? const Color(0xFF3E6F58) : Colors.grey.shade300,
          shape: BoxShape.circle,
        ),
      )),
    );
  }
}
