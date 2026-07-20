import 'package:flutter/material.dart';

class FogScreen extends StatefulWidget {
  const FogScreen({super.key});

  @override
  State<FogScreen> createState() => _FogScreenState();
}

class _FogScreenState extends State<FogScreen> {
  bool _isEngineActive = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fog Computing Local', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Engine Status Card
            Card(
              color: _isEngineActive ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(
                      _isEngineActive ? Icons.online_prediction : Icons.offline_bolt_outlined,
                      size: 64,
                      color: _isEngineActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isEngineActive ? 'Algoritmo de Sedentarismo Activo' : 'Motor Inactivo',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _isEngineActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isEngineActive 
                        ? 'Analizando datos de sensores en tiempo real de manera local.' 
                        : 'El procesamiento en segundo plano está en pausa.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _isEngineActive 
                          ? colorScheme.onPrimaryContainer.withAlpha(200) 
                          : colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _isEngineActive = !_isEngineActive;
                        });
                      },
                      icon: Icon(_isEngineActive ? Icons.pause_circle_outline : Icons.play_circle_outline),
                      label: Text(_isEngineActive ? 'Pausar Procesamiento' : 'Reanudar Procesamiento'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Performance Metrics
            Text(
              'Estadísticas del Motor Local',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.speed, color: Colors.blue),
                    title: const Text('Frecuencia de Lectura'),
                    trailing: const Text('Cada 5 segundos', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.memory, color: Colors.purple),
                    title: const Text('Consumo de CPU (Simulado)'),
                    trailing: const Text('Muy Bajo (<1%)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.storage, color: Colors.teal),
                    title: const Text('Registros Procesados Hoy'),
                    trailing: const Text('14,400 registros', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
