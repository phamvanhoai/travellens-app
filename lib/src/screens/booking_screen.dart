import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../core/network/api_client.dart';
import '../design/app_colors.dart';
import '../design/app_widgets.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.tourId});
  final int tourId;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  final _form = GlobalKey<FormState>();
  final _contactName = TextEditingController();
  final _phone = TextEditingController();
  final _coupon = TextEditingController();
  Map<String, dynamic>? _tour;
  DateTime? _date;
  int _adults = 1, _children = 0, _infants = 0;
  bool _loadingTour = true, _submitting = false, _accepted = false;
  bool _validatingCoupon = false;
  Map<String, dynamic>? _appliedCoupon;
  String? _couponError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTour();
  }

  @override
  void didUpdateWidget(covariant BookingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tourId != widget.tourId) _loadTour();
  }

  @override
  void dispose() {
    _contactName.dispose();
    _phone.dispose();
    _coupon.dispose();
    super.dispose();
  }

  Future<void> _loadTour() async {
    setState(() {
      _loadingTour = true;
      _error = null;
    });
    try {
      final response = await ref
          .read(dioProvider)
          .get('/tours/${widget.tourId}');
      dynamic data = unwrap(response.data);
      if (data is Map && data['tour'] is Map) data = data['tour'];
      if (!mounted) return;
      setState(() => _tour = Map<String, dynamic>.from(data as Map));
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    } finally {
      if (mounted) setState(() => _loadingTour = false);
    }
  }

  double get _adultPrice => _money(_tour?['price']);
  double get _childPrice {
    final value = _money(_tour?['child_price']);
    return value > 0 ? value : _adultPrice * .65;
  }

  double get _infantPrice => _money(_tour?['infant_price']);
  double get _total =>
      _adults * _adultPrice + _children * _childPrice + _infants * _infantPrice;
  double get _discount {
    final coupon = _appliedCoupon;
    if (coupon == null) return 0;
    final direct = _money(
      coupon['discount_amount'] ?? coupon['discountAmount'],
    );
    if (direct > 0) return direct.clamp(0, _total);
    final finalAmount = _money(coupon['final_amount'] ?? coupon['finalAmount']);
    if (finalAmount >= 0 && finalAmount < _total) return _total - finalAmount;
    return 0;
  }

  double get _finalTotal => (_total - _discount).clamp(0, _total);

  void _changeGuests(VoidCallback change) {
    setState(() {
      change();
      _appliedCoupon = null;
      _couponError = null;
    });
  }

  Future<void> _applyCoupon() async {
    final code = _coupon.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _couponError = 'Nhập mã giảm giá trước khi áp dụng.');
      return;
    }
    if (_total <= 0 || _validatingCoupon) return;
    setState(() {
      _validatingCoupon = true;
      _couponError = null;
      _appliedCoupon = null;
    });
    try {
      final response = await ref
          .read(dioProvider)
          .post(
            '/coupons/validate',
            data: {'code': code, 'booking_amount': _total},
          );
      dynamic result = unwrap(response.data);
      if (result is Map && result['data'] is Map) result = result['data'];
      final coupon = Map<String, dynamic>.from(result as Map);
      coupon['code'] ??= coupon['coupon'] is Map
          ? coupon['coupon']['code']
          : code;
      if (!mounted) return;
      setState(() {
        _appliedCoupon = coupon;
        _coupon.text = '${coupon['code'] ?? code}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Áp dụng mã giảm giá thành công.')),
      );
    } catch (e) {
      if (mounted) setState(() => _couponError = apiError(e));
    } finally {
      if (mounted) setState(() => _validatingCoupon = false);
    }
  }

  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _couponError = null;
      _coupon.clear();
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 730)),
      initialDate: _date ?? now.add(const Duration(days: 1)),
    );
    if (selected != null) setState(() => _date = selected);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate() || _date == null || !_accepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng điền đầy đủ thông tin và đồng ý điều khoản.'),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final passengers = <Map<String, dynamic>>[];
      void addPassengers(int count, String category) {
        for (var i = 0; i < count; i++) {
          passengers.add({
            'passenger_name': _contactName.text.trim(),
            'age_category': category,
          });
        }
      }

      addPassengers(_adults, 'adult');
      addPassengers(_children, 'child');
      addPassengers(_infants, 'infant');
      final response = await ref
          .read(dioProvider)
          .post(
            '/bookings',
            data: {
              'tour_id': widget.tourId,
              'contact_phone': _phone.text.trim(),
              'travel_date': DateFormat('yyyy-MM-dd').format(_date!),
              if (_appliedCoupon != null) 'coupon_code': _coupon.text.trim(),
              'passengers': passengers,
            },
          );
      final data = unwrap(response.data);
      final id = data is Map ? data['booking_id'] ?? data['id'] : null;
      if (mounted)
        context.go(
          id == null ? '/bookings' : '/payment/checkout?bookingId=$id',
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingTour)
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    if (_error != null || _tour == null)
      return Scaffold(
        appBar: AppBar(),
        body: AppErrorState(
          error: _error ?? 'Không tìm thấy tour.',
          onRetry: _loadTour,
        ),
      );
    final tour = _tour!;
    final name = '${tour['name'] ?? tour['title'] ?? 'Tour du lịch'}';
    final image = AppConfig.assetUrl(
      '${tour['thumbnail_url'] ?? tour['thumbnail'] ?? tour['image_url'] ?? ''}',
    );
    final destination = _destination(tour);
    final days = _integer(tour['duration_days']);
    final nights = _integer(tour['duration_nights']);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/tours/${widget.tourId}'),
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
        ),
        title: const Text('Đặt tour'),
      ),
      body: Form(
        key: _form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          child: Column(
            children: [
              const _BookingSteps(),
              const SizedBox(height: 18),
              _SelectedTour(
                name: name,
                destination: destination,
                image: image,
                duration: days > 0
                    ? '$days ngày${nights > 0 ? ' $nights đêm' : ''}'
                    : '${tour['duration'] ?? 'Trong ngày'}',
              ),
              const SizedBox(height: 20),
              const _Title('Ngày khởi hành'),
              const SizedBox(height: 9),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _date == null ? AppColors.border : AppColors.brand,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _date == null
                              ? 'Chọn ngày khởi hành'
                              : DateFormat('dd/MM/yyyy').format(_date!),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _date == null
                                ? AppColors.muted
                                : AppColors.ink,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.calendar_month_outlined,
                        size: 19,
                        color: AppColors.muted,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const _Title('Số lượng khách'),
              const SizedBox(height: 4),
              _GuestRow(
                label: 'Người lớn',
                hint: 'Trên 12 tuổi',
                price: _adultPrice,
                value: _adults,
                min: 1,
                onChanged: (v) => _changeGuests(() => _adults = v),
              ),
              _GuestRow(
                label: 'Trẻ em',
                hint: 'Từ 2 – 11 tuổi',
                price: _childPrice,
                value: _children,
                onChanged: (v) => _changeGuests(() => _children = v),
              ),
              _GuestRow(
                label: 'Em bé',
                hint: 'Dưới 2 tuổi',
                price: _infantPrice,
                value: _infants,
                onChanged: (v) => _changeGuests(() => _infants = v),
              ),
              const SizedBox(height: 18),
              const _Title('Thông tin người đặt'),
              const SizedBox(height: 9),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _contactName,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Họ và tên',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                      ),
                      validator: (v) =>
                          (v?.trim().length ?? 0) < 2 ? 'Nhập họ tên' : null,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Số điện thoại',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                      ),
                      validator: (v) =>
                          !RegExp(
                            r'^0(?:3|5|7|8|9)\d{8}$',
                          ).hasMatch(v?.trim() ?? '')
                          ? 'Số điện thoại không hợp lệ'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _coupon,
                      enabled: _appliedCoupon == null,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) {
                        if (_couponError != null)
                          setState(() => _couponError = null);
                      },
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Mã giảm giá',
                        prefixIcon: const Icon(Icons.sell_outlined, size: 18),
                        errorText: _couponError,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _validatingCoupon
                          ? null
                          : (_appliedCoupon == null
                                ? _applyCoupon
                                : _removeCoupon),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 13),
                      ),
                      child: _validatingCoupon
                          ? const SizedBox.square(
                              dimension: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _appliedCoupon == null
                                      ? Icons.local_offer_outlined
                                      : Icons.close_rounded,
                                  size: 16,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _appliedCoupon == null ? 'Áp dụng' : 'Xóa',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
              if (_appliedCoupon != null) ...[
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 15,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Đã áp dụng mã ${_coupon.text}. Giảm ${_vnd(_discount)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              InkWell(
                onTap: () => setState(() => _accepted = !_accepted),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _accepted ? AppColors.brand : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _accepted
                                ? AppColors.brand
                                : AppColors.border,
                          ),
                        ),
                        child: _accepted
                            ? const Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 9),
                      const Expanded(
                        child: Text(
                          'Tôi đã đọc và đồng ý với chính sách đặt tour và điều khoản hủy tour.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.45,
                            color: AppColors.muted,
                          ),
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: AppColors.borderLight)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .05),
                blurRadius: 14,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tổng thanh toán',
                      style: TextStyle(fontSize: 10, color: AppColors.muted),
                    ),
                    if (_discount > 0)
                      Text(
                        'Giảm ${_vnd(_discount)}',
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.success,
                        ),
                      ),
                    Text(
                      _vnd(_finalTotal),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 150,
                height: 48,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox.square(
                          dimension: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Tiếp tục',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingSteps extends StatelessWidget {
  const _BookingSteps();
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const _Step(number: '1', label: 'Thông tin', active: true),
      Expanded(
        child: Container(
          height: 1,
          margin: const EdgeInsets.only(bottom: 17),
          color: AppColors.borderLight,
        ),
      ),
      const _Step(number: '2', label: 'Thanh toán'),
      Expanded(
        child: Container(
          height: 1,
          margin: const EdgeInsets.only(bottom: 17),
          color: AppColors.borderLight,
        ),
      ),
      const _Step(number: '3', label: 'Xác nhận'),
    ],
  );
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.label, this.active = false});
  final String number, label;
  final bool active;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 68,
    child: Column(
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: active ? AppColors.brand : AppColors.borderLight,
          child: Text(
            number,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.subtle,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppColors.brand : AppColors.subtle,
          ),
        ),
      ],
    ),
  );
}

