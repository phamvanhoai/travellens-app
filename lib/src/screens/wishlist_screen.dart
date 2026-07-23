import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../core/network/api_client.dart';
import '../design/app_colors.dart';
import '../design/app_widgets.dart';
import '../features/destinations/saved_destinations_controller.dart';
import '../features/tours/saved_tours_controller.dart';

class WishlistScreen extends ConsumerStatefulWidget {
  const WishlistScreen({super.key});

  @override
  ConsumerState<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends ConsumerState<WishlistScreen> {
  static const _pageSize = 6;
  List<Map<String, dynamic>> _items = [];
  int _tab = 0;
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  bool _loading = true;
  String? _error;

  bool get _tours => _tab == 0;

  @override
  void initState() {
    super.initState();
    _load();
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
            _tours ? '/saved/tours' : '/saved/destinations',
            queryParameters: {'page': _page, 'limit': _pageSize},
          );
      final result = _parseSaved(response.data);
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _total = result.total;
        _totalPages = math.max(1, result.totalPages);
      });
    } catch (error) {
      if (mounted) setState(() => _error = apiError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeTab(int value) {
    if (value == _tab) return;
    setState(() {
      _tab = value;
      _page = 1;
      _items = [];
    });
    _load();
  }

  void _changePage(int value) {
    if (value < 1 || value > _totalPages || value == _page) return;
    setState(() => _page = value);
    _load();
  }

  Future<void> _remove(Map<String, dynamic> item) async {
    final id = _id(item, tours: _tours);
    if (id <= 0) return;
    final removed = item;
    final index = _items.indexOf(item);
    setState(() {
      _items.remove(item);
      _total = math.max(0, _total - 1);
    });
    try {
      if (_tours) {
        await ref.read(dioProvider).post('/saved/tours/$id/toggle');
        await ref.read(savedToursProvider.notifier).load(force: true);
      } else {
        await ref.read(dioProvider).post('/saved/destinations/$id/toggle');
        await ref.read(savedDestinationsProvider.notifier).load(force: true);
      }
      if (_items.isEmpty && _page > 1) _page--;
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _items.insert(index.clamp(0, _items.length), removed));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(apiError(error))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    appBar: AppBar(
      title: const Text('Danh sách yêu thích'),
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
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Đã lưu',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Những tour và điểm đến bạn muốn khám phá.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _WishlistTab(
                        label: 'Tour đã lưu',
                        selected: _tab == 0,
                        onTap: () => _changeTab(0),
                      ),
                      const SizedBox(width: 8),
                      _WishlistTab(
                        label: 'Điểm đến đã lưu',
                        selected: _tab == 1,
                        onTap: () => _changeTab(1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              sliver: SliverList.separated(
                itemCount: 3,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, _) => const _WishlistSkeleton(),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppErrorState(error: _error!, onRetry: _load),
            )
          else if (_items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.favorite_border_rounded,
                title: _tours ? 'Chưa lưu tour nào' : 'Chưa lưu điểm đến nào',
                subtitle: 'Nhấn biểu tượng trái tim để lưu lại cho lần sau.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              sliver: SliverList.separated(
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, index) => _SavedCard(
                  item: _items[index],
                  tours: _tours,
                  onRemove: () => _remove(_items[index]),
                ),
              ),
            ),
          if (!_loading && _error == null && _totalPages > 1)
            SliverToBoxAdapter(
              child: _WishlistPagination(
                page: _page,
                totalPages: _totalPages,
                total: _total,
                onChanged: _changePage,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    ),
  );
}

class _WishlistTab extends StatelessWidget {
  const _WishlistTab({
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
        height: 34,
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

class _SavedCard extends StatelessWidget {
  const _SavedCard({
    required this.item,
    required this.tours,
    required this.onRemove,
  });
  final Map<String, dynamic> item;
  final bool tours;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final id = _id(item, tours: tours);
    final image = AppConfig.assetUrl(_image(item));
    final name =
        '${item['name'] ?? item['title'] ?? (tours ? 'Tour trải nghiệm' : 'Điểm đến')}';
    final subtitle = tours
        ? '${item['destination_name'] ?? item['destination'] ?? item['description'] ?? 'Hành trình đáng nhớ'}'
        : '${item['country'] ?? item['region'] ?? item['short_description'] ?? 'Điểm đến nổi bật'}';
    final rating = _number(item['average_rating'] ?? item['rating']);
    final reviews = _integer(item['review_count'] ?? item['reviews_count']);
    final price = _number(item['price'] ?? item['base_price']);
    final days = _integer(item['duration_days']);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(tours ? '/tours/$id' : '/destinations/$id'),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 180,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    image.isEmpty
                        ? const ColoredBox(
                            color: AppColors.borderLight,
                            child: Icon(
                              Icons.landscape_outlined,
                              size: 42,
                              color: AppColors.subtle,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: image,
                            fit: BoxFit.cover,
                          ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: IconButton.filled(
                        tooltip: 'Bỏ lưu',
                        onPressed: onRemove,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFFF4D5E),
                          minimumSize: const Size(36, 36),
                          maximumSize: const Size(36, 36),
                          padding: EdgeInsets.zero,
                        ),
                        icon: const Icon(Icons.favorite_rounded, size: 19),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          rating > 0 ? rating.toStringAsFixed(1) : 'Mới',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (reviews > 0)
                          Text(
                            ' ($reviews)',
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: AppColors.muted,
                            ),
                          ),
                        if (tours && days > 0) ...[
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: AppColors.subtle,
                          ),
                          Text(
                            ' $days ngày',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (tours && price > 0)
                          Text(
                            '${NumberFormat('#,##0', 'vi_VN').format(price)} ₫',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.brand,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WishlistSkeleton extends StatelessWidget {
  const _WishlistSkeleton();
  @override
  Widget build(BuildContext context) => Container(
    height: 276,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppShimmerBox(width: double.infinity, height: 180, borderRadius: 12),
        SizedBox(height: 12),
        AppShimmerBox(width: 180, height: 13, borderRadius: 6),
        SizedBox(height: 9),
        AppShimmerBox(width: 120, height: 9, borderRadius: 5),
        SizedBox(height: 10),
        AppShimmerBox(width: double.infinity, height: 10, borderRadius: 5),
      ],
    ),
  );
}

class _WishlistPagination extends StatelessWidget {
  const _WishlistPagination({
    required this.page,
    required this.totalPages,
    required this.total,
    required this.onChanged,
  });
  final int page, totalPages, total;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '$total mục · Trang $page/$totalPages',
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

({List<Map<String, dynamic>> items, int totalPages, int total}) _parseSaved(
  dynamic body,
) {
  dynamic data = body;
  if (data is Map && data['data'] != null) data = data['data'];
  if (data is Map && data['data'] != null) data = data['data'];
  final raw = data is Map ? data['items'] : null;
  final items = raw is List
      ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];
  final pagination = data is Map && data['pagination'] is Map
      ? data['pagination'] as Map
      : const {};
  return (
    items: items,
    totalPages:
        int.tryParse(
          '${pagination['totalPages'] ?? pagination['total_pages'] ?? 1}',
        ) ??
        1,
    total:
        int.tryParse('${pagination['total'] ?? items.length}') ?? items.length,
  );
}

int _id(Map item, {required bool tours}) =>
    int.tryParse(
      '${tours ? item['tour_id'] ?? item['id'] : item['travel_destination_id'] ?? item['destination_id'] ?? item['id']}',
    ) ??
    0;
String _image(Map item) =>
    '${item['thumbnail_url'] ?? item['thumbnail'] ?? item['image_url'] ?? item['cover_image'] ?? ''}';
double _number(dynamic value) => double.tryParse('${value ?? 0}') ?? 0;
int _integer(dynamic value) => int.tryParse('${value ?? 0}') ?? 0;
