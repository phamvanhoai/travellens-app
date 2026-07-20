import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      password = TextEditingController(),
      confirmPassword = TextEditingController(),
      otp = TextEditingController();
  bool obscure = true;
  bool obscureConfirm = true;
  bool agreed = false;
  bool verifying = false;
  String? registrationMessage;
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
    confirmPassword.dispose();
    otp.dispose();
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
    if (widget.register && password.text != confirmPassword.text) {
      setState(() => validationError = 'Passwords do not match.');
      return;
    }
    if (widget.register && !agreed) {
      setState(
        () => validationError = 'Please accept the terms and privacy policy.',
      );
      return;
    }
    setState(() => validationError = null);
    final controller = ref.read(authProvider.notifier);
    final ok = widget.register
        ? await controller.register(name.text.trim(), emailValue, password.text)
        : await controller.login(emailValue, password.text);
    if (!mounted) return;
    if (!ok) {
      final result = ref.read(authProvider);
      if (!widget.register && result.requiresEmailVerification) {
        setState(() {
          verifying = true;
          validationError = null;
          registrationMessage =
              'This email has not been verified. Enter the OTP sent when you registered.';
        });
      }
      return;
    }
    if (widget.register) {
      setState(() {
        verifying = true;
        registrationMessage =
            'Registration successful. Check your email for the OTP.';
      });
    } else {
      context.go('/home');
    }
  }

  Future<void> verifyOtp() async {
    final code = otp.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => validationError = 'Enter the 6-digit verification code.');
      return;
    }
    setState(() => validationError = null);
    final ok = await ref
        .read(authProvider.notifier)
        .verifyEmail(email.text.trim(), code);
    if (!mounted || !ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Email verified. You can now sign in.')),
    );
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (verifying) return _buildOtpScreen(auth);
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
                  horizontal: 18,
                  vertical: 12,
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
                                  minimumSize: const Size(36, 36),
                                  maximumSize: const Size(36, 36),
                                  padding: EdgeInsets.zero,
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
                          const SizedBox(height: 24),
                          // App icon
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              gradient: const LinearGradient(
                                colors: AppColors.brandGradientLight,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.brand.withValues(alpha: .30),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.travel_explore_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.register
                                ? 'Create your account'
                                : 'Welcome back',
                            style: AppTextStyles.h1.copyWith(fontSize: 27),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.register
                                ? 'Create an account to save places and plan unforgettable trips.'
                                : 'Sign in to continue exploring the world with TravelLens.',
                            style: AppTextStyles.bodySmall,
                          ),
                          const SizedBox(height: 20),

                          // Form card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.dark.withValues(alpha: .05),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (widget.register) ...[
                                  _FieldLabel('Full name'),
                                  const SizedBox(height: 6),
                                  _AuthField(
                                    controller: name,
                                    hintText: 'Enter your full name',
                                    icon: Icons.person_outline_rounded,
                                  ),
                                  const SizedBox(height: 13),
                                ],
                                _FieldLabel('Email address'),
                                const SizedBox(height: 6),
                                _AuthField(
                                  controller: email,
                                  hintText: 'you@example.com',
                                  icon: Icons.mail_outline_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 13),
                                _FieldLabel('Password'),
                                const SizedBox(height: 6),
                                _AuthField(
                                  controller: password,
                                  hintText: 'At least 6 characters',
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: obscure,
                                  onSubmitted: widget.register ? null : submit,
                                  onToggleVisibility: () =>
                                      setState(() => obscure = !obscure),
                                ),
                                if (widget.register) ...[
                                  const SizedBox(height: 13),
                                  _FieldLabel('Confirm password'),
                                  const SizedBox(height: 6),
                                  _AuthField(
                                    controller: confirmPassword,
                                    hintText: 'Enter password again',
                                    icon: Icons.lock_outline_rounded,
                                    obscureText: obscureConfirm,
                                    onSubmitted: submit,
                                    onToggleVisibility: () => setState(
                                      () => obscureConfirm = !obscureConfirm,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  InkWell(
                                    onTap: () =>
                                        setState(() => agreed = !agreed),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 30,
                                          height: 30,
                                          child: Checkbox(
                                            value: agreed,
                                            onChanged: (value) => setState(
                                              () => agreed = value ?? false,
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Expanded(
                                          child: Text(
                                            'I agree to the Terms & Conditions and Privacy Policy',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              color: AppColors.muted,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (validationError != null ||
                                    auth.error != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(10),
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
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 46,
                                  child: FilledButton(
                                    onPressed: auth.loading ? null : submit,
                                    child: auth.loading
                                        ? const SizedBox.square(
                                            dimension: 18,
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
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
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

  Widget _buildOtpScreen(AuthState auth) => Scaffold(
    backgroundColor: Colors.white,
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFF6FF), Colors.white, Color(0xFFF0F9FF)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton.outlined(
                      onPressed: auth.loading
                          ? null
                          : () => setState(() {
                              verifying = false;
                              validationError = null;
                            }),
                      icon: const Icon(Icons.arrow_back_rounded, size: 19),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(36, 36),
                        maximumSize: const Size(36, 36),
                        padding: EdgeInsets.zero,
                        side: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.brandGradientLight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.mark_email_read_outlined,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Verify your email',
                    style: AppTextStyles.h1.copyWith(fontSize: 27),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Enter the 6-digit OTP sent to ${email.text.trim()}',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (registrationMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.successSoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              registrationMessage!,
                              style: const TextStyle(
                                color: Color(0xFF047857),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 13),
                        ],
                        const _FieldLabel('Verification code (OTP)'),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 48,
                          child: TextField(
                            controller: otp,
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            maxLength: 6,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onSubmitted: (_) => verifyOtp(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 8,
                            ),
                            decoration: const InputDecoration(
                              hintText: '000000',
                              counterText: '',
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        if (validationError != null || auth.error != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            validationError ?? auth.error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 46,
                          child: FilledButton(
                            onPressed: auth.loading ? null : verifyOtp,
                            child: auth.loading
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Verify email'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTextStyles.label.copyWith(fontSize: 11.5));
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.onToggleVisibility,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final VoidCallback? onToggleVisibility;
  final Future<void> Function()? onSubmitted;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 46,
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: onSubmitted == null
          ? TextInputAction.next
          : TextInputAction.done,
      onFieldSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      style: const TextStyle(fontSize: 12.5),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon, size: 18),
        prefixIconColor: AppColors.muted,
        suffixIcon: onToggleVisibility == null
            ? null
            : IconButton(
                onPressed: onToggleVisibility,
                icon: Icon(
                  obscureText
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                  color: AppColors.muted,
                ),
              ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    ),
  );
}
