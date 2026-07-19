import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/auth_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, required this.register});
  final bool register;
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool obscure = true;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    final controller = ref.read(authProvider.notifier);
    final ok = widget.register
        ? await controller.register(
            name.text.trim(),
            email.text.trim(),
            password.text,
          )
        : await controller.login(email.text.trim(), password.text);
    if (!mounted || !ok) return;
    if (widget.register) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account created. Please verify your email, then sign in.',
          ),
        ),
      );
      context.go('/login');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.travel_explore,
                    size: 64,
                    color: Color(0xFF0E7490),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.register ? 'Create your account' : 'Welcome back',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'TravelLens customer app',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  if (widget.register) ...[
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: (v) => (v?.trim().length ?? 0) < 2
                          ? 'Enter your full name'
                          : null,
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) =>
                        !(v ?? '').contains('@') ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: password,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => obscure = !obscure),
                        icon: Icon(
                          obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (v) => (v?.length ?? 0) < 6
                        ? 'Password must contain at least 6 characters'
                        : null,
                  ),
                  if (auth.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        auth.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: auth.loading ? null : submit,
                    child: auth.loading
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.register ? 'Create account' : 'Sign in'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () =>
                        context.go(widget.register ? '/login' : '/register'),
                    child: Text(
                      widget.register
                          ? 'Already have an account? Sign in'
                          : 'New to TravelLens? Create account',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
