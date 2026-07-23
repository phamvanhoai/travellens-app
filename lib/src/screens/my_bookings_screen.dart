import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../core/network/api_client.dart';
import '../design/app_colors.dart';
import '../design/app_widgets.dart';
import '../widgets/app_back_button.dart';

class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen> {
  static const _tabs = ['Tất cả', 'Sắp tới', 'Đã hoàn thành', 'Đã hủy'];
  List<Map<String, dynamic>> _items = [];
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _loading = true;
  String? _error;
  int _tab = 0;
  int _page = 1;
  int _totalPages = 1;
  int _totalItems = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = _searchController.text.trim();
      late final List<Map<String, dynamic>> pageItems;
      late final (int, int) pagination;

      if (_tab == 0 && query.isEmpty) {
        final response = await ref
            .read(dioProvider)
            .get('/bookings', queryParameters: {'page': _page, 'limit': 5});
        final body = response.data;
        pagination = _bookingPagination(body);
        pageItems = unwrapList(body, ['bookings']);
      } else {
        final allItems = await _loadAllBookingPages();
        final filtered = allItems.where((item) {
          final matchesTab = switch (_tab) {
            1 => !_isCompleted(item) && !_isCancelled(item),
            2 => _isCompleted(item),
            3 => _isCancelled(item),
            _ => true,
          };
          if (!matchesTab || query.isEmpty) return matchesTab;
          final keyword = query.toLowerCase();
          return _bookingCode(item).toLowerCase().contains(keyword) ||
              _tourName(item).toLowerCase().contains(keyword) ||
              '${item['contact_phone'] ?? ''}'.toLowerCase().contains(keyword);
        }).toList();
        final totalPages = math.max(1, (filtered.length / 5).ceil());
        if (_page > totalPages) _page = totalPages;
        final start = (_page - 1) * 5;
        pageItems = filtered.skip(start).take(5).toList();
        pagination = (totalPages, filtered.length);
      }
      final items = await _loadBookingDetails(pageItems);
      if (mounted) {
        setState(() {
          _items = items;
          _totalPages = math.max(1, pagination.$1);
          _totalItems = pagination.$2;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadAllBookingPages() async {
    final dio = ref.read(dioProvider);
    final first = await dio.get(
      '/bookings',
      queryParameters: {'page': 1, 'limit': 100},
    );
    final items = unwrapList(first.data, ['bookings']);
    final totalPages = _bookingPagination(first.data).$1;
    for (var page = 2; page <= totalPages; page++) {
      final response = await dio.get(
        '/bookings',
        queryParameters: {'page': page, 'limit': 100},
      );
      items.addAll(unwrapList(response.data, ['bookings']));
    }
    return items;
  }

  Future<List<Map<String, dynamic>>> _loadBookingDetails(
    List<Map<String, dynamic>> items,
  ) async {
    return Future.wait(
      items.map((item) async {
        final id = _bookingId(item);
        if (id <= 0) return item;
        try {
          final response = await ref.read(dioProvider).get('/bookings/$id');
          dynamic data = unwrap(response.data);
          if (data is! Map) return item;
          if (data['booking'] is Map) {
            final detail = Map<String, dynamic>.from(data['booking']);
            final passengers =
                data['passengers'] ??
                data['booking_details'] ??
                data['bookingDetails'] ??
                data['BookingDetail'] ??
                data['BookingDetails'] ??
                data['details'];
            final review =
                data['review'] ??
                data['Review'] ??
                data['tour_review'] ??
                data['tourReview'];
            if (passengers != null) detail['passengers'] = passengers;
            if (review != null) detail['review'] = review;
            return {...item, ...detail};
          }
          return {...item, ...Map<String, dynamic>.from(data)};
        } catch (_) {
          return item;
        }
      }),
    );
  }

  void _search(String _) {
    _searchDebounce?.cancel();
    setState(() {});
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _page = 1;
      _load();
    });
  }

  void _changePage(int value) {
    if (value < 1 || value > _totalPages || value == _page) return;
    setState(() => _page = value);
    _load();
  }

  List<Map<String, dynamic>> get _visible => _items;

  void _changeTab(int value) {
    if (value == _tab) return;
    setState(() {
      _tab = value;
      _page = 1;
      _items = [];
    });
    _load();
  }

  void _showDetail(Map<String, dynamic> booking) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BookingDetailSheet(booking: booking),
    );
  }

  Future<void> _cancel(Map<String, dynamic> booking) async {
    final id = _bookingId(booking);
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hủy booking?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Yêu cầu hủy sẽ được xử lý theo chính sách của tour.'),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Lý do (không bắt buộc)',
                hintText: 'Kế hoạch của tôi đã thay đổi…',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, reasonController.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Hủy booking'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null) return;
    try {
      await ref
          .read(dioProvider)
          .patch(
            '/bookings/$id/cancel',
            data: {'reason': reason.isEmpty ? null : reason},
          );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(e))));
      }
    }
  }

  Future<void> _review(Map<String, dynamic> booking) async {
    final existing = _bookingReview(booking);
    final result = await showDialog<_ReviewResult>(
      context: context,
      builder: (_) => _BookingReviewDialog(
        tourName: _tourName(booking),
        initialRating: int.tryParse('${existing?['rating'] ?? 5}') ?? 5,
        initialComment: '${existing?['comment'] ?? ''}',
        editing: existing != null,
      ),
    );
    if (result == null) return;
    try {
      final id = _bookingId(booking);
      final data = {'rating': result.rating, 'comment': result.comment};
      dynamic response;
      if (existing == null) {
        try {
          response = await ref
              .read(dioProvider)
              .post('/bookings/$id/review', data: data);
        } on DioException catch (error) {
          if (error.response?.statusCode != 409) rethrow;
          response = await ref
              .read(dioProvider)
              .put('/bookings/$id/review', data: data);
        }
      } else {
        response = await ref
            .read(dioProvider)
            .put('/bookings/$id/review', data: data);
      }
      dynamic saved = unwrap(response.data);
      if (saved is Map && saved['review'] is Map) saved = saved['review'];
      final review = saved is Map
          ? Map<String, dynamic>.from(saved)
          : <String, dynamic>{};
      review['rating'] ??= result.rating;
      review['comment'] ??= result.comment;
      if (mounted) {
        setState(() {
          _items = _items.map((item) {
            if (_bookingId(item) != id) return item;
            return {...item, 'review': review};
          }).toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              existing == null
                  ? 'Đã gửi đánh giá tour.'
                  : 'Đã cập nhật đánh giá.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      leading: const AppBackButton(fallbackRoute: '/account'),
      title: const Text('Booking của tôi'),
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded, size: 20),
        ),
        const SizedBox(width: 6),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
                itemCount: _tabs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) => _BookingTab(
                  label: _tabs[index],
                  selected: _tab == index,
                  onTap: () => _changeTab(index),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
              child: SizedBox(
                height: 44,
                child: TextField(
                  controller: _searchController,
                  onChanged: _search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Tìm mã booking, tên tour...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 19),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              _page = 1;
                              _load();
                            },
                            icon: const Icon(Icons.close_rounded, size: 17),
                          ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ),
          if (_loading)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              sliver: SliverList.separated(
                itemCount: 5,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, _) => const _BookingSkeleton(),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: AppErrorState(error: _error!, onRetry: _load),
            )
          else if (_visible.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.card_travel_outlined,
                title: 'Chưa có booking',
                subtitle: 'Các tour bạn đặt sẽ xuất hiện tại đây.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              sliver: SliverList.separated(
                itemCount: _visible.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final booking = _visible[index];
                  return _BookingCard(
                    booking: booking,
                    onDetail: () => _showDetail(booking),
                    onPay: () => context.push(
                      '/payment/checkout?bookingId=${_bookingId(booking)}',
                    ),
                    onCancel: () => _cancel(booking),
                    onReview: () => _review(booking),
                  );
                },
              ),
            ),
          if (!_loading && _error == null && _totalPages > 1)
            SliverToBoxAdapter(
              child: _BookingPagination(
                page: _page,
                totalPages: _totalPages,
                totalItems: _totalItems,
                onChanged: _changePage,
              ),
            ),
        ],
      ),
    ),
  );
}

