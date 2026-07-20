import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../features/auth/auth_controller.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, required this.register});
  final bool register;
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController();
  bool obscure = true;
  String? validationError;
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.forward();
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    _anim.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final emailValue = email.text.trim();
    if (widget.register && name.text.trim().length < 2) {
      setState(() => validationError = 'Enter your full name.');
      return;
    }
    if (!RegExp(r'^[^\@\s]+@[^\@\s]+\.[^\@\s]+$').hasMatch(emailValue)) {
      setState(() => validationError = 'Enter a valid email address.');
      return;
    }
    if (password.text.length < 6) {
      setState(
        () => validationError = 'Password must contain at least 6 characters.',
      );
      return;
    }
    setState(() => validationError = null);
    final controller = ref.read(authProvider.notifier);
    final ok = widget.register
        ? await controller.register(name.text.trim(), emailValue, password.text)
        : await controller.login(emailValue, password.text);
    if (!mounted || !ok) return;
    if (widget.register) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created. Verify your email, then sign in.'),
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
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFECFDF8), Colors.white, Color(0xFFF0F9FF)],
                  stops: [0, 0.5, 1],
                ),
              ),
            ),
          ),
          // Decorative blob top-right
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brand.withValues(alpha: .08),
              ),
            ),
          ),
          // Decorative blob bottom-left
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: .06),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Back + Logo
                          Row(
                            children: [
                              IconButton.outlined(
                                onPressed: () => context.go('/home'),
                                icon: const Icon(
                                  Icons.arrow_back_rounded,
                                  size: 20,
                                ),
                                style: IconButton.styleFrom(
                                  side: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'TRAVELLENS',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.brand,
                                  letterSpacing: 2.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                          // App icon
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: const LinearGradient(
                                colors: AppColors.brandGradientLight,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.brand.withValues(alpha: .30),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.travel_explore_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            widget.register
                                ? 'Begin your\njourney.'
                                : 'Welcome\nback.',
                            style: AppTextStyles.h1.copyWith(fontSize: 36),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.register
                                ? 'Create an account to save places and plan unforgettable trips.'
                                : 'Sign in to continue exploring the world with TravelLens.',
                            style: AppTextStyles.bodySmall,
                          ),
                          const SizedBox(height: 32),

                          // Form card
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppColors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.dark.withValues(alpha: .05),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (widget.register) ...[
                                  _FieldLabel('Full name'),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: name,
                                    textInputAction: TextInputAction.next,
                                    decoration: InputDecoration(
                                      hintText: 'How should we call you?',
                                      prefixIcon: const Icon(
                                        Icons.person_outline_rounded,
                                        size: 20,
                                      ),
                                      prefixIconColor: AppColors.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                ],
                                _FieldLabel('Email address'),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: email,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    hintText: 'you@example.com',
                                    prefixIcon: const Icon(
                                      Icons.mail_outline_rounded,
                                      size: 20,
                                    ),
                                    prefixIconColor: AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _FieldLabel('Password'),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: password,
                                  obscureText: obscure,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => submit(),
                                  decoration: InputDecoration(
                                    hintText: 'At least 6 characters',
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                      size: 20,
                                    ),
                                    prefixIconColor: AppColors.muted,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        size: 20,
                                        color: AppColors.muted,
                                      ),
                                      onPressed: () =>
                                          setState(() => obscure = !obscure),
                                    ),
                                  ),
                                ),
                                if (validationError != null ||
                                    auth.error != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppColors.errorSoft,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.error.withValues(
                                          alpha: .2,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline_rounded,
                                          color: AppColors.error,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            validationError ?? auth.error!,
                                            style: AppTextStyles.bodySmall
                                                .copyWith(
                                                  color: AppColors.error,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 22),
                                FilledButton(
                                  onPressed: auth.loading ? null : submit,
                                  child: auth.loading
                                      ? const SizedBox.square(
                                          dimension: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          widget.register
                                              ? 'Create account'
                                              : 'Sign in',
                                        ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => context.go(
                              widget.register ? '/login' : '/register',
                            ),
                            child: RichText(
                              text: TextSpan(
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.muted,
                                ),
                                children: [
                                  TextSpan(
                                    text: widget.register
                                        ? 'Already have an account? '
                                        : 'New to TravelLens? ',
                                  ),
                                  TextSpan(
                                    text: widget.register
                                        ? 'Sign in'
                                        : 'Create account',
                                    style: GoogleFonts.outfit(
                                      color: AppColors.brand,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTextStyles.label.copyWith(fontSize: 13));
}
