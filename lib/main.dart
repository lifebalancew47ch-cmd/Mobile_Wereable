import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
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
import 'package:lifebalance/core/security/app_lock_preferences.dart';

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

  // A-02: Eliminar todos los logs de debugPrint en release
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // M-02 (audit de seguridad): migra valores de Secure Storage guardados con
  // el backend heredado de Android antes de que cualquier cosa (el motor de
  // encriptación de la BD, el login) intente leerlos con las nuevas opciones
  // (`encryptedSharedPreferences: true`). Debe ir antes de la inicialización
  // de la base de datos segura más abajo.
  await migrateLegacySecureStorageIfNeeded();

  // C-01 (fix 07/08/2026): flutter_dotenv eliminado. Las URLs y pins TLS
  // se pasan con --dart-define en tiempo de compilación (ver build_scripts/).
  // No hay nada que cargar en runtime.

  // M-07 (fix 07/08/2026): Root / Jailbreak detection.
  // Antes se llamaba exit(0) directamente, lo que no daba oportunidad al SO de
  // cerrar limpiamente las conexiones SQLCipher y podía dejar el WAL de SQLite
  // en estado inconsistente. Ahora se muestra una pantalla de bloqueo y el
  // usuario cierra la app de forma controlada con SystemNavigator.pop(), que
  // notifica al framework y le permite ejecutar su rutina de finalización.
  bool jailbroken = await FlutterJailbreakDetection.jailbroken;
  if (jailbroken) {
    runApp(const _SecurityBlockScreen());
    return; // No continuar con la inicialización normal.
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

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // A-03 (fix 07/08/2026): registrar observer para detectar cuando la app
    // va a background y resetear el biometric lock, de modo que al volver se
    // exija de nuevo la autenticación biométrica.
    WidgetsBinding.instance.addObserver(this);
    _requestPermissionsAndStartService();
    _listenToRemotePushes();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// A-03: Al pausar la app (ir a background), se revoca el flag de sesión
  /// desbloqueada. La próxima vez que el usuario abra la app, el router
  /// redirigirá a /auth-gate si el bloqueo biométrico está activo.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      appUnlockedThisSession = false;
    }
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

/// M-07 (fix 07/08/2026): pantalla de bloqueo de seguridad mostrada cuando
/// [FlutterJailbreakDetection] detecta un entorno comprometido (root/jailbreak).
///
/// Sustituye el `exit(0)` anterior, que terminaba el proceso abruptamente sin
/// dar oportunidad al framework de cerrar limpiamente las conexiones SQLCipher.
/// Ahora el usuario ve un aviso claro y cierra la app mediante
/// [SystemNavigator.pop], que notifica al sistema operativo para que ejecute
/// su rutina de finalización normal (flush WAL, liberar file locks).
class _SecurityBlockScreen extends StatelessWidget {
  const _SecurityBlockScreen();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.security,
                    size: 72,
                    color: Color(0xFFE94560),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Dispositivo no compatible',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'LifeBalance no puede ejecutarse en un dispositivo con '
                    'root o jailbreak porque no puede garantizar la '
                    'confidencialidad de tus datos de salud.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE94560),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => SystemNavigator.pop(),
                    child: const Text(
                      'Cerrar aplicación',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