class _ReviewResult {
  const _ReviewResult(this.rating, this.comment);
  final int rating;
  final String comment;
}

class _BookingReviewDialog extends StatefulWidget {
  const _BookingReviewDialog({
    required this.tourName,
    required this.initialRating,
    required this.initialComment,
    required this.editing,
  });
  final String tourName;
  final int initialRating;
  final String initialComment;
  final bool editing;

  @override
  State<_BookingReviewDialog> createState() => _BookingReviewDialogState();
}

class _BookingReviewDialogState extends State<_BookingReviewDialog> {
  late final TextEditingController _comment;
  late int _rating;
  String? _commentError;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
    _comment = TextEditingController(text: widget.initialComment);
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _comment.text.trim();
    if (value.isEmpty) {
      setState(() => _commentError = 'Vui lòng nhập nội dung đánh giá.');
      return;
    }
    Navigator.of(context).pop(_ReviewResult(_rating, value));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.editing ? 'Sửa đánh giá' : 'Đánh giá tour'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.tourName,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            5,
            (index) => IconButton(
              onPressed: () => setState(() => _rating = index + 1),
              icon: Icon(
                Icons.star_rounded,
                color: index < _rating ? AppColors.gold : AppColors.border,
              ),
            ),
          ),
        ),
        TextField(
          controller: _comment,
          minLines: 3,
          maxLines: 5,
          onChanged: (_) {
            if (_commentError != null) setState(() => _commentError = null);
          },
          decoration: InputDecoration(
            hintText: 'Chia sẻ trải nghiệm của bạn...',
            errorText: _commentError,
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Đóng'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Gửi đánh giá')),
    ],
  );
}

