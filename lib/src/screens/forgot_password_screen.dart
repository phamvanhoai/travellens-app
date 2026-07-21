import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/network/api_client.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialToken});
  final String? initialToken;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  int _step = 0;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _resetToken;
  String? _error;
  String? _message;
  Timer? _timer;
  int _resendSeconds = 0;

  @override
  void initState() {
    super.initState();
    final token = widget.initialToken?.trim() ?? '';
    if (token.isNotEmpty) {
      _resetToken = token;
      _step = 2;
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _resendSeconds = 15);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^\@\s]+@[^\@\s]+\.[^\@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Vui lòng nhập địa chỉ email hợp lệ.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });
    try {
      final response = await ref
          .read(dioProvider)
          .post('/auth/forgot-password', data: {'email': email});
      if (!mounted) return;
      setState(() {
        _step = 1;
        _message =
            _responseMessage(response.data) ??
            'Mã đặt lại mật khẩu đã được gửi tới email của bạn.';
      });
      _startCooldown();
    } catch (error) {
      if (mounted) setState(() => _error = apiError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _otp.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Vui lòng nhập mã xác minh gồm 6 chữ số.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });
    try {
      final response = await ref
          .read(dioProvider)
          .post(
            '/auth/verify-reset-code',
            data: {'email': _email.text.trim(), 'code': code},
          );
      final token = _readResetToken(response.data);
      if (token.isEmpty) {
        throw StateError('Máy chủ không trả về reset token.');
      }
      if (!mounted) return;
      setState(() {
        _resetToken = token;
        _step = 2;
        _message = 'Mã xác minh hợp lệ. Hãy tạo mật khẩu mới.';
      });
    } catch (error) {
      if (mounted) setState(() => _error = apiError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if ((_resetToken ?? '').isEmpty) {
      setState(() => _error = 'Reset token không hợp lệ. Vui lòng gửi lại mã.');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = 'Mật khẩu mới phải có ít nhất 8 ký tự.');
      return;
    }
    if (_password.text != _confirmPassword.text) {
      setState(() => _error = 'Hai mật khẩu không trùng khớp.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });
    try {
      await ref
          .read(dioProvider)
          .post(
            '/auth/reset-password',
            data: {'reset_token': _resetToken, 'new_password': _password.text},
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 42,
          ),
          title: const Text('Đổi mật khẩu thành công'),
          content: const Text(
            'Bạn có thể đăng nhập bằng mật khẩu mới ngay bây giờ.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Đăng nhập'),
            ),
          ],
        ),
      );
      if (mounted) context.go('/login');
    } catch (error) {
      if (mounted) setState(() => _error = apiError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _back() {
    if (_loading) return;
    if (_step == 0 || widget.initialToken?.isNotEmpty == true) {
      context.go('/login');
    } else {
      setState(() {
        _step--;
        _error = null;
        _message = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFECFDF8), Colors.white, Color(0xFFF0F9FF)],
          stops: [0, .5, 1],
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
                  Row(
                    children: [
                      IconButton.outlined(
                        onPressed: _back,
                        icon: const Icon(Icons.arrow_back_rounded, size: 19),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(36, 36),
                          maximumSize: const Size(36, 36),
                          padding: EdgeInsets.zero,
                          side: const BorderSide(color: AppColors.border),
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
                  Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: const LinearGradient(
                        colors: AppColors.brandGradientLight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brand.withValues(alpha: .25),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(_stepIcon, color: Colors.white, size: 25),
                  ),
                  const SizedBox(height: 16),
                  Text(_title, style: AppTextStyles.h1.copyWith(fontSize: 27)),
                  const SizedBox(height: 7),
                  Text(_subtitle, style: AppTextStyles.bodySmall),
                  const SizedBox(height: 14),
                  _StepIndicator(step: _step),
                  const SizedBox(height: 16),
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
                        if (_message != null) ...[
                          _Notice(message: _message!, success: true),
                          const SizedBox(height: 12),
                        ],
                        if (_error != null) ...[
                          _Notice(message: _error!, success: false),
                          const SizedBox(height: 12),
                        ],
                        if (_step == 0) _emailForm(),
                        if (_step == 1) _otpForm(),
                        if (_step == 2) _passwordForm(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _loading ? null : () => context.go('/login'),
                    icon: const Icon(Icons.login_rounded, size: 16),
                    label: const Text(
                      'Quay lại đăng nhập',
                      style: TextStyle(fontSize: 11.5),
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

  Widget _emailForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _ResetLabel('Địa chỉ email'),
      const SizedBox(height: 6),
      _ResetField(
        controller: _email,
        hintText: 'you@example.com',
        icon: Icons.mail_outline_rounded,
        keyboardType: TextInputType.emailAddress,
        onSubmitted: _sendCode,
      ),
      const SizedBox(height: 16),
      _SubmitButton(
        loading: _loading,
        label: 'Gửi mã đặt lại',
        onPressed: _sendCode,
      ),
    ],
  );

  Widget _otpForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Mã đã được gửi tới ${_email.text.trim()}',
        style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
      ),
      const SizedBox(height: 12),
      const _ResetLabel('Mã xác minh'),
      const SizedBox(height: 6),
      SizedBox(
        height: 48,
        child: TextField(
          controller: _otp,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (_) => _verifyCode(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 8,
          ),
          decoration: const InputDecoration(
            hintText: '000000',
            counterText: '',
          ),
        ),
      ),
      const SizedBox(height: 16),
      _SubmitButton(
        loading: _loading,
        label: 'Xác minh mã',
        onPressed: _verifyCode,
      ),
      const SizedBox(height: 7),
      TextButton(
        onPressed: _loading || _resendSeconds > 0 ? null : _sendCode,
        child: Text(
          _resendSeconds > 0
              ? 'Gửi lại mã sau ${_resendSeconds}s'
              : 'Gửi lại mã',
          style: const TextStyle(fontSize: 11.5),
        ),
      ),
    ],
  );

  Widget _passwordForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _ResetLabel('Mật khẩu mới'),
      const SizedBox(height: 6),
      _ResetField(
        controller: _password,
        hintText: 'Ít nhất 8 ký tự',
        icon: Icons.lock_outline_rounded,
        obscureText: _obscurePassword,
        onToggleVisibility: () =>
            setState(() => _obscurePassword = !_obscurePassword),
      ),
      const SizedBox(height: 13),
      const _ResetLabel('Xác nhận mật khẩu mới'),
      const SizedBox(height: 6),
      _ResetField(
        controller: _confirmPassword,
        hintText: 'Nhập lại mật khẩu mới',
        icon: Icons.lock_outline_rounded,
        obscureText: _obscureConfirm,
        onToggleVisibility: () =>
            setState(() => _obscureConfirm = !_obscureConfirm),
        onSubmitted: _resetPassword,
      ),
      const SizedBox(height: 10),
      const Text(
        '• Ít nhất 8 ký tự\n• Nên kết hợp chữ hoa, chữ thường, số hoặc ký hiệu',
        style: TextStyle(fontSize: 9.5, height: 1.6, color: Color(0xFF059669)),
      ),
      const SizedBox(height: 16),
      _SubmitButton(
        loading: _loading,
        label: 'Đặt lại mật khẩu',
        onPressed: _resetPassword,
      ),
    ],
  );

  String get _title => switch (_step) {
    1 => 'Xác minh email',
    2 => 'Tạo mật khẩu mới',
    _ => 'Quên mật khẩu?',
  };
  String get _subtitle => switch (_step) {
    1 => 'Nhập mã gồm 6 chữ số đã được gửi tới email của bạn.',
    2 => 'Tạo mật khẩu mới để tiếp tục sử dụng TravelLens.',
    _ => 'Nhập email và chúng tôi sẽ gửi mã đặt lại mật khẩu.',
  };
  IconData get _stepIcon => switch (_step) {
    1 => Icons.mark_email_read_outlined,
    2 => Icons.lock_reset_rounded,
    _ => Icons.key_rounded,
  };
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});
  final int step;
  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(3, (index) {
      final active = index <= step;
      return Expanded(
        child: Container(
          height: 3,
          margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
          decoration: BoxDecoration(
            color: active ? AppColors.brand : AppColors.border,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      );
    }),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, required this.success});
  final String message;
  final bool success;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: success ? AppColors.successSoft : AppColors.errorSoft,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(
          success ? Icons.check_circle_outline : Icons.error_outline_rounded,
          size: 17,
          color: success ? AppColors.success : AppColors.error,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontSize: 10.5,
              color: success ? const Color(0xFF047857) : AppColors.error,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ResetLabel extends StatelessWidget {
  const _ResetLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTextStyles.label.copyWith(fontSize: 11.5));
}

class _ResetField extends StatelessWidget {
  const _ResetField({
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
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: onSubmitted == null
          ? TextInputAction.next
          : TextInputAction.done,
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      style: const TextStyle(fontSize: 11.5),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon, size: 18),
        suffixIcon: onToggleVisibility == null
            ? null
            : IconButton(
                onPressed: onToggleVisibility,
                icon: Icon(
                  obscureText
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                ),
              ),
      ),
    ),
  );
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.loading,
    required this.label,
    required this.onPressed,
  });
  final bool loading;
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 46,
    child: FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(label),
    ),
  );
}

String _readResetToken(dynamic body) {
  dynamic value = unwrap(body);
  if (value is Map && value['data'] is Map) value = value['data'];
  return value is Map
      ? '${value['reset_token'] ?? value['resetToken'] ?? value['token'] ?? ''}'
      : '';
}

String? _responseMessage(dynamic body) {
  if (body is Map && body['message'] != null) return '${body['message']}';
  return null;
}
