// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:lifebalance/main.dart';


void main() {
  testWidgets('App launches successfully smoke test', (WidgetTester tester) async {
    // Solo construimos la aplicación principal para verificar que no crashea al arrancar la UI.
    // (Nota: si main.dart requiere inicializar Firebase u otros plugins nativos, 
    // podrías necesitar configurar un mock para el entorno de test).
    await tester.pumpWidget(const MyApp());
    
    // Verificamos que el router construyó el MaterialApp sin crashear.
    // La app muestra "LifeBalance" en alguna parte de la interfaz inicial (Splash Screen o Home).
    expect(find.text('LifeBalance'), findsWidgets);

    // Esperamos a que terminen los temporizadores (como el de 2 segundos de la SplashScreen)
    // para evitar el error "A Timer is still pending".
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
