import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../core/network/api_client.dart';
import '../design/app_colors.dart';
import '../design/app_widgets.dart';

class PaymentCheckoutScreen extends ConsumerStatefulWidget {
  const PaymentCheckoutScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<PaymentCheckoutScreen> createState() =>
      _PaymentCheckoutScreenState();
}

class _PaymentCheckoutScreenState extends ConsumerState<PaymentCheckoutScreen> {
  Map<String, dynamic>? _payment;
  bool _loading = true;
  bool _checking = false;
  String? _error;
  Timer? _statusTimer;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _createPayment();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  int get _paymentId =>
      int.tryParse('${_payment?['payment_id'] ?? _payment?['id'] ?? 0}') ?? 0;
  String get _status =>
      '${_payment?['status'] ?? _payment?['payment_status'] ?? 'pending'}'
          .toLowerCase();

  Duration? get _remaining {
    final expires = DateTime.tryParse('${_payment?['expired_at'] ?? ''}');
    if (expires == null) return null;
    final value = expires.toLocal().difference(_now);
    return value.isNegative ? Duration.zero : value;
  }

  Future<void> _createPayment() async {
    if (widget.bookingId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Thiếu mã booking.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref
          .read(dioProvider)
          .post(
            '/payments',
            data: {
              'booking_id': int.tryParse(widget.bookingId) ?? widget.bookingId,
            },
          );
      if (!mounted) return;
      setState(() => _payment = _unwrapPayment(response.data));
      _startTimers();
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startTimers() {
    _statusTimer?.cancel();
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    if (_status == 'pending') {
      _statusTimer = Timer.periodic(
        const Duration(seconds: 8),
        (_) => _refreshStatus(false),
      );
    }
  }

  Future<void> _refreshStatus([bool notify = true]) async {
    if (_paymentId <= 0 || _checking) return;
    setState(() => _checking = true);
    try {
      final response = await ref
          .read(dioProvider)
          .get('/payments/$_paymentId/status');
      final update = _unwrapPayment(response.data);
      final paymentStatus =
          '${update['status'] ?? update['payment_status'] ?? ''}'.toLowerCase();
      if (paymentStatus.isEmpty || paymentStatus == 'pending') {
        try {
          final bookingResponse = await ref
              .read(dioProvider)
              .get('/bookings/${widget.bookingId}');
          final bookingStatus = _bookingPaymentStatus(bookingResponse.data);
          if (bookingStatus.isNotEmpty && bookingStatus != 'pending') {
            update['status'] = bookingStatus;
          }
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        final merged = {...?_payment, ...update};
        final nextStatus =
            update['status'] ??
            update['payment_status'] ??
            merged['status'] ??
            merged['payment_status'];
        if (nextStatus != null) merged['status'] = nextStatus;
        _payment = merged;
      });
      if (_status != 'pending') _statusTimer?.cancel();
      if (notify) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Trạng thái: ${_statusLabel(_status)}')),
        );
      }
    } catch (e) {
      if (mounted && notify) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(e))));
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _copy(String value, String label) async {
    if (value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã sao chép $label.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _payment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thanh toán')),
        body: AppErrorState(
          error: _error ?? 'Không thể tạo thanh toán.',
          onRetry: _createPayment,
        ),
      );
    }

    final payment = _payment!;
    final qr = AppConfig.assetUrl('${payment['qr_url'] ?? ''}');
    final amount = double.tryParse('${payment['amount'] ?? 0}') ?? 0;
    final code = '${payment['payment_code'] ?? payment['code'] ?? ''}';
    final transfer = '${payment['transfer_content'] ?? code}';
    final bank = '${payment['bank_name'] ?? 'SePay'}';
    final account = '${payment['bank_account'] ?? ''}';
    final remaining = _remaining;
    final displayedStatus = _status == 'pending' && remaining == Duration.zero
        ? 'expired'
        : _status;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Thanh toán')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quét mã QR để thanh toán',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Chuyển đúng số tiền và nội dung bên dưới.',
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                _PaymentBadge(status: displayedStatus),
              ],
            ),
            if (_status == 'paid') ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.successSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppColors.success),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Thanh toán thành công. Booking đang được xác nhận.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Center(
              child: Container(
                width: 270,
                height: 270,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(color: Color(0x10000000), blurRadius: 16),
                  ],
                ),
                child: qr.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.qr_code_2_rounded,
                              size: 64,
                              color: AppColors.subtle,
                            ),
                            SizedBox(height: 8),
                            Text('QR chưa khả dụng'),
                          ],
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: qr,
                        fit: BoxFit.contain,
                        errorWidget: (_, _, _) =>
                            const Icon(Icons.broken_image_outlined, size: 48),
                      ),
              ),
            ),
            if (_status == 'pending' && remaining != null) ...[
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: remaining > Duration.zero
                        ? const Color(0xFFFFF7E6)
                        : AppColors.errorSoft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    remaining > Duration.zero
                        ? 'QR hết hạn sau ${_countdown(remaining)}'
                        : 'Mã QR đã hết hạn',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: remaining > Duration.zero
                          ? const Color(0xFFB56A00)
                          : AppColors.error,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _checking ? null : () => _refreshStatus(),
                icon: _checking
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Kiểm tra trạng thái thanh toán'),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Thông tin chuyển khoản',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _PaymentInfo(label: 'Mã booking', value: widget.bookingId),
            _PaymentInfo(
              label: 'Mã thanh toán',
              value: code,
              copy: () => _copy(code, 'mã thanh toán'),
            ),
            _PaymentInfo(
              label: 'Số tiền',
              value: '${NumberFormat.decimalPattern('vi').format(amount)}đ',
              strong: true,
            ),
            _PaymentInfo(label: 'Ngân hàng', value: bank),
            if (account.isNotEmpty)
              _PaymentInfo(
                label: 'Số tài khoản',
                value: account,
                copy: () => _copy(account, 'số tài khoản'),
              ),
            _PaymentInfo(
              label: 'Nội dung chuyển khoản',
              value: transfer,
              copy: () => _copy(transfer, 'nội dung chuyển khoản'),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Color(0xFFB56A00),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vui lòng chuyển chính xác số tiền và nội dung để hệ thống tự động đối soát.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.45,
                        color: Color(0xFF8A5600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.go('/bookings'),
                    child: const Text('Booking của tôi'),
                  ),
                ),
                if (_status == 'paid') ...[
                  const SizedBox(width: 9),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => context.go('/bookings'),
                      child: const Text('Tiếp tục'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentBadge extends StatelessWidget {
  const _PaymentBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final paid = status == 'paid';
    final failed = status == 'failed' || status == 'expired';
    final color = paid
        ? AppColors.success
        : failed
        ? AppColors.error
        : AppColors.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _PaymentInfo extends StatelessWidget {
  const _PaymentInfo({
    required this.label,
    required this.value,
    this.copy,
    this.strong = false,
  });
  final String label;
  final String value;
  final VoidCallback? copy;
  final bool strong;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(11),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 9, color: AppColors.muted),
              ),
              const SizedBox(height: 3),
              Text(
                value.isEmpty ? '-' : value,
                style: TextStyle(
                  fontSize: strong ? 15 : 12,
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                  color: strong ? AppColors.brand : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
        if (copy != null)
          IconButton(
            onPressed: copy,
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.copy_rounded,
              size: 17,
              color: AppColors.brand,
            ),
          ),
      ],
    ),
  );
}

