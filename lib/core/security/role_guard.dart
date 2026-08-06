import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/profile_provider.dart';

/// Defensa en profundidad para rutas restringidas por rol (p. ej. `/admin`).
///
/// `UserModel.role` se parseaba desde el backend pero nunca se leía en
/// ningún punto del código (A-01 del audit de seguridad): la pantalla de
/// administración era visible para cualquier usuario autenticado, sin
/// distinción de rol. `AdminSummaryScreen` hoy solo lee la BD local del
/// propio usuario, así que el impacto real estaba acotado -- pero la UI
/// prometía capacidades administrativas sin gobernarlas, y en cuanto se
/// conecte a un endpoint de organización se vuelve una fuga entre inquilinos.
///
/// Importante: esto es *solo* UX/defensa en profundidad. La autorización
/// real vive (y, según el sondeo del 6/08/2026, ya funciona) en el backend
/// -- un `RoleGuard` de cliente nunca debe tratarse como el control de
/// seguridad real.
///
/// ESTADO: implementado pero DELIBERADAMENTE NO conectado a `/admin` en
/// `app_router.dart` todavía. No está confirmado si esa pantalla es un
/// panel multi-tenant real (solo ADMIN/SUPERADMIN) o un resumen que
/// cualquier usuario final debe poder ver pese al nombre "Admin Summary" --
/// gatearla por rol sin esa confirmación podría romper la navegación
/// principal para la mayoría de los usuarios. Antes de envolver la ruta con
/// `RoleGuard(allowedRoles: {'ADMIN', 'SUPERADMIN'}, child: const
/// AdminSummaryScreen())`, confirmar con el equipo/producto qué usuarios
/// deben ver esa pantalla.
class RoleGuard extends ConsumerWidget {
  final Set<String> allowedRoles;
  final Widget child;

  const RoleGuard({super.key, required this.allowedRoles, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => _AccessDenied(
        message: 'No se pudo verificar tu rol de acceso.',
        onRetry: () => ref.invalidate(profileProvider),
      ),
      data: (user) {
        final role = (user.role ?? '').toUpperCase();
        final isAllowed = allowedRoles.any((r) => role.contains(r.toUpperCase()));
        if (!isAllowed) {
          return const _AccessDenied(
            message: 'Esta sección requiere permisos de administrador.',
          );
        }
        return child;
      },
    );
  }
}

class _AccessDenied extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _AccessDenied({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              if (onRetry != null)
                OutlinedButton(onPressed: onRetry, child: const Text('Reintentar'))
              else
                FilledButton(
                  onPressed: () => context.go('/dashboard'),
                  child: const Text('Volver al panel'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
