import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/notifications_provider.dart';

class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  bool _push = true;
  bool _email = true;
  bool _wear = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await ref.read(notificationPreferencesProvider.future);
    if (!mounted) return;
    setState(() {
      _push = prefs.pushEnabled;
      _email = prefs.emailEnabled;
      _wear = prefs.wearEnabled;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(notificationsApiServiceProvider);
      await api.updatePreferences(
        pushEnabled: _push,
        emailEnabled: _email,
        wearEnabled: _wear,
      );
      ref.invalidate(notificationPreferencesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferencias guardadas')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Preferencias de notificación')),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('No se pudieron cargar las preferencias.\n$e',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(notificationPreferencesProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (_) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              title: const Text('Notificaciones push'),
              subtitle: const Text('Alertas de sedentarismo y recordatorios'),
              value: _push,
              onChanged: (v) => setState(() => _push = v),
            ),
            SwitchListTile(
              title: const Text('Notificaciones por email'),
              subtitle: const Text('Resúmenes y reportes a tu correo'),
              value: _email,
              onChanged: (v) => setState(() => _email = v),
            ),
            SwitchListTile(
              title: const Text('Alertas en el wearable'),
              subtitle: const Text('Vibración y notificaciones en tu reloj'),
              value: _wear,
              onChanged: (v) => setState(() => _wear = v),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Guardar preferencias'),
            ),
          ],
        ),
      ),
    );
  }
}