Map<String, dynamic> _unwrapPayment(dynamic body) {
  dynamic value = unwrap(body);
  if (value is Map && value['payment'] is Map) {
    final payment = Map<String, dynamic>.from(value['payment']);
    final status =
        value['status'] ??
        value['payment_status'] ??
        payment['status'] ??
        payment['payment_status'];
    if (status != null) payment['status'] = status;
    return payment;
  }
  if (value is String) return {'status': value};
  if (value is Map) {
    final payment = Map<String, dynamic>.from(value);
    final status = payment['status'] ?? payment['payment_status'];
    if (status != null) payment['status'] = status;
    return payment;
  }
  return <String, dynamic>{};
}

String _statusLabel(String status) => switch (status) {
  'paid' => 'Đã thanh toán',
  'failed' => 'Thất bại',
  'expired' => 'Hết hạn',
  'refunded' => 'Hoàn tiền',
  _ => 'Đang chờ',
};

String _bookingPaymentStatus(dynamic body) {
  dynamic value = unwrap(body);
  if (value is Map && value['booking'] is Map) value = value['booking'];
  if (value is! Map) return '';
  final latest = value['latest_payment'] ?? value['latestPayment'];
  final payment =
      latest ??
      value['payment'] ??
      value['Payment'] ??
      ((value['payments'] is List && value['payments'].isNotEmpty)
          ? value['payments'].first
          : null) ??
      ((value['Payments'] is List && value['Payments'].isNotEmpty)
          ? value['Payments'].first
          : null);
  final paymentStatus = payment is Map
      ? payment['status'] ?? payment['payment_status']
      : null;
  final direct =
      paymentStatus ?? value['payment_status'] ?? value['paymentStatus'];
  if (direct != null && '$direct'.isNotEmpty) return '$direct'.toLowerCase();
  final bookingStatus = '${value['status'] ?? ''}'.toLowerCase();
  return bookingStatus == 'confirmed' || bookingStatus == 'completed'
      ? 'paid'
      : '';
}

String _countdown(Duration value) =>
    '${value.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
    '${value.inSeconds.remainder(60).toString().padLeft(2, '0')}';