class _BookingSkeleton extends StatelessWidget {
  const _BookingSkeleton();

  @override
  Widget build(BuildContext context) => Container(
    height: 190,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: AppColors.borderLight),
    ),
    child: const Column(
      children: [
        Row(
          children: [
            AppShimmerBox(width: 72, height: 10, borderRadius: 5),
            Spacer(),
            AppShimmerBox(width: 68, height: 20, borderRadius: 10),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            AppShimmerBox(width: 88, height: 76, borderRadius: 9),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppShimmerBox(
                    width: double.infinity,
                    height: 12,
                    borderRadius: 6,
                  ),
                  SizedBox(height: 9),
                  AppShimmerBox(width: 94, height: 9, borderRadius: 5),
                  SizedBox(height: 7),
                  AppShimmerBox(width: 58, height: 9, borderRadius: 5),
                ],
              ),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppShimmerBox(width: 66, height: 11, borderRadius: 5),
                SizedBox(height: 10),
                AppShimmerBox(width: 58, height: 26, borderRadius: 8),
              ],
            ),
          ],
        ),
        SizedBox(height: 12),
        AppShimmerBox(width: double.infinity, height: 38, borderRadius: 10),
      ],
    ),
  );
}

class _BookingPagination extends StatelessWidget {
  const _BookingPagination({
    required this.page,
    required this.totalPages,
    required this.totalItems,
    required this.onChanged,
  });
  final int page;
  final int totalPages;
  final int totalItems;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 2, 18, 24),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '$totalItems booking · Trang $page/$totalPages',
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
          ),
        ),
        _PageButton(
          icon: Icons.chevron_left_rounded,
          enabled: page > 1,
          onTap: () => onChanged(page - 1),
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
          onTap: () => onChanged(page + 1),
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

class _BookingTab extends StatelessWidget {
  const _BookingTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.brandDark : Colors.white,
    borderRadius: BorderRadius.circular(17),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? AppColors.brandDark : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.muted,
          ),
        ),
      ),
    ),
  );
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.onDetail,
    required this.onPay,
    required this.onCancel,
    required this.onReview,
  });
  final Map<String, dynamic> booking;
  final VoidCallback onDetail;
  final VoidCallback onPay;
  final VoidCallback onCancel;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final status = _bookingStatus(booking);
    final payment = _paymentStatus(booking);
    final cancelled = _isCancelled(booking);
    final completed = _isCompleted(booking);
    final paid = payment == 'paid';
    final canPay = _canPay(booking);
    final canCancel = _canCancel(booking);
    final canReview = _canReview(booking);
    final image = AppConfig.assetUrl(_bookingImage(booking));
    final date = _bookingDate(booking);
    final passengers = _passengers(booking).length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                _bookingCode(booking),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
              const Spacer(),
              _StatusChip(
                status: cancelled
                    ? status
                    : completed
                    ? 'completed'
                    : status == 'confirmed'
                    ? 'confirmed'
                    : paid
                    ? 'paid'
                    : status,
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: SizedBox(
                  width: 88,
                  height: 76,
                  child: image.isEmpty
                      ? const ColoredBox(
                          color: AppColors.borderLight,
                          child: Icon(
                            Icons.landscape_outlined,
                            color: AppColors.subtle,
                          ),
                        )
                      : CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tourName(booking),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_outlined,
                          size: 13,
                          color: AppColors.subtle,
                        ),
                        const SizedBox(width: 4),
                        Text(_formatDate(date), style: _metaStyle),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.groups_outlined,
                          size: 13,
                          color: AppColors.subtle,
                        ),
                        const SizedBox(width: 4),
                        Text('$passengers khách', style: _metaStyle),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _vnd(_bookingAmount(booking)),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (canReview)
                    _SmallAction(
                      label: _bookingReview(booking) == null
                          ? 'Đánh giá'
                          : 'Sửa đánh giá',
                      icon: Icons.star_outline_rounded,
                      onTap: onReview,
                    )
                  else if (canPay)
                    _SmallAction(
                      label: 'Thanh toán',
                      icon: Icons.qr_code_rounded,
                      filled: true,
                      onTap: onPay,
                    )
                  else if (canCancel)
                    _SmallAction(
                      label: 'Hủy',
                      icon: Icons.close_rounded,
                      onTap: onCancel,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDetail,
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Chi tiết'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    textStyle: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookingDetailSheet extends StatelessWidget {
  const _BookingDetailSheet({required this.booking});

  final Map<String, dynamic> booking;

  @override
  Widget build(BuildContext context) {
    final passengers = _passengers(booking);
    final amount = _bookingAmount(booking);
    final original =
        double.tryParse(
          '${booking['original_amount'] ?? passengers.fold<num>(0, (sum, item) => sum + (item is Map ? (double.tryParse('${item['price'] ?? 0}') ?? 0) : 0))}',
        ) ??
        amount;
    final discount =
        double.tryParse('${booking['discount_amount'] ?? ''}') ??
        math.max(0, original - amount);
    final created =
        booking['created_at'] ??
        booking['booking_date'] ??
        booking['booked_at'];
    final contact = '${booking['contact_phone'] ?? booking['phone'] ?? '-'}';
    final method = '${booking['payment_method'] ?? '-'}';

    return DraggableScrollableSheet(
      initialChildSize: .88,
      minChildSize: .55,
      maxChildSize: .96,
      expand: false,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: CustomScrollView(
          controller: controller,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CHI TIẾT BOOKING',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: AppColors.brand,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _bookingCode(booking),
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Đã tạo ${_formatDate(created)}',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'Đóng',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, size: 19),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = (constraints.maxWidth - 10) / 2;
                        final items = [
                          _DetailInfo(
                            label: 'Tour',
                            value: _tourName(booking),
                            icon: Icons.card_travel_outlined,
                          ),
                          _DetailInfo(
                            label: 'Khởi hành',
                            value: _formatDate(_bookingDate(booking)),
                            icon: Icons.calendar_month_outlined,
                          ),
                          _DetailInfo(
                            label: 'Trạng thái booking',
                            icon: Icons.fact_check_outlined,
                            child: _StatusChip(status: _bookingStatus(booking)),
                          ),
                          _DetailInfo(
                            label: 'Thanh toán',
                            icon: Icons.payments_outlined,
                            child: _StatusChip(status: _paymentStatus(booking)),
                          ),
                          _DetailInfo(
                            label: 'Số điện thoại',
                            value: contact,
                            icon: Icons.phone_outlined,
                          ),
                          _DetailInfo(
                            label: 'Phương thức',
                            value: method,
                            icon: Icons.account_balance_wallet_outlined,
                          ),
                        ];
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: items
                              .map(
                                (item) => SizedBox(width: width, child: item),
                              )
                              .toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Hành khách',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentLight,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '${passengers.length} người',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.brand,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (passengers.isEmpty)
                      const _EmptyPassengers()
                    else
                      ...passengers.asMap().entries.map(
                        (entry) => _PassengerItem(
                          passenger: entry.value is Map
                              ? Map<String, dynamic>.from(entry.value)
                              : const {},
                          index: entry.key,
                        ),
                      ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _PriceLine(label: 'Giá gốc', amount: original),
                          const SizedBox(height: 10),
                          _PriceLine(
                            label: booking['coupon_id'] == null
                                ? 'Giảm giá'
                                : 'Mã giảm giá #${booking['coupon_id']}',
                            amount: -discount,
                            muted: true,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(height: 1),
                          ),
                          _PriceLine(
                            label: 'Tổng thanh toán',
                            amount: amount,
                            total: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailInfo extends StatelessWidget {
  const _DetailInfo({
    required this.label,
    required this.icon,
    this.value,
    this.child,
  });

  final String label;
  final IconData icon;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 90),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: AppColors.borderLight),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.brand),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9, color: AppColors.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        child ??
            Text(
              value ?? '-',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
      ],
    ),
  );
}

class _PassengerItem extends StatelessWidget {
  const _PassengerItem({required this.passenger, required this.index});

  final Map<String, dynamic> passenger;
  final int index;

  @override
  Widget build(BuildContext context) {
    final category =
        '${passenger['age_category'] ?? passenger['ageCategory'] ?? '-'}';
    final price = double.tryParse('${passenger['price'] ?? 0}') ?? 0;
    final seat = '${passenger['seat_number'] ?? '-'}';
    final request = '${passenger['special_request'] ?? '-'}';
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.accentLight,
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.brand,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${passenger['passenger_name'] ?? 'Hành khách ${index + 1}'}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_categoryLabel(category)} · Ghế $seat',
                  style: const TextStyle(fontSize: 9.5, color: AppColors.muted),
                ),
                if (request != '-') ...[
                  const SizedBox(height: 4),
                  Text(
                    request,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _vnd(price),
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _EmptyPassengers extends StatelessWidget {
  const _EmptyPassengers();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Text(
      'Chưa có thông tin hành khách.',
      style: TextStyle(fontSize: 10.5, color: AppColors.muted),
    ),
  );
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({
    required this.label,
    required this.amount,
    this.muted = false,
    this.total = false,
  });

  final String label;
  final double amount;
  final bool muted;
  final bool total;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: total ? 12 : 10.5,
            fontWeight: total ? FontWeight.w800 : FontWeight.w600,
            color: total
                ? AppColors.brand
                : muted
                ? AppColors.muted
                : AppColors.ink,
          ),
        ),
      ),
      Text(
        amount < 0 ? '-${_vnd(amount.abs())}' : _vnd(amount),
        style: TextStyle(
          fontSize: total ? 14 : 10.5,
          fontWeight: total ? FontWeight.w900 : FontWeight.w700,
          color: total ? AppColors.brand : AppColors.ink,
        ),
      ),
    ],
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final cancelled = const {
      'cancelled',
      'canceled',
      'expired',
      'refunded',
      'rejected',
    }.contains(status);
    final color =
        status == 'completed' || status == 'paid' || status == 'confirmed'
        ? AppColors.success
        : cancelled
        ? AppColors.error
        : AppColors.gold;
    final label = status == 'completed'
        ? 'Đã hoàn thành'
        : status == 'confirmed'
        ? 'Đã xác nhận'
        : status == 'waiting_manual_confirmation'
        ? 'Chờ xác nhận'
        : status == 'paid'
        ? 'Đã thanh toán'
        : status == 'unpaid'
        ? 'Chưa thanh toán'
        : status == 'failed'
        ? 'Thanh toán lỗi'
        : status == 'pending'
        ? 'Đang chờ'
        : cancelled
        ? 'Đã hủy'
        : status == 'cancel_pending'
        ? 'Đang hủy'
        : 'Sắp tới';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 32,
    child: filled
        ? FilledButton.icon(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 9),
            ),
            icon: Icon(icon, size: 13),
            label: Text(label, style: const TextStyle(fontSize: 9)),
          )
        : OutlinedButton.icon(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 9),
            ),
            icon: Icon(icon, size: 13),
            label: Text(label, style: const TextStyle(fontSize: 9)),
          ),
  );
}

