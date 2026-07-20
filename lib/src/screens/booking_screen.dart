import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../core/network/api_client.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.tourId});
  final int tourId;
  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  final form = GlobalKey<FormState>(),
      contactName = TextEditingController(),
      phone = TextEditingController(),
      coupon = TextEditingController();
  DateTime? date;
  int adults = 1, children = 0, infants = 0;
  bool loading = false, accepted = false;

  @override
  void dispose() {
    contactName.dispose();
    phone.dispose();
    coupon.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate() || date == null || !accepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng điền đầy đủ thông tin và đồng ý điều khoản.'),
        ),
      );
      return;
    }
    setState(() => loading = true);
    try {
      final passengers = <Map<String, dynamic>>[];
      for (var i = 0; i < adults; i++)
        passengers.add({
          'passenger_name': contactName.text.trim(),
          'age_category': 'adult',
        });
      for (var i = 0; i < children; i++)
        passengers.add({
          'passenger_name': contactName.text.trim(),
          'age_category': 'child',
        });
      for (var i = 0; i < infants; i++)
        passengers.add({
          'passenger_name': contactName.text.trim(),
          'age_category': 'infant',
        });
      final response = await ref
          .read(dioProvider)
          .post(
            '/bookings',
            data: {
              'tour_id': widget.tourId,
              'contact_phone': phone.text.trim(),
              'travel_date': DateFormat('yyyy-MM-dd').format(date!),
              if (coupon.text.trim().isNotEmpty) 'coupon_code': coupon.text.trim(),
              'passengers': passengers,
            },
          );
      final data = unwrap(response.data);
      final id = data is Map ? data['booking_id'] ?? data['id'] : null;
      if (mounted)
        context.go(id == null ? '/bookings' : '/payment/checkout?bookingId=$id');
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(e))));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    appBar: AppBar(
      title: const Text('Đặt tour'),
      backgroundColor: Colors.white,
    ),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // Header
          Text(
            'Thông tin đặt tour',
            style: AppTextStyles.h1.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 6),
          Text(
            'Hoàn tất thông tin cho tour #${widget.tourId}.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 24),

          // Step 1: Contact
          _SectionCard(
            step: '1',
            title: 'Thông tin người đặt',
            subtitle: 'Thông tin dùng để xác nhận booking',
            icon: Icons.person_outline_rounded,
            child: Column(
              children: [
                TextFormField(
                  controller: contactName,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Contact name',
                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                  ),
                  validator: (v) =>
                      (v?.trim().length ?? 0) < 2 ? 'Enter contact name' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Contact phone',
                    prefixIcon: Icon(Icons.phone_outlined, size: 20),
                  ),
                  validator: (v) =>
                      !RegExp(r'^\+?[0-9\s-]{8,15}$').hasMatch(v?.trim() ?? '')
                      ? 'Enter a valid phone number'
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Step 2: Date & travelers
          _SectionCard(
            step: '2',
            title: 'Ngày khởi hành & số khách',
            subtitle: 'Chọn ngày đi và số lượng hành khách',
            icon: Icons.calendar_today_outlined,
            child: Column(
              children: [
                // Date picker button
                InkWell(
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                      initialDate: date ?? DateTime.now().add(const Duration(days: 1)),
                    );
                    if (selected != null) setState(() => date = selected);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: date != null ? AppColors.brand : AppColors.border,
                        width: date != null ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 20,
                          color: date != null ? AppColors.brand : AppColors.muted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            date == null
                                ? 'Select travel date'
                                : DateFormat.yMMMMd().format(date!),
                            style: AppTextStyles.body.copyWith(
                              color: date == null ? AppColors.muted : AppColors.ink,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down_rounded,
                          color: AppColors.muted,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _Counter(
                  label: 'Người lớn',
                  hint: 'Age 12+',
                  value: adults,
                  min: 1,
                  onChanged: (v) => setState(() => adults = v),
                ),
                const Divider(height: 24),
                _Counter(
                  label: 'Trẻ em',
                  hint: 'Ages 2–11',
                  value: children,
                  onChanged: (v) => setState(() => children = v),
                ),
                const Divider(height: 24),
                _Counter(
                  label: 'Em bé',
                  hint: 'Under 2 years',
                  value: infants,
                  onChanged: (v) => setState(() => infants = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Step 3: Coupon & policy
          _SectionCard(
            step: '3',
            title: 'Mã giảm giá & điều khoản',
            subtitle: 'Áp dụng ưu đãi và kiểm tra chính sách',
            icon: Icons.local_offer_outlined,
            child: Column(
              children: [
                TextField(
                  controller: coupon,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Coupon code (optional)',
                    prefixIcon: Icon(Icons.sell_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => setState(() => accepted = !accepted),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: accepted ? AppColors.brand : Colors.white,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: accepted ? AppColors.brand : AppColors.border,
                            width: 1.5,
                          ),
                        ),
                        child: accepted
                            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'I agree to the booking and cancellation policies.',
                          style: AppTextStyles.body.copyWith(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Submit button
          FilledButton(
            onPressed: loading ? null : submit,
            child: loading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Tiếp tục'),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });
  final String step, title, subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    step,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.label),
                    Text(subtitle, style: AppTextStyles.caption),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ],
    ),
  );
}

class _Counter extends StatelessWidget {
  const _Counter({
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
    this.min = 0,
  });
  final String label, hint;
  final int value, min;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.label),
            Text(hint, style: AppTextStyles.caption),
          ],
        ),
      ),
      Row(
        children: [
          _CounterBtn(
            icon: Icons.remove_rounded,
            enabled: value > min,
            onTap: () => onChanged(value - 1),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: AppTextStyles.h4,
            ),
          ),
          _CounterBtn(
            icon: Icons.add_rounded,
            enabled: true,
            onTap: () => onChanged(value + 1),
          ),
        ],
      ),
    ],
  );
}

class _CounterBtn extends StatelessWidget {
  const _CounterBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: enabled ? AppColors.brand.withValues(alpha: .1) : AppColors.borderLight,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.brand : AppColors.subtle,
        ),
      ),
    ),
  );
}
