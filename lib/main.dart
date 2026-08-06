import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'package:lifebalance/core/routes/app_router.dart';
import 'package:lifebalance/core/theme/app_theme.dart';
import 'package:lifebalance/core/theme/theme_provider.dart';
import 'package:lifebalance/features/fog/presentation/providers/fog_providers.dart';
import 'package:lifebalance/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:lifebalance/services/background_service.dart';
import 'package:lifebalance/services/watch_service.dart';
import 'package:lifebalance/data/datasources/secure_database_service.dart';
import 'package:lifebalance/services/notification_service.dart';
import 'package:lifebalance/core/security/secure_storage.dart';

/// Handler de mensajes FCM en background/terminado. Debe ser una función
/// top-level (o estática) anotada `vm:entry-point`: FCM la ejecuta en un
/// isolate aparte que no comparte estado con la app, por eso reinicializa
/// Firebase por su cuenta. Hoy solo loguea — Android ya muestra la
/// notificación del sistema automáticamente para mensajes tipo `notification`
/// en background, así que no hace falta duplicarla aquí.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  debugPrint('[FCM] Push recibido en background: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // M-02 (audit de seguridad): migra valores de Secure Storage guardados con
  // el backend heredado de Android antes de que cualquier cosa (el motor de
  // encriptación de la BD, el login) intente leerlos con las nuevas opciones
  // (`encryptedSharedPreferences: true`). Debe ir antes de la inicialización
  // de la base de datos segura más abajo.
  await migrateLegacySecureStorageIfNeeded();

  // Load environment variables (Security - Sección 2 Cloud Prep)
  try {
    await dotenv.load(fileName: const String.fromEnvironment('ENV_FILE', defaultValue: '.env.development'));
  } catch (e) {
    debugPrint('Aviso: No se pudo cargar el archivo env o está vacío ($e). Usando configuración por defecto.');
  }

  // Security Check: Root / Jailbreak detection
  bool jailbroken = await FlutterJailbreakDetection.jailbroken;
  if (jailbroken) {
    exit(0); // Cierre inmediato en dispositivos comprometidos
  }

  // Firebase (push remoto FCM). No-bloqueante: si no hay google-services.json
  // la app sigue funcionando con notificaciones locales únicamente.
  await _initializeFirebaseSafely();
  if (Firebase.apps.isNotEmpty) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    // Crashlytics estaba declarado en pubspec.yaml pero nunca conectado
    // (M-04 del audit de seguridad): ningún crash ni excepción no capturada
    // se reportaba. Esto es lo que hace visibles en telemetría los fallos
    // silenciosos de escritura a SQLite que se acaban de corregir en
    // FogEngine -- sin esto, seguirían siendo invisibles aunque ya no se
    // pierdan datos.
    await _initializeCrashlyticsSafely();
  }

  // Inicializar Base de Datos Segura
  await SecureDatabaseService.instance.database;
  
  // Inicializar Notificaciones (requerido para recordatorios)
  await NotificationService().init();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

/// Inicializa Firebase si el proyecto está configurado. Nunca lanza: ante
/// cualquier fallo (falta google-services.json, dispositivo sin Google Play
/// Services) se degrada a un no-op seguro.
Future<void> _initializeFirebaseSafely() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('Firebase no configurado: push remoto desactivado.');
  }
}

/// Conecta `FlutterError.onError` y `PlatformDispatcher.onError` a
/// Crashlytics para que los errores no capturados (Flutter y Dart puro,
/// incluidos los de isolates de background) queden registrados. Solo se
/// llama cuando Firebase ya se inicializó correctamente; nunca lanza.
Future<void> _initializeCrashlyticsSafely() async {
  try {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (e) {
    debugPrint('Crashlytics no disponible: $e');
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    _requestPermissionsAndStartService();
    _listenToRemotePushes();
  }

  Future<void> _requestPermissionsAndStartService() async {
    await Permission.notification.request();
    await Permission.ignoreBatteryOptimizations.request();
    await Permission.sensors.request();

    final watchService = WatchService();
    await watchService.requestPermissions();

    await BackgroundService.initialize();
  }

  /// Con esto un push mandado desde el backend (gamificación, reportes, una
  /// alerta médica/ML, un broadcast de organización, etc. — cualquier cosa
  /// que llegue a `POST /notifications` o `/push/send`) realmente se nota:
  /// - Con la app abierta, Android/iOS NO muestran nada por su cuenta para
  ///   mensajes en foreground, así que sin este listener el push llegaba y
  ///   desaparecía en silencio.
  /// - Al llegar, además de mostrar el banner local, se invalida
  ///   `notificationsProvider`/`alertsProvider` para que el Centro de
  ///   notificaciones ya tenga el dato fresco si el usuario lo abre.
  /// No-op seguro si Firebase no está configurado.
  void _listenToRemotePushes() {
    if (Firebase.apps.isEmpty) return;
    try {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        final String title = notification?.title ?? message.data['title']?.toString() ?? '';
        final String body = notification?.body ?? message.data['body']?.toString() ?? '';
        if (title.isEmpty && body.isEmpty) return;

        NotificationService().showRemoteNotification(title: title, body: body);
        ref.invalidate(notificationsProvider);
        ref.invalidate(alertsProvider);
      });

      // El usuario tocó el push (app en background) y lo abrió: refresca el
      // Centro de notificaciones para que no muestre datos viejos.
      FirebaseMessaging.onMessageOpenedApp.listen((_) {
        ref.invalidate(notificationsProvider);
        ref.invalidate(alertsProvider);
      });
    } catch (e) {
      debugPrint('[FCM] No se pudo suscribir a mensajes remotos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    // El FogEngine y la sincronización se arrancan de forma eager en el
    // aislado de la UI (donde el EventChannel del wearable SÍ existe y entrega
    // datos). Antes solo corrían si la pantalla del Fog estaba abierta, por lo
    // que estando quieto en cualquier otra pantalla no se detectaba nada.
    ref.watch(fogEngineProvider);
    ref.watch(offlineSyncControllerProvider);
    // Registro FCM: fuerza la ejecución del provider lazy para que el
    // dispositivo quede registrado para push notifications y el token se
    // renueve automáticamente ante cambios de FCM token.
    ref.watch(deviceRegistrationServiceProvider);

    return MaterialApp.router(
      title: 'LifeBalance Watch',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
