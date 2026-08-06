import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lifebalance/core/security/token_service.dart';
import 'package:lifebalance/core/security/auth_gate.dart';
import 'package:lifebalance/core/security/app_lock_preferences.dart';

// Screens
import 'package:lifebalance/features/auth/presentation/screens/login_screen.dart';
import 'package:lifebalance/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:lifebalance/features/authentication/presentation/splash_screen.dart';
import 'package:lifebalance/features/authentication/presentation/landing_screen.dart';
import 'package:lifebalance/features/dashboard/presentation/screens/executive_dashboard_screen.dart';
import 'package:lifebalance/features/admin/presentation/screens/admin_summary_screen.dart';
import 'package:lifebalance/features/analytics/presentation/screens/heatmap_screen.dart';
import 'package:lifebalance/features/analytics/presentation/screens/performance_analysis_screen.dart';
import 'package:lifebalance/features/settings/presentation/screens/alert_settings_screen.dart';
import 'package:lifebalance/features/settings/presentation/settings_screen.dart';
import 'package:lifebalance/features/support/presentation/screens/faq_screen.dart';
import 'package:lifebalance/features/support/presentation/screens/video_explanation_screen.dart';
import 'package:lifebalance/features/profile/presentation/profile_screen.dart';
import 'package:lifebalance/features/profile/presentation/screens/biometric_profile_screen.dart';
import 'package:lifebalance/features/profile/presentation/activity_history_screen.dart';
import 'package:lifebalance/features/gamification/presentation/gamification_screen.dart';
import 'package:lifebalance/features/fog/presentation/fog_screen.dart';
import 'package:lifebalance/features/fog/presentation/screens/sync_status_screen.dart';
import 'package:lifebalance/features/wearable/presentation/screens/device_scanning_screen.dart';
import 'package:lifebalance/features/wearable/presentation/screens/device_management_screen.dart';
import 'package:lifebalance/features/notifications/presentation/notifications_screen.dart';
import 'package:lifebalance/features/sedentary/presentation/screens/sedentary_screen.dart';
import 'package:lifebalance/features/ml/presentation/screens/ml_prediction_screen.dart';
import 'package:lifebalance/features/medical/presentation/screens/medical_screen.dart';
import 'package:lifebalance/features/dashboard/presentation/screens/individual_dashboard_screen.dart';

// Navigation Shell
import 'package:lifebalance/shared/widgets/main_navigation_shell.dart';

