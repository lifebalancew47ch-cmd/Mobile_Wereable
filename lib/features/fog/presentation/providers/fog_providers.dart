import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/fog_engine.dart';
import '../../../../services/notification_service.dart';
import '../../../../services/wearable_communication_service.dart';

/// Providers de inyección de dependencias para el FogEngine (Sección 13:
/// Integración Clean Arch). Compartidos entre la pantalla del wearable y la
/// pantalla de Fog Computing para que ambas observen el mismo motor.
final wearableCommunicationServiceProvider =
    Provider((ref) => WearableCommunicationService());

final notificationServiceProvider = Provider((ref) => NotificationService());

final fogEngineProvider = Provider((ref) {
  final wearable = ref.watch(wearableCommunicationServiceProvider);
  final notification = ref.watch(notificationServiceProvider);
  final engine = FogEngine(wearable, notification);
  // El ciclo de vida del motor se ata al provider
  engine.start();
  ref.onDispose(() => engine.stop());
  return engine;
});
