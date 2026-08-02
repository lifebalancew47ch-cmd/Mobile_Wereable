import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifebalance/features/dashboard/presentation/dashboard_screen.dart';
import 'package:lifebalance/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:lifebalance/features/dashboard/domain/entities/dashboard_models.dart';

void main() {
  testWidgets('DashboardScreen renders static UI correctly', (WidgetTester tester) async {
    final dashboard = DashboardData(
      summary: DashboardSummary(
        userId: '1',
        fullName: 'Usuario Prueba',
        dailySteps: 8500,
        activeMinutes: 45,
        points: 120,
        streakDays: 3,
      ),
      kpis: DashboardKpis(
        userId: '1',
        bmi: 24.2,
        heartRate: 72,
        dailySteps: 8500,
        caloriesBurned: 420,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardDataProvider.overrideWith((ref) async => dashboard),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );
    await tester.pump();

    // Verify AppBar title
    expect(find.text('Dashboard'), findsOneWidget);

    // Verify metric cards are rendered with real data
    expect(find.text('Métricas clave'), findsOneWidget);
    expect(find.text('Pasos'), findsOneWidget);
    expect(find.text('Corazón'), findsOneWidget);
    expect(find.text('IMC'), findsOneWidget);
    expect(find.text('Calorías'), findsOneWidget);

    expect(find.text('8500'), findsOneWidget);
    expect(find.text('72 bpm'), findsOneWidget);
    expect(find.text('24.2'), findsOneWidget);
    expect(find.text('420 kcal'), findsOneWidget);

    // Verify icons are present
    expect(find.byIcon(Icons.directions_walk), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.monitor_weight_outlined), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
  });
}