// Global keys for navigation
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _dashboardNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'dashboard');
final GlobalKey<NavigatorState> _wearableNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'wearable');
final GlobalKey<NavigatorState> _profileNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  refreshListenable: sessionChangeNotifier,
  redirect: (BuildContext context, GoRouterState state) async {
    // Rutas públicas (auth) no requieren sesión.
    const publicRoutes = {'/splash', '/landing', '/login', '/auth/forgot-password'};
    if (publicRoutes.contains(state.matchedLocation)) return null;

    final tokenService = ProviderScope.containerOf(context).read(tokenServiceProvider);
    final hasValidSession = await tokenService.hasValidToken();
    if (!hasValidSession) return '/login';

    // AuthGate (bloqueo biométrico al reabrir la app): existía completo pero
    // nunca se instanciaba en ningún flujo de navegación real (M-04 del
    // audit). Si el usuario lo activó desde Ajustes y aún no desbloqueó esta
    // sesión de proceso, cualquier ruta protegida redirige a /auth-gate.
    if (state.matchedLocation == '/auth-gate') return null;
    if (!appUnlockedThisSession) {
      final lockEnabled = await AppLockPreferences.isBiometricLockEnabled();
      if (lockEnabled) return '/auth-gate';
    }

    return null;
  },
  routes: <RouteBase>[
    // Authentication Routes (Outside the shell)
    GoRoute(
      path: '/splash',
      builder: (BuildContext context, GoRouterState state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/landing',
      builder: (BuildContext context, GoRouterState state) => const LandingScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (BuildContext context, GoRouterState state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/auth/forgot-password',
      builder: (BuildContext context, GoRouterState state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/auth-gate',
      builder: (BuildContext context, GoRouterState state) => const AuthGate(),
    ),
    GoRoute(
      path: '/fog',
      builder: (BuildContext context, GoRouterState state) => const FogScreen(),
      routes: [
        GoRoute(
          path: 'sync',
          builder: (BuildContext context, GoRouterState state) => const SyncStatusScreen(),
        ),
      ],
    ),

    // Stateful Shell Route for Bottom Navigation Tabs
    StatefulShellRoute.indexedStack(
      builder: (BuildContext context, GoRouterState state, StatefulNavigationShell navigationShell) {
        return MainNavigationShell(navigationShell: navigationShell);
      },
      branches: <StatefulShellBranch>[
        // Tab 1: Dashboard
        StatefulShellBranch(
          navigatorKey: _dashboardNavigatorKey,
          routes: <RouteBase>[
            GoRoute(
              path: '/dashboard',
              builder: (BuildContext context, GoRouterState state) => const ExecutiveDashboardScreen(),
              routes: <RouteBase>[
                GoRoute(
                  path: 'notifications',
                  parentNavigatorKey: _rootNavigatorKey, // Opens on top of bottom navigation bar
                  builder: (BuildContext context, GoRouterState state) => const NotificationsScreen(),
                ),
                GoRoute(
                  path: 'individual',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (BuildContext context, GoRouterState state) => const IndividualDashboardScreen(),
                ),
              ],
            ),
          ],
        ),

        // Tab 2: Analytics / Performance
        StatefulShellBranch(
          navigatorKey: _wearableNavigatorKey,
          routes: <RouteBase>[
            GoRoute(
              path: '/analytics',
              builder: (BuildContext context, GoRouterState state) => const PerformanceAnalysisScreen(),
              routes: [
                GoRoute(
                  path: 'heatmap',
                  builder: (context, state) => const HeatmapScreen(),
                ),
                GoRoute(
                  path: 'sedentary',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const SedentaryScreen(),
                ),
                GoRoute(
                  path: 'prediction',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const MlPredictionScreen(),
                ),
                GoRoute(
                  path: 'medical',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const MedicalScreen(),
                ),
              ],
            ),
          ],
        ),

        // Tab 3: Admin / Summary
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/admin',
              builder: (BuildContext context, GoRouterState state) => const AdminSummaryScreen(),
            ),
          ],
        ),

        // Tab 4: Support / FAQ & Video
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/support',
              builder: (BuildContext context, GoRouterState state) => const FAQScreen(),
              routes: [
                GoRoute(
                  path: 'video',
                  builder: (context, state) => const VideoExplanationScreen(),
                ),
              ],
            ),
          ],
        ),

        // Tab 5: Profile
        StatefulShellBranch(
          navigatorKey: _profileNavigatorKey,
          routes: <RouteBase>[
            GoRoute(
              path: '/profile',
              builder: (BuildContext context, GoRouterState state) => const ProfileScreen(),
              routes: <RouteBase>[
                GoRoute(
                  path: 'biometric',
                  builder: (context, state) => const BiometricProfileScreen(),
                ),
                GoRoute(
                  path: 'gamification',
                  builder: (context, state) => const GamificationScreen(),
                ),
                GoRoute(
                  path: 'settings',
                  parentNavigatorKey: _rootNavigatorKey, // Opens on top of bottom navigation bar
                  builder: (BuildContext context, GoRouterState state) => const SettingsScreen(),
                  routes: <RouteBase>[
                    GoRoute(
                      path: 'alerts',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (BuildContext context, GoRouterState state) =>
                          const AlertSettingsScreen(),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'history',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (BuildContext context, GoRouterState state) => const ActivityHistoryScreen(),
                ),
                GoRoute(
                  path: 'wearable-scan',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (BuildContext context, GoRouterState state) => const DeviceScanningScreen(),
                ),
                GoRoute(
                  path: 'wearable-manage',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (BuildContext context, GoRouterState state) => const DeviceManagementScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
