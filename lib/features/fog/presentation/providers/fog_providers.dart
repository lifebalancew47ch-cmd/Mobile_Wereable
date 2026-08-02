import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/fog_engine.dart';
import '../../../../services/notification_service.dart';
import '../../../settings/domain/alert_settings.dart';
import '../../../settings/presentation/providers/alert_settings_provider.dart';
import '../../../wearable/presentation/wearable_provider.dart';

/// Providers de inyección de dependencias para el FogEngine (Sección 13:
/// Integración Clean Arch). Compartidos entre la pantalla del wearable y la
/// pantalla de Fog Computing para que ambas observen el mismo motor.
/// `wearableCommunicationServiceProvider` se define en
/// features/wearable/presentation/wearable_provider.dart para que UI y motor
/// compartan una única instancia.
final notificationServiceProvider = Provider((ref) => NotificationService());

final fogEngineProvider = Provider((ref) {
  final wearable = ref.watch(wearableCommunicationServiceProvider);
  final notification = ref.watch(notificationServiceProvider);
  final engine = FogEngine(wearable, notification);

  // Aplica el intervalo de alerta configurado por el usuario si ya está cargado.
  final settings = ref.watch(alertSettingsProvider).value;
  if (settings != null) {
    engine.setAlertThreshold(settings.intervalMinutes);
  }

  final settingsSub = ref.listen<AsyncValue<AlertSettings>>(
    alertSettingsProvider,
    (previous, next) {
      final value = next.value;
      if (value != null) {
        engine.setAlertThreshold(value.intervalMinutes);
      }
    },
  );
  ref.onDispose(settingsSub.close);

  // El ciclo de vida del motor se ata al provider
  engine.start();
  ref.onDispose(() => engine.stop());
  return engine;
});
