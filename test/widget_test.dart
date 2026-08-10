// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lifebalance/main.dart';


void main() {
  testWidgets('App launches successfully smoke test', (WidgetTester tester) async {
    // La app real envuelve MyApp en un ProviderScope (ver main.dart).
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    // El router resuelve el redirect de sesión de forma asíncrona
    // (lee el token desde Secure Storage), por lo que se necesita al
    // menos un frame adicional antes de inspeccionar el árbol.
    await tester.pump();

    // Verificamos que el router construyó el MaterialApp y MyApp sin crashear.
    expect(find.byType(MyApp), findsOneWidget);

    // Esperamos los temporizadores de la SplashScreen sin pumpAndSettle
    // (el CircularProgressIndicator impide que el frame se estabilice).
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
  });
}
