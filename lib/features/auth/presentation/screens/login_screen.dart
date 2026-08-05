import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/dynamic_onboarding_service.dart';
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
  final _dynamicService = DynamicOnboardingService();
  
  bool _isPasswordVisible = false;
  bool _rememberMe = false;

  late String _dynamicQuote;
  late TimePhase _currentPhase;

  @override
  void initState() {
    super.initState();
    _currentPhase = DynamicOnboardingService.getTimePhase();
    _dynamicQuote = _dynamicService.getRandomLoginPhrase();
    _loadSavedCredentials();
  }

  IconData _getPhaseIcon(TimePhase phase) {
    switch (phase) {
      case TimePhase.madrugada:
        return Icons.bedtime_outlined;
      case TimePhase.manana:
        return Icons.wb_sunny_outlined;
      case TimePhase.mediodia:
        return Icons.wb_twilight_outlined;
      case TimePhase.tarde:
        return Icons.nature_people_outlined;
      case TimePhase.noche:
        return Icons.nightlight_round_outlined;
    }
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final savedEmail = await _storage.read(key: 'saved_email');
      final rememberMe = await _storage.read(key: 'remember_me');

      if (rememberMe == 'true' && savedEmail != null) {
        setState(() {
          _emailController.text = savedEmail;
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
        // Nunca persistir la contraseña: solo el email para autocompletar.
        await _storage.write(key: 'saved_email', value: _emailController.text);
        await _storage.write(key: 'remember_me', value: 'true');
      } else {
        await _storage.delete(key: 'saved_email');
        await _storage.delete(key: 'remember_me');
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/landing'),
          tooltip: 'Volver',
        ),
      ),
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
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9F1EC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF3E6F58).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3E6F58),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getPhaseIcon(_currentPhase),
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DynamicOnboardingService.getPhaseTitle(_currentPhase),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3E6F58),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _dynamicQuote,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF2C3E35),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
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
                OutlinedButton.icon(
                  onPressed: () async {
                    const url = 'https://lifebalance-adv3.onrender.com/register';
                    final uri = Uri.parse(url);
                    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                    if (!launched && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No se pudo abrir el registro en la web.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Crear Cuenta en la Web'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

