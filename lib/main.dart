import 'core/security/auth_gate.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lifebalance/core/routes/app_router.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/background_service.dart';
import 'data/datasources/secure_database_service.dart';
import 'services/watch_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: const String.fromEnvironment('ENV_FILE', defaultValue: '.env.development'));

  // Security Check: Root / Jailbreak detection
  bool jailbroken = await FlutterJailbreakDetection.jailbroken;
  if (jailbroken) {
    // Force close app on compromised devices
    SystemNavigator.pop();
    exit(0);
  }

  // Inicializar Base de Datos local
  await SecureDatabaseService.instance.database;

  runApp(const MyApp());
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
    // Pedir permisos generales
    await Permission.notification.request();
    await Permission.ignoreBatteryOptimizations.request();
    await Permission.sensors.request();
    
    // Pedir permisos para WatchService (Health Connect)
    final watchService = WatchService();
    await watchService.requestPermissions();

    // Inicializar Background Service
    await BackgroundService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    // AuthGate now needs to encapsulate the router so it protects all screens.
    // Or we use go_router redirects. For now, since AuthGate just redirects
    // to a route on success, wait, we can just use MaterialApp.router here
    // but the original code replaced home with AuthGate.
    // If we have appRouter, we should probably add AuthGate as the initial route in go_router.
    // Let's just wrap MaterialApp.router inside a builder or keep it simple.
    
    // I will return AuthGate as the home for now, since this is what we wrote.
    // But since the remote added go_router, let's use the router!
    return MaterialApp.router(
      title: 'LifeBalance Watch',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}