const _metaStyle = TextStyle(fontSize: 9, color: AppColors.muted);
int _bookingId(Map item) =>
    int.tryParse('${item['booking_id'] ?? item['id'] ?? 0}') ?? 0;
String _bookingCode(Map item) =>
    '${item['booking_code'] ?? item['code'] ?? 'BK-${_bookingId(item)}'}';
String _bookingStatus(Map item) =>
    '${item['status'] ?? 'pending'}'.toLowerCase();

bool _isCancelled(Map item) => const {
  'cancel_pending',
  'cancelled',
  'canceled',
  'expired',
  'refunded',
  'rejected',
}.contains(_bookingStatus(item));

bool _isCompleted(Map item) => _canReview(item);

bool _canPay(Map item) {
  if (_bookingAmount(item) <= 0) return false;
  final status = _bookingStatus(item);
  if (const {
    'waiting_manual_confirmation',
    'cancel_pending',
    'cancelled',
    'canceled',
    'expired',
    'refunded',
    'completed',
  }.contains(status)) {
    return false;
  }
  return const {'unpaid', 'pending', 'failed'}.contains(_paymentStatus(item));
}

bool _canCancel(Map item) {
  final status = _bookingStatus(item);
  if (const {
    'cancel_pending',
    'cancelled',
    'canceled',
    'expired',
    'refunded',
    'completed',
  }.contains(status)) {
    return false;
  }
  final departure = _departureDate(item);
  if (departure == null) return true;
  final deadline = departure.subtract(const Duration(hours: 24));
  return !DateTime.now().isAfter(deadline);
}

