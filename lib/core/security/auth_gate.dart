import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _authorized = false;
  String _authMessage = 'Autenticación requerida';

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    bool authenticated = false;
    try {
      authenticated = await auth.authenticate(
        localizedReason: 'Por favor, autentícate para acceder a los datos de salud.',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } on PlatformException catch (e) {
      setState(() {
        _authMessage = 'Error de biometría: ${e.message}';
      });
      return;
    }

    if (!mounted) return;

    setState(() {
      _authorized = authenticated;
      if (_authorized) {
        // Redirigir a la app principal si la biometría es exitosa
        context.go('/dashboard');
      } else {
        _authMessage = 'Autenticación fallida. Intenta de nuevo.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            Text(_authMessage, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _authenticate,
              child: const Text('Autenticar'),
            )
          ],
        ),
      ),
    );
  }
}
