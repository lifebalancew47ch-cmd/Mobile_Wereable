import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifebalance/features/dashboard/presentation/dashboard_screen.dart';

void main() {
  testWidgets('DashboardScreen renders loading state and static UI correctly', (WidgetTester tester) async {
    // Build the DashboardScreen inside a MaterialApp to provide Theme and Directionality
    await tester.pumpWidget(
      const MaterialApp(
        home: DashboardScreen(),
      ),
    );

    // Verify AppBar title
    expect(find.text('Dashboard'), findsOneWidget);

    // Verify main summary card renders the loading text
    expect(find.text('Resumen Diario'), findsOneWidget);
    expect(find.text('Cargando datos...'), findsOneWidget);

    // Verify Metric Cards exist with placeholders '--'
    expect(find.text('Métricas clave'), findsOneWidget);
    expect(find.text('Pasos'), findsOneWidget);
    expect(find.text('Corazón'), findsOneWidget);
    expect(find.text('Sueño'), findsOneWidget);
    expect(find.text('Calorías'), findsOneWidget);
    
    // We expect 4 placeholders for the 4 metric cards
    expect(find.text('--'), findsNWidgets(4));
    
    // Verify icons are present
    expect(find.byIcon(Icons.directions_walk), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.bedtime), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
  });
}