bool _canReview(Map item) {
  final status = _bookingStatus(item);
  if (const {
    'cancel_pending',
    'cancelled',
    'canceled',
    'expired',
    'refunded',
    'rejected',
  }.contains(status)) {
    return false;
  }
  final payment = _paymentStatus(item);
  if (status != 'completed' && payment != 'paid' && payment != 'completed') {
    return false;
  }
  if (status == 'completed') return true;
  final departure = _departureDate(item);
  return departure != null && !departure.isAfter(DateTime.now());
}

DateTime? _departureDate(Map item) {
  final value = _bookingDate(item);
  if (value == null || '$value'.isEmpty) return null;
  return DateTime.tryParse('$value')?.toLocal();
}

String _tourName(Map item) {
  final tour = item['tour_summary'] ?? item['tour'] ?? item['Tour'];
  return '${item['tour_name'] ?? (tour is Map ? tour['name'] ?? tour['title'] : null) ?? 'Tour #${item['tour_id'] ?? ''}'}';
}

String? _bookingImage(Map item) {
  final tour = item['tour_summary'] ?? item['tour'] ?? item['Tour'];
  return item['thumbnail_url'] ??
      (tour is Map
          ? tour['thumbnail_url'] ?? tour['thumbnail'] ?? tour['image_url']
          : null);
}

