import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WearableScreen extends StatelessWidget {
  const WearableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Wearable'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.watch_rounded, size: 80, color: colorScheme.onPrimaryContainer),
              ),
              const SizedBox(height: 32),
              const Text(
                'Sin dispositivo vinculado',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Vincula tu reloj para ver tus métricas en tiempo real',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => context.push('/wearable/bluetooth'),
                icon: const Icon(Icons.bluetooth),
                label: const Text('Buscar dispositivo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
