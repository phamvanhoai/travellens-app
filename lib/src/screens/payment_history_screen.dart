import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/network/api_client.dart';
import '../design/app_colors.dart';

class PaymentHistoryScreen extends ConsumerStatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  ConsumerState<PaymentHistoryScreen> createState() =>
      _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends ConsumerState<PaymentHistoryScreen> {
  static const _pageSize = 10;
  static const _statuses = [
    '',
    'pending',
    'paid',
    'failed',
    'expired',
    'refunded',
  ];

  final _searchController = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _items = [];
  String _status = '';
  String? _error;
  bool _loading = true;
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref
          .read(dioProvider)
          .get(
            '/payments',
            queryParameters: {
              'page': _page,
              'limit': _pageSize,
              if (_searchController.text.trim().isNotEmpty)
                'search': _searchController.text.trim(),
              if (_status.isNotEmpty) 'status': _status,
            },
          );
      final result = _parsePayments(response.data);
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _total = result.total;
        _totalPages = math.max(1, result.totalPages);
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _items = [];
          _error = apiError(error);
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _search(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _page = 1;
      _load();
    });
  }

  void _changePage(int page) {
    if (page < 1 || page > _totalPages || page == _page) return;
    setState(() => _page = page);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Lịch sử thanh toán'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const Text(
              'Các giao dịch của bạn',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 20,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Theo dõi trạng thái thanh toán cho những tour đã đặt.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Mã thanh toán, booking, tour...',
                prefixIcon: const Icon(Icons.search_rounded, size: 21),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _page = 1;
                          setState(() {});
                          _load();
                        },
                        icon: const Icon(Icons.close_rounded, size: 19),
                      ),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _statuses.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  final value = _statuses[index];
                  final selected = value == _status;
                  return ChoiceChip(
                    label: Text(_statusLabel(value)),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        _status = value;
                        _page = 1;
                      });
                      _load();
                    },
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    selectedColor: AppColors.brand,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: selected ? AppColors.brand : AppColors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              _ErrorCard(message: _error!, onRetry: _load)
            else if (_loading)
              const SizedBox(
                height: 320,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_items.isEmpty)
              const _EmptyPayments()
            else ...[
              ..._items.map((item) => _PaymentCard(payment: item)),
              if (_totalPages > 1) ...[
                const SizedBox(height: 6),
                _Pagination(
                  page: _page,
                  totalPages: _totalPages,
                  total: _total,
                  onChange: _changePage,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});
  final Map<String, dynamic> payment;

  @override
  Widget build(BuildContext context) {
    final booking = _map(payment['booking']);
    final nestedTour = _map(booking['tour']);
    final tour = _map(payment['tour']);
    final id = payment['payment_id'] ?? payment['id'] ?? '-';
    final code = '${payment['payment_code'] ?? payment['code'] ?? '#$id'}';
    final bookingId =
        payment['booking_id'] ?? booking['booking_id'] ?? booking['id'] ?? '-';
    final bookingCode =
        '${booking['booking_code'] ?? booking['code'] ?? '#$bookingId'}';
    final tourName =
        '${booking['tour_name'] ?? nestedTour['name'] ?? nestedTour['title'] ?? tour['name'] ?? tour['title'] ?? 'Tour du lịch'}';
    final amount = double.tryParse('${payment['amount'] ?? 0}') ?? 0;
    final currency = '${payment['currency'] ?? 'VND'}';
    final bank = '${payment['bank_name'] ?? 'SePay'}';
    final transaction =
        '${payment['transaction_code'] ?? payment['transfer_content'] ?? '-'}';
    final status =
        '${payment['status'] ?? payment['payment_status'] ?? 'pending'}'
            .toLowerCase();
    final created = _date(payment['created_at'] ?? payment['createdAt']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.credit_card_rounded,
                  color: Color(0xFF7C3AED),
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$bookingCode${created.isEmpty ? '' : ' • $created'}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tourName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 11),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _Info(
                  icon: Icons.account_balance_rounded,
                  label: 'Ngân hàng',
                  value: bank,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Số tiền',
                    style: TextStyle(fontSize: 10.5, color: AppColors.muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _money(amount, currency),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brand,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Info(
            icon: Icons.receipt_long_rounded,
            label: 'Mã giao dịch',
            value: transaction,
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 15, color: AppColors.subtle),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          '$label: ',
          style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
        ),
      ),
      Flexible(
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ),
    ],
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      'paid' => (AppColors.successSoft, const Color(0xFF047857)),
      'failed' || 'expired' => (AppColors.errorSoft, const Color(0xFFDC2626)),
      'refunded' => (const Color(0xFFEFF6FF), const Color(0xFF2563EB)),
      _ => (const Color(0xFFFFFBEB), const Color(0xFFD97706)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: foreground,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.totalPages,
    required this.total,
    required this.onChange,
  });
  final int page, totalPages, total;
  final ValueChanged<int> onChange;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '$total giao dịch · Trang $page/$totalPages',
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
          ),
        ),
        _PageButton(
          icon: Icons.chevron_left_rounded,
          enabled: page > 1,
          onTap: () => onChange(page - 1),
        ),
        const SizedBox(width: 7),
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            '$page',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 7),
        _PageButton(
          icon: Icons.chevron_right_rounded,
          enabled: page < totalPages,
          onTap: () => onChange(page + 1),
        ),
      ],
    ),
  );
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 34,
    height: 34,
    child: OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 34),
        padding: EdgeInsets.zero,
      ),
      child: Icon(icon, size: 17),
    ),
  );
}

