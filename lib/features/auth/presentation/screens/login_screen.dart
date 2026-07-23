import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../providers/login_provider.dart';
import '../providers/login_state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  
  bool _isPasswordVisible = false;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final savedEmail = await _storage.read(key: 'saved_email');
      final savedPassword = await _storage.read(key: 'saved_password');
      final rememberMe = await _storage.read(key: 'remember_me');

      if (rememberMe == 'true' && savedEmail != null && savedPassword != null) {
        setState(() {
          _emailController.text = savedEmail;
          _passwordController.text = savedPassword;
          _rememberMe = true;
        });
      }
    } catch (e) {
      // Ignorar errores al leer del almacenamiento seguro
    }
  }

  Future<void> _saveCredentials() async {
    try {
      if (_rememberMe) {
        await _storage.write(key: 'saved_email', value: _emailController.text);
        await _storage.write(key: 'saved_password', value: _passwordController.text);
        await _storage.write(key: 'remember_me', value: 'true');
      } else {
        await _storage.delete(key: 'saved_email');
        await _storage.delete(key: 'saved_password');
        await _storage.write(key: 'remember_me', value: 'false');
      }
    } catch (e) {
      // Ignorar errores al guardar en el almacenamiento seguro
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(loginProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Listen for state changes (Error/Success)
    ref.listen(loginProvider, (previous, next) {
      if (next.status == LoginStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage ?? 'Error desconocido'), backgroundColor: colorScheme.error),
        );
      } else if (next.status == LoginStatus.success) {
        _saveCredentials();
        context.go('/dashboard');
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  width: 120,
                  height: 120,
                ),
                const SizedBox(height: 24),
                Text(
                  'Bienvenido a LifeBalance',
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Correo Electrónico',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                  obscureText: !_isPasswordVisible,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                        ),
                        const Text('Recordarme'),
                      ],
                    ),
                    TextButton(
                      onPressed: () => context.push('/auth/forgot-password'),
                      child: const Text('¿Olvidaste tu contraseña?'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: loginState.status == LoginStatus.loading
                      ? null
                      : () => ref.read(loginProvider.notifier).login(
                            _emailController.text,
                            _passwordController.text,
                          ),
                  child: loginState.status == LoginStatus.loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Iniciar Sesión'),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => context.push('/auth/register'),
                  child: const Text('Crear Cuenta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

