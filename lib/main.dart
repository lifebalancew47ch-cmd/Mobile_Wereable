import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/background_service.dart';
import 'services/database_service.dart';
import 'services/watch_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Base de Datos local
  await DatabaseService.instance.database;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeBalance Watch',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Fog Layer - Sedentarismo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isServiceRunning = false;

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
    
    setState(() {
      _isServiceRunning = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Estado del Fog Layer:',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            Text(
              _isServiceRunning ? 'Activo (Monitoreando en segundo plano)' : 'Iniciando...',
              style: TextStyle(
                fontSize: 16,
                color: _isServiceRunning ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold
              ),
            ),
          ],
        ),
      ),
    );
  }
}