class _EmptyPayments extends StatelessWidget {
  const _EmptyPayments();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 56),
    child: Column(
      children: [
        Icon(Icons.receipt_long_outlined, size: 46, color: AppColors.subtle),
        SizedBox(height: 12),
        Text(
          'Không tìm thấy giao dịch',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 4),
        Text(
          'Hãy thử từ khóa hoặc trạng thái khác.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
      ],
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.errorSoft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.error,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Thử lại'),
        ),
      ],
    ),
  );
}

({List<Map<String, dynamic>> items, int totalPages, int total}) _parsePayments(
  dynamic body,
) {
  final root = body is Map
      ? Map<String, dynamic>.from(body)
      : <String, dynamic>{};
  dynamic data = root['data'] ?? body;
  dynamic rawItems;
  if (data is List) {
    rawItems = data;
  } else if (data is Map) {
    rawItems = data['payments'] ?? data['data'];
  }
  final items = rawItems is List
      ? rawItems
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
      : <Map<String, dynamic>>[];
  dynamic rawPagination = root['pagination'];
  if (rawPagination == null && data is Map)
    rawPagination = data['pagination'] ?? data['meta'];
  final pagination = _map(rawPagination);
  final total =
      int.tryParse(
        '${pagination['total'] ?? pagination['total_items'] ?? items.length}',
      ) ??
      items.length;
  final totalPages =
      int.tryParse(
        '${pagination['totalPages'] ?? pagination['total_pages'] ?? pagination['last_page'] ?? 1}',
      ) ??
      1;
  return (items: items, totalPages: totalPages, total: total);
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

String _statusLabel(String value) => switch (value.toLowerCase()) {
  '' => 'Tất cả',
  'pending' => 'Đang chờ',
  'paid' => 'Đã thanh toán',
  'failed' => 'Thất bại',
  'expired' => 'Hết hạn',
  'refunded' => 'Đã hoàn tiền',
  _ => value,
};

String _money(double value, String currency) {
  if (currency.toUpperCase() == 'VND')
    return '${NumberFormat('#,##0', 'vi_VN').format(value)} ₫';
  return NumberFormat.currency(name: currency, symbol: currency).format(value);
}

String _date(dynamic value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  return date == null ? '' : DateFormat('dd/MM/yyyy').format(date);
}
