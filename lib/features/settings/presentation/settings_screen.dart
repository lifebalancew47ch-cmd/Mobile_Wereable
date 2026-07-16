import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: ListView(
        children: [
          const _SettingsHeader(title: 'Notificaciones'),
          SwitchListTile(
            title: const Text('Notificaciones push'),
            subtitle: const Text('Recibir alertas de actividad'),
            value: true,
            onChanged: (val) {},
          ),
          SwitchListTile(
            title: const Text('Alertas de sedentarismo'),
            value: true,
            onChanged: (val) {},
          ),
          const Divider(),
          const _SettingsHeader(title: 'Cuenta'),
          ListTile(
            title: const Text('Cambiar contraseña'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            title: const Text('Privacidad'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(),
          const _SettingsHeader(title: 'Aplicación'),
          ListTile(
            title: const Text('Versión'),
            subtitle: const Text('1.0.0'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  final String title;
  const _SettingsHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
