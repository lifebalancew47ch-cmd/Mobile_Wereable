import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lifebalance/core/routes/app_router.dart';
import 'package:lifebalance/core/theme/app_theme.dart';
import 'services/background_service.dart';
import 'services/database_service.dart';
import 'services/watch_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Base de Datos local
  await DatabaseService.instance.database;

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
    return MaterialApp.router(
      title: 'LifeBalance Watch',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Por defecto usa el del sistema
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
