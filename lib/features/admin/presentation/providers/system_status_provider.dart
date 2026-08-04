import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';

class SystemStatus {
  final Map<String, dynamic> system;
  final Map<String, dynamic> health;
  final Map<String, dynamic> version;

  const SystemStatus({
    this.system = const {},
    this.health = const {},
    this.version = const {},
  });

  bool get loaded => system.isNotEmpty || health.isNotEmpty || version.isNotEmpty;
}

/// Estado general de los servicios del backend (endpoints públicos del
/// dashboard general). Se muestra en la pantalla de administración.
final systemStatusProvider = FutureProvider<SystemStatus>((ref) async {
  final api = ref.watch(dashboardApiServiceProvider);

  Map<String, dynamic> system = const {};
  Map<String, dynamic> health = const {};
  Map<String, dynamic> version = const {};

  try {
    system = await api.getSystem();
  } catch (_) {}
  try {
    health = await api.getHealth();
  } catch (_) {}
  try {
    version = await api.getVersion();
  } catch (_) {}

  return SystemStatus(system: system, health: health, version: version);
});
