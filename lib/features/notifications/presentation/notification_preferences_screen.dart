import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/notifications_provider.dart';
import '../domain/entities/alert_item.dart';

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

  /// Preferencias tal y como están guardadas, para saber si hay cambios
  /// pendientes y para no pisar la edición en curso al refrescar.
  NotificationPreferences? _saved;

  bool get _dirty {
    final saved = _saved;
    if (saved == null) return false;
    return saved.pushEnabled != _push ||
        saved.emailEnabled != _email ||
        saved.wearEnabled != _wear;
  }

  void _applyToForm(NotificationPreferences prefs) {
    _saved = prefs;
    _push = prefs.pushEnabled;
    _email = prefs.emailEnabled;
    _wear = prefs.wearEnabled;
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final desired = NotificationPreferences(
      pushEnabled: _push,
      emailEnabled: _email,
      wearEnabled: _wear,
    );
    final store = ref.read(notificationPreferencesStoreProvider);

    // 1) Persistencia local primero: la elección del usuario no se pierde
    //    aunque el backend no responda.
    await store.save(desired, pendingSync: true);

    String message;
    try {
      // 2) Sincronización con el backend.
      final api = ref.read(notificationsApiServiceProvider);
      final confirmed = await api.updatePreferences(
        pushEnabled: desired.pushEnabled,
        emailEnabled: desired.emailEnabled,
        wearEnabled: desired.wearEnabled,
      );
      await store.save(confirmed);
      if (mounted) setState(() => _applyToForm(confirmed));
      message = 'Preferencias guardadas';
    } catch (e) {
      // Queda marcado como pendiente de sincronizar; el valor local manda.
      if (mounted) setState(() => _saved = desired);
      message = 'Guardado en este dispositivo. No se pudo sincronizar: $e';
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    ref.invalidate(notificationPreferencesProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(notificationPreferencesProvider);

    // El provider ya hace fallback a la copia local, así que solo sincroniza
    // el formulario cuando no hay ediciones sin guardar.
    ref.listen<AsyncValue<NotificationPreferences>>(
      notificationPreferencesProvider,
      (previous, next) {
        final value = next.valueOrNull;
        if (value == null || _saving || _dirty) return;
        setState(() => _applyToForm(value));
      },
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Preferencias de notificación')),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
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
        ),
        data: (prefs) {
          // Primera vez que llegan datos (incluido el caso de valor ya
          // cacheado, donde ref.listen no dispara): inicializa el formulario.
          if (_saved == null) _applyToForm(prefs);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SwitchListTile(
                title: const Text('Notificaciones push'),
                subtitle: const Text('Alertas de sedentarismo y recordatorios'),
                value: _push,
                onChanged: _saving ? null : (v) => setState(() => _push = v),
              ),
              SwitchListTile(
                title: const Text('Notificaciones por email'),
                subtitle: const Text('Resúmenes y reportes a tu correo'),
                value: _email,
                onChanged: _saving ? null : (v) => setState(() => _email = v),
              ),
              SwitchListTile(
                title: const Text('Alertas en el wearable'),
                subtitle: const Text('Vibración y notificaciones en tu reloj'),
                value: _wear,
                onChanged: _saving ? null : (v) => setState(() => _wear = v),
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
                label: Text(_saving ? 'Guardando…' : 'Guardar preferencias'),
              ),
            ],
          );
        },
      ),
    );
  }
}
