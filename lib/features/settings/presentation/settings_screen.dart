import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/presentation/providers/login_provider.dart';
import '../../../services/notification_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _kPushEnabled = 'settings_push_enabled';
  static const _kSedentaryEnabled = 'settings_sedentary_alerts_enabled';

  final NotificationService _notifications = NotificationService();

  bool _pushEnabled = true;
  bool _sedentaryEnabled = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _pushEnabled = prefs.getBool(_kPushEnabled) ?? true;
      _sedentaryEnabled = prefs.getBool(_kSedentaryEnabled) ?? true;
      _loading = false;
    });
  }

  Future<void> _setPushEnabled(bool value) async {
    setState(() => _pushEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPushEnabled, value);
    if (value) {
      await _notifications.requestPermissions();
    }
  }

  Future<void> _setSedentaryEnabled(bool value) async {
    setState(() => _sedentaryEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSedentaryEnabled, value);
    if (value) {
      await _notifications.requestPermissions();
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar contraseña'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña actual',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Requerida' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nueva contraseña',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.length < 8)
                    ? 'Mínimo 8 caracteres'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmar nueva contraseña',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v != newCtrl.text) ? 'No coincide' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result != true || !mounted) return;

    try {
      final api = ref.read(authApiServiceProvider);
      await api.changePassword(
        currentPassword: currentCtrl.text,
        newPassword: newCtrl.text,
        confirmNewPassword: confirmCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const _SettingsHeader(title: 'Notificaciones'),
                SwitchListTile(
                  title: const Text('Notificaciones push'),
                  subtitle: const Text('Recibir alertas de actividad'),
                  value: _pushEnabled,
                  onChanged: _setPushEnabled,
                ),
                SwitchListTile(
                  title: const Text('Alertas de sedentarismo'),
                  subtitle: const Text(
                      'Notificación al superar tu tiempo inactivo configurado'),
                  value: _sedentaryEnabled,
                  onChanged: _setSedentaryEnabled,
                ),
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('Configuración de alertas'),
                  subtitle: const Text(
                      'Intervalo, horario y días de operación'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/profile/settings/alerts'),
                ),
                const Divider(),
                const _SettingsHeader(title: 'Cuenta'),
                ListTile(
                  title: const Text('Cambiar contraseña'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showChangePasswordDialog,
                ),
                ListTile(
                  title: const Text('Cerrar sesión'),
                  subtitle: const Text('Salir de esta cuenta'),
                  leading: const Icon(Icons.logout, color: Colors.red),
                  onTap: () async {
                    await ref.read(loginProvider.notifier).logout();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
                ),
                const Divider(),
                const _SettingsHeader(title: 'Aplicación'),
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: const Text('Sincronización en la nube'),
                  subtitle: const Text('Estado y sincronización de datos'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/fog/sync'),
                ),
                ListTile(
                  leading: const Icon(Icons.memory_outlined),
                  title: const Text('Estado del Fog'),
                  subtitle: const Text('Motor de análisis local'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/fog'),
                ),
                ListTile(
                  title: const Text('Versión'),
                  subtitle: Text(
                    '${const String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0')} '
                    '(${const String.fromEnvironment('APP_BUILD', defaultValue: '1')})',
                  ),
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
