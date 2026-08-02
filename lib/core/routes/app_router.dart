import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Screens
import 'package:lifebalance/features/auth/presentation/screens/login_screen.dart';
import 'package:lifebalance/features/auth/presentation/screens/register_screen.dart';
import 'package:lifebalance/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:lifebalance/features/authentication/presentation/splash_screen.dart';
import 'package:lifebalance/features/dashboard/presentation/screens/executive_dashboard_screen.dart';
import 'package:lifebalance/features/admin/presentation/screens/admin_summary_screen.dart';
import 'package:lifebalance/features/analytics/presentation/screens/heatmap_screen.dart';
import 'package:lifebalance/features/analytics/presentation/screens/performance_analysis_screen.dart';
import 'package:lifebalance/features/settings/presentation/screens/alert_settings_screen.dart';
import 'package:lifebalance/features/support/presentation/screens/faq_screen.dart';
import 'package:lifebalance/features/support/presentation/screens/video_explanation_screen.dart';
import 'package:lifebalance/features/profile/presentation/profile_screen.dart';
import 'package:lifebalance/features/profile/presentation/screens/biometric_profile_screen.dart';
import 'package:lifebalance/features/profile/presentation/activity_history_screen.dart';
import 'package:lifebalance/features/fog/presentation/fog_screen.dart';
import 'package:lifebalance/features/wearable/presentation/screens/device_scanning_screen.dart';
import 'package:lifebalance/features/wearable/presentation/screens/device_management_screen.dart';
import 'package:lifebalance/features/notifications/presentation/notifications_screen.dart';
import 'package:lifebalance/features/wearable/presentation/screens/watch_alert_screen.dart';
import 'package:lifebalance/features/wearable/presentation/screens/watch_progress_screen.dart';

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
  routes: <RouteBase>[
    // Authentication Routes (Outside the shell)
    GoRoute(
      path: '/splash',
      builder: (BuildContext context, GoRouterState state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (BuildContext context, GoRouterState state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/auth/register',
      builder: (BuildContext context, GoRouterState state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/auth/forgot-password',
      builder: (BuildContext context, GoRouterState state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/watch/alert',
      builder: (BuildContext context, GoRouterState state) => const WatchAlertScreen(),
    ),
    GoRoute(
      path: '/watch/progress',
      builder: (BuildContext context, GoRouterState state) => const WatchProgressScreen(),
    ),
    GoRoute(
      path: '/fog',
      builder: (BuildContext context, GoRouterState state) => const FogScreen(),
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
                  path: 'settings',
                  parentNavigatorKey: _rootNavigatorKey, // Opens on top of bottom navigation bar
                  builder: (BuildContext context, GoRouterState state) => const AlertSettingsScreen(),
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
