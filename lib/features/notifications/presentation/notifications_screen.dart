import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final titles = ['¡Meta alcanzada!', 'Hora de moverse', 'Sincronización completa'];
          final bodies = [
            'Has completado tus 10,000 pasos de hoy.',
            'Llevas mucho tiempo inactivo. ¡Levántate!',
            'Tus datos han sido actualizados con éxito.'
          ];
          final icons = [Icons.emoji_events, Icons.directions_walk, Icons.sync];

          return Card(
            child: ListTile(
              leading: Icon(icons[index], color: Theme.of(context).colorScheme.primary),
              title: Text(titles[index]),
              subtitle: Text(bodies[index]),
              trailing: const Text('Ahora'),
            ),
          );
        },
      ),
    );
  }
}