String _paymentStatus(Map item) {
  final payment =
      item['latest_payment'] ??
      item['latestPayment'] ??
      item['payment'] ??
      item['Payment'] ??
      ((item['payments'] is List && item['payments'].isNotEmpty)
          ? item['payments'].first
          : null);
  return '${payment is Map ? payment['status'] ?? payment['payment_status'] : item['payment_status'] ?? 'unpaid'}'
      .toLowerCase();
}

List _passengers(Map item) {
  final value =
      item['passengers'] ??
      item['booking_details'] ??
      item['bookingDetails'] ??
      item['BookingDetail'] ??
      item['BookingDetails'] ??
      item['details'];
  return value is List ? value : const [];
}

Map? _bookingReview(Map item) {
  final value =
      item['review'] ??
      item['Review'] ??
      item['tour_review'] ??
      item['tourReview'] ??
      ((item['reviews'] is List && item['reviews'].isNotEmpty)
          ? item['reviews'].first
          : null) ??
      ((item['Reviews'] is List && item['Reviews'].isNotEmpty)
          ? item['Reviews'].first
          : null);
  return value is Map ? value : null;
}

double _bookingAmount(Map item) =>
    double.tryParse(
      '${item['total_amount'] ?? item['final_amount'] ?? item['paid_amount'] ?? item['amount'] ?? item['total_price'] ?? 0}',
    ) ??
    0;
dynamic _bookingDate(Map item) =>
    item['preferred_arrival_time'] ??
    item['departure_at'] ??
    item['arrival_time'] ??
    item['travel_date'];
String _formatDate(dynamic value) {
  final date = DateTime.tryParse('${value ?? ''}');
  return date == null
      ? 'Đang cập nhật'
      : DateFormat('dd/MM/yyyy').format(date.toLocal());
}

String _vnd(double value) =>
    '${NumberFormat.decimalPattern('vi').format(value)}đ';

String _categoryLabel(String value) => switch (value.toLowerCase()) {
  'adult' => 'Người lớn',
  'child' => 'Trẻ em',
  'infant' => 'Em bé',
  _ => value,
};

(int, int) _bookingPagination(dynamic body) {
  final root = body is Map ? body : const {};
  final data = root['data'] is Map ? root['data'] as Map : const {};
  final raw =
      root['meta'] ?? root['pagination'] ?? data['meta'] ?? data['pagination'];
  if (raw is! Map) return (1, 0);
  final pages =
      int.tryParse('${raw['total_pages'] ?? raw['totalPages'] ?? 1}') ?? 1;
  final total = int.tryParse('${raw['total'] ?? 0}') ?? 0;
  return (pages, total);
}
