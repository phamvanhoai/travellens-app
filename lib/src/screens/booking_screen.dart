import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../core/network/api_client.dart';

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
          content: Text('Complete the form and accept the policies.'),
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
              if (coupon.text.trim().isNotEmpty)
                'coupon_code': coupon.text.trim(),
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
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Book this tour')),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Tour #${widget.tourId}',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: contactName,
            decoration: const InputDecoration(labelText: 'Contact name'),
            validator: (v) =>
                (v?.trim().length ?? 0) < 2 ? 'Enter contact name' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Contact phone'),
            validator: (v) =>
                !RegExp(r'^\+?[0-9\s-]{8,15}$').hasMatch(v?.trim() ?? '')
                ? 'Enter a valid phone number'
                : null,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final selected = await showDatePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 730)),
                initialDate:
                    date ?? DateTime.now().add(const Duration(days: 1)),
              );
              if (selected != null) setState(() => date = selected);
            },
            icon: const Icon(Icons.calendar_month),
            label: Text(
              date == null
                  ? 'Select travel date'
                  : DateFormat.yMMMMd().format(date!),
            ),
          ),
          const SizedBox(height: 16),
          _Counter(
            label: 'Adults',
            value: adults,
            min: 1,
            onChanged: (v) => setState(() => adults = v),
          ),
          _Counter(
            label: 'Children',
            value: children,
            onChanged: (v) => setState(() => children = v),
          ),
          _Counter(
            label: 'Infants',
            value: infants,
            onChanged: (v) => setState(() => infants = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: coupon,
            decoration: const InputDecoration(
              labelText: 'Coupon code (optional)',
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: accepted,
            onChanged: (v) => setState(() => accepted = v ?? false),
            title: const Text(
              'I agree to the booking and cancellation policies',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: loading ? null : submit,
            child: loading
                ? const CircularProgressIndicator()
                : const Text('Continue to payment'),
          ),
        ],
      ),
    ),
  );
}

class _Counter extends StatelessWidget {
  const _Counter({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
  });
  final String label;
  final int value, min;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
        IconButton(
          onPressed: () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    ),
  );
}