class _SelectedTour extends StatelessWidget {
  const _SelectedTour({
    required this.name,
    required this.destination,
    required this.image,
    required this.duration,
  });
  final String name, destination, image, duration;
  @override
  Widget build(BuildContext context) => Container(
    height: 86,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: AppColors.borderLight),
    ),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            width: 92,
            height: 68,
            child: image.isEmpty
                ? const ColoredBox(color: AppColors.borderLight)
                : CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                destination,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 13,
                    color: AppColors.subtle,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    duration,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w800,
      color: AppColors.ink,
    ),
  );
}

class _GuestRow extends StatelessWidget {
  const _GuestRow({
    required this.label,
    required this.hint,
    required this.price,
    required this.value,
    required this.onChanged,
    this.min = 0,
  });
  final String label, hint;
  final double price;
  final int value, min;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 63,
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$hint · ${_vnd(price)}',
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
            ],
          ),
        ),
        _CountButton(
          icon: Icons.remove_rounded,
          enabled: value > min,
          onTap: () => onChanged(value - 1),
        ),
        SizedBox(
          width: 38,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        _CountButton(
          icon: Icons.add_rounded,
          onTap: () => onChanged(value + 1),
        ),
      ],
    ),
  );
}

class _CountButton extends StatelessWidget {
  const _CountButton({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 32,
    height: 32,
    child: OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      child: Icon(icon, size: 15),
    ),
  );
}

double _money(dynamic value) => double.tryParse('${value ?? 0}') ?? 0;
int _integer(dynamic value) =>
    int.tryParse('${value ?? 0}') ?? _money(value).round();
String _vnd(double value) =>
    '${NumberFormat.decimalPattern('vi').format(value)}đ';
String _destination(Map<String, dynamic> tour) {
  final raw = tour['destination'];
  if (raw is Map) return '${raw['name'] ?? raw['title'] ?? ''}';
  final list = tour['destinations'] ?? tour['tour_destinations'];
  if (list is List)
    return list
        .map(
          (item) =>
              item is Map ? '${item['name'] ?? item['title'] ?? ''}' : '$item',
        )
        .where((value) => value.isNotEmpty)
        .join(' • ');
  return '${tour['destination_name'] ?? raw ?? 'Việt Nam'}';
}
