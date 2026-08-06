import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/fog_engine.dart';
import '../../../../core/network/api_client.dart';
import '../../../../models/fog_state.dart';
import '../../../../services/notification_service.dart';
import '../../../../services/offline_sync_service.dart';
import '../../../../services/connectivity_monitor.dart';
import '../../../../services/device_registration_service.dart';
import '../../../../services/device_identity_service.dart';
import '../../../../services/location_service.dart';
import '../../../../features/ingestion/data/ingestion_api_service.dart';
import '../../../../features/gamification/data/gamification_api_service.dart';
import '../../../../features/medical/data/medical_api_service.dart';
import '../../../../features/sedentary/data/sedentary_api_service.dart';
import '../../../../features/notifications/data/datasources/notifications_api_service.dart';
import '../../../settings/domain/alert_settings.dart';
import '../../../settings/presentation/providers/alert_settings_provider.dart';
import '../../../wearable/presentation/wearable_provider.dart';
import '../../../auth/presentation/providers/profile_provider.dart';

/// Providers de inyección de dependencias para el FogEngine (Sección 13:
/// Integración Clean Arch). Compartidos entre la pantalla del wearable y la
/// pantalla de Fog Computing para que ambas observen el mismo motor.
/// `wearableCommunicationServiceProvider` se define en
/// features/wearable/presentation/wearable_provider.dart para que UI y motor
/// compartan una única instancia.
final notificationServiceProvider = Provider((ref) => NotificationService());

/// Servicios cloud (contratos reales de `backapi-main`) expuestos a la UI.
final ingestionApiServiceProvider = Provider<IngestionApiService>((ref) {
  return IngestionApiService(ref.watch(ingestionApiClientProvider));
});

final gamificationApiServiceProvider = Provider<GamificationApiService>((ref) {
  return GamificationApiService(ref.watch(gamificationApiClientProvider));
});

final notificationsApiServiceProvider = Provider<NotificationsApiService>((ref) {
  return NotificationsApiService(ref.watch(notificationsApiClientProvider));
});

final medicalApiServiceProvider = Provider<MedicalApiService>((ref) {
  return MedicalApiService(ref.watch(medicalApiClientProvider));
});

final sedentaryApiServiceProvider = Provider<SedentaryApiService>((ref) {
  return SedentaryApiService(ref.watch(sedentaryApiClientProvider));
});

/// Sincronización Offline-First (colas locales -> Ingestion Service).
final offlineSyncServiceProvider = Provider<OfflineSyncService>((ref) {
  return OfflineSyncService(
    ingestionApi: ref.watch(ingestionApiServiceProvider),
    gamificationApi: ref.watch(gamificationApiServiceProvider),
    medicalApi: ref.watch(medicalApiServiceProvider),
    sedentaryApi: ref.watch(sedentaryApiServiceProvider),
  );
});

/// Registro del dispositivo para push remoto (FCM), no-bloqueante.
final deviceRegistrationServiceProvider = Provider<DeviceRegistrationService>((ref) {
  final service = DeviceRegistrationService(
    notificationsApi: ref.watch(notificationsApiServiceProvider),
  );
  service.registerDevice();
  service.registerDeviceOnTokenRefresh();
  return service;
});

final fogEngineProvider = Provider((ref) {
  final wearable = ref.watch(wearableCommunicationServiceProvider);
  final notification = ref.watch(notificationServiceProvider);
  final engine = FogEngine(wearable, notification);

  // Alimenta el Filtro Clínico con FC/HRV del wearable (si están presentes).
  final clinicalSub = wearable.sensorStream.listen((sample) {
    engine.feedClinicalSample(
      heartRate: sample.heartRate > 0 ? sample.heartRate : null,
      hrv: sample.hrv > 0 ? sample.hrv : null,
    );
  });
  ref.onDispose(clinicalSub.cancel);

  // GPS bajo demanda: en una alerta de sedentarismo se captura la ubicación
  // una vez y se registra en el Ingestion Service (asíncrono, no bloqueante).
  final alertSub = engine.stateStream.listen((state) {
    if (state.status != ActivityStatus.alertTriggered) return;
    unawaited(_captureGpsAndSend(ref));
    // Nota: `state.inactiveMinutes` ya viene en 0 aquí (FogEngine resetea el
    // contador antes de emitir el evento), por eso se usa el umbral
    // configurado, que es el valor real que disparó la alerta.
    unawaited(_sendRealAlert(ref, engine.alertThresholdMinutes));
  });
  ref.onDispose(alertSub.cancel);

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

/// Arranca la sincronización periódica al crear el primer listener (UI).
final offlineSyncControllerProvider = Provider((ref) {
  final sync = ref.watch(offlineSyncServiceProvider);
  final connectivity = ConnectivityMonitor();
  final stream = connectivity.onlineStream;
  sync.startPeriodicSync(
    interval: const Duration(minutes: 5),
    connectivityStream: stream,
  );
  ref.onDispose(() {
    sync.stop();
    connectivity.dispose();
  });
  return sync;
});

/// Crea la alerta de sedentarismo en el Notifications & Alerts Service
/// (POST /alerts), además del registro local que ya existía. Así queda
/// visible en la pestaña Alertas sincronizada entre dispositivos y en el
/// dashboard web/admin, no solo en el SQLite del teléfono. Nunca lanza: si
/// falla (sin red, backend caído) la alerta local sigue funcionando igual.
Future<void> _sendRealAlert(Ref ref, int minutes) async {
  try {
    final userId = ref.read(profileProvider).value?.id;
    if (userId == null || userId.isEmpty) return;
    await ref.read(notificationsApiServiceProvider).createAlert(
          userId: userId,
          title: 'Alerta de sedentarismo',
          body: 'Llevas $minutes minutos inactivo. Te sugerimos una pausa activa de 2 minutos.',
          source: 'FogEngine',
        );
  } catch (e) {
    debugPrint('[FogEngine] No se pudo crear la alerta en la nube (queda solo local): $e');
  }
}

/// Captura GPS bajo demanda (solo en alertas de sedentarismo) y registra el
/// evento en el Ingestion Service. Nunca lanza: los fallos se loguean.
Future<void> _captureGpsAndSend(Ref ref) async {
  final gps = await LocationService().capture();
  if (gps == null) return;
  try {
    await ref.read(ingestionApiServiceProvider).postEvent(
          deviceId: await DeviceIdentityService().getDeviceId(),
          eventType: 'GPS_COORDINATE',
          source: 'Mobile',
          occurredAtUtc: gps.capturedAt,
          payload: {'latitude': gps.latitude, 'longitude': gps.longitude},
          idempotencyKey: 'gps-${gps.capturedAt.millisecondsSinceEpoch}',
        );
  } catch (e) {
    debugPrint('[GPS] Envío diferido (cola local): $e');
  }
}
