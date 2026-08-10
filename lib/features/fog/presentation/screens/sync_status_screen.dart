import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/security/token_service.dart';
import '../providers/fog_providers.dart';

class SyncStatusScreen extends ConsumerStatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  ConsumerState<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends ConsumerState<SyncStatusScreen> {
  bool _syncing = false;
  int _pending = 0;
  int _pendingMedical = 0;
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final sync = ref.read(offlineSyncControllerProvider);
    final pending = await sync.pendingCount();
    final medicalPending = await sync.pendingMedicalCount();
    if (!mounted) return;
    setState(() {
      _pending = pending;
      _pendingMedical = medicalPending;
      _lastSync = sync.lastSync;
    });
  }

  Future<void> _syncNow() async {
    if (_syncing) return;

    final tokenService = ref.read(tokenServiceProvider);
    final hasToken = await tokenService.hasValidToken();
    if (!hasToken) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Debes iniciar sesión para sincronizar tus datos con la nube.'),
          backgroundColor: Colors.orange.shade700,
          action: SnackBarAction(
            label: 'INICIAR SESIÓN',
            textColor: Colors.white,
            onPressed: () => context.go('/login'),
          ),
        ),
      );
      return;
    }

    setState(() => _syncing = true);
    final sync = ref.read(offlineSyncControllerProvider);
    final ok = await sync.syncNow();
    if (!mounted) return;
    setState(() => _syncing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Sincronización completada' : 'No se pudo sincronizar con la nube (verifica tu sesión o conexión)'),
        backgroundColor: ok ? const Color(0xFF3E6F58) : Colors.orange.shade700,
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sync = ref.watch(offlineSyncControllerProvider);
    final lastSync = _lastSync ?? sync.lastSync;

    return Scaffold(
      appBar: AppBar(title: const Text('Sincronización en la nube')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStatusBanner(theme),
            const SizedBox(height: 20),
            _buildStatsCard(theme, lastSync),
            const SizedBox(height: 20),
            _buildPendingCard(theme),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _syncing ? null : _syncNow,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3E6F58),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: _syncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(
                _syncing ? 'Sincronizando…' : 'Sincronizar ahora',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Se envían los datos de salud (signos vitales), sesiones de actividad, '
              'alertas y pausas activas a la nube. Normalmente se sincroniza cada 15 min '
              'y al recuperar la conexión.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF3E6F58),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_done_outlined, color: Colors.white, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sincronización Offline-First',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Los datos locales se suben a la nube automáticamente, sin pérdida si no hay conexión.',
                  style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(ThemeData theme, DateTime? lastSync) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.schedule, color: Color(0xFF3E6F58)),
            title: const Text('Última sincronización'),
            trailing: Text(
              lastSync == null ? 'Nunca' : _formatDate(lastSync),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.sync, color: Color(0xFF3E6F58)),
            title: const Text('Intervalo automático'),
            trailing: const Text('15 min', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.wifi, color: Color(0xFF3E6F58)),
            title: const Text('Sincronización por conexión'),
            subtitle: const Text('Se activa al recuperar Internet'),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Datos pendientes de subir',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.favorite, color: Colors.red),
            title: const Text('Cola de Ingestion (signos vitales, sesiones, alertas)'),
            trailing: Text(
              '$_pending',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.medical_information_outlined, color: Colors.blue),
            title: const Text('Lecturas médicas (Medical Service)'),
            subtitle: const Text('Se envían en lotes al sincronizar'),
            trailing: Text(
              '$_pendingMedical',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final d = date.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
