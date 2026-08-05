import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:lifebalance/core/routes/app_router.dart';
import 'package:lifebalance/core/theme/app_theme.dart';
import 'package:lifebalance/core/theme/theme_provider.dart';
import 'package:lifebalance/features/fog/presentation/providers/fog_providers.dart';
import 'package:lifebalance/services/background_service.dart';
import 'package:lifebalance/services/watch_service.dart';
import 'package:lifebalance/data/datasources/secure_database_service.dart';
import 'package:lifebalance/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (Security - Sección 2 Cloud Prep)
  await dotenv.load(fileName: const String.fromEnvironment('ENV_FILE', defaultValue: '.env.development'));

  // Security Check: Root / Jailbreak detection
  bool jailbroken = await FlutterJailbreakDetection.jailbroken;
  if (jailbroken) {
    exit(0); // Cierre inmediato en dispositivos comprometidos
  }

  // Firebase (push remoto FCM). No-bloqueante: si no hay google-services.json
  // la app sigue funcionando con notificaciones locales únicamente.
  await _initializeFirebaseSafely();

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
  }

  Future<void> _requestPermissionsAndStartService() async {
    await Permission.notification.request();
    await Permission.ignoreBatteryOptimizations.request();
    await Permission.sensors.request();
    
    final watchService = WatchService();
    await watchService.requestPermissions();

    await BackgroundService.initialize();
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
