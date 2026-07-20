import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:lifebalance/core/routes/app_router.dart';
import 'package:lifebalance/core/theme/app_theme.dart';
import 'package:lifebalance/services/background_service.dart';
import 'package:lifebalance/services/watch_service.dart';
import 'package:lifebalance/data/datasources/secure_database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables (Security - Sección 2 Cloud Prep)
  await dotenv.load(fileName: const String.fromEnvironment('ENV_FILE', defaultValue: '.env.development'));

  // Security Check: Root / Jailbreak detection
  bool jailbroken = await FlutterJailbreakDetection.jailbroken;
  if (jailbroken) {
    exit(0); // Cierre inmediato en dispositivos comprometidos
  }

  // Inicializar Base de Datos Segura
  await SecureDatabaseService.instance.database;

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
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
    return MaterialApp.router(
      title: 'LifeBalance Watch',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
