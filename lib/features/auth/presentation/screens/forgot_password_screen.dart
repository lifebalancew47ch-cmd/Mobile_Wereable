import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/forgot_password_provider.dart';
import '../../../../core/validation/validators.dart';
import 'package:flutter/services.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final forgotPasswordState = ref.watch(forgotPasswordProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar Contraseña')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ingresa tu correo para enviarte un enlace de recuperación.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Correo Electrónico',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.username],
                maxLength: 254,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  LengthLimitingTextInputFormatter(254),
                ],
                validator: Validators.email,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: forgotPasswordState.status == ForgotPasswordStatus.loading
                  ? null
                  : () async {
                      if (_formKey.currentState?.validate() ?? false) {
                        final success = await ref.read(forgotPasswordProvider.notifier).sendInstructions(_emailController.text);
                      if (!context.mounted) return;
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Si el correo existe, recibirás instrucciones.'), backgroundColor: Colors.green),
                        );
                        context.pop();
                      } else if (forgotPasswordState.errorMessage != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(forgotPasswordState.errorMessage!), backgroundColor: colorScheme.error),
                        );
                      }
                    }
                  },
            child: forgotPasswordState.status == ForgotPasswordStatus.loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Enviar Enlace'),
            ),
          ],
        ),
      ),
    );
  }
}
