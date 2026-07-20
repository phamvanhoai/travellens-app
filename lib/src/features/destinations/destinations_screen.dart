import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../design/app_colors.dart';
import '../../design/app_text_styles.dart';
import '../../design/app_widgets.dart';
import '../auth/auth_controller.dart';
import 'saved_destinations_controller.dart';

class DestinationsScreen extends ConsumerStatefulWidget {
  const DestinationsScreen({super.key});

  @override
  ConsumerState<DestinationsScreen> createState() => _DestinationsScreenState();
}

class _DestinationsScreenState extends ConsumerState<DestinationsScreen> {
  static const _sorts = [
    ('Mới nhất', 'created_at', 'DESC'),
    ('Cũ nhất', 'created_at', 'ASC'),
    ('Tên A–Z', 'name', 'ASC'),
    ('Tên Z–A', 'name', 'DESC'),
  ];

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _categories = [];
  String _search = '';
  String _categoryId = '';
  int _sortIndex = 0;
  int _page = 1;
  int _totalPages = 1;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _load();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await ref
          .read(dioProvider)
          .get('/destination-categories');
      if (!mounted) return;
      setState(() {
        _categories = unwrapList(response.data, [
          'categories',
          'destination_categories',
        ]);
      });
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sort = _sorts[_sortIndex];
      final response = await ref
          .read(dioProvider)
          .get(
            '/travel-destinations',
            queryParameters: {
              'page': _page,
              'limit': 8,
              if (_search.isNotEmpty) 'search': _search,
              if (_categoryId.isNotEmpty)
                'destination_category_id': _categoryId,
              'sortBy': sort.$2,
              'sortOrder': sort.$3,
            },
          );
      final body = response.data;
      final items = unwrapList(body, ['destinations', 'travel_destinations']);
      final root = body is Map ? body : const {};
      final data = root['data'] is Map ? root['data'] as Map : const {};
      final pagination = root['pagination'] is Map
          ? root['pagination'] as Map
          : data['pagination'] is Map
          ? data['pagination'] as Map
          : const {};
      if (!mounted) return;
      setState(() {
        _items = items;
        _totalPages = math.max(
          1,
          int.tryParse(
                '${pagination['totalPages'] ?? pagination['total_pages'] ?? 1}',
              ) ??
              1,
        );
      });
    } on DioException catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apply({int page = 1}) {
    _page = page;
    _load();
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _submitSearch() {
    _search = _searchController.text.trim();
    _apply();
  }

  Future<void> _toggleSaved(Map<String, dynamic> item) async {
    if (!ref.read(authProvider).authenticated) {
      context.push('/login');
      return;
    }
    final id = _id(item);
    try {
      await ref.read(savedDestinationsProvider.notifier).toggle(id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(apiError(e))));
    }
  }

  void _showSort() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sắp xếp theo', style: AppTextStyles.h4),
              const SizedBox(height: 10),
              for (var i = 0; i < _sorts.length; i++)
                RadioListTile<int>(
                  value: i,
                  groupValue: _sortIndex,
                  contentPadding: EdgeInsets.zero,
                  title: Text(_sorts[i].$1),
                  onChanged: (value) {
                    if (value == null) return;
                    Navigator.pop(sheetContext);
                    setState(() => _sortIndex = value);
                    _apply();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final savedIds = ref.watch(savedDestinationsProvider).ids;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
        ),
        title: const Text('Khám phá điểm đến'),
      ),
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: _load,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _submitSearch(),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.ink,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Tìm điểm đến, quốc gia...',
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: AppColors.subtle,
                            ),
                            suffixIcon: _searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      _search = '';
                                      _apply();
                                    },
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                    ),
                                  ),
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Material(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: AppColors.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: _showSort,
                        borderRadius: BorderRadius.circular(12),
                        child: const SizedBox(
                          width: 46,
                          height: 46,
                          child: Icon(Icons.tune_rounded, size: 19),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 5, 16, 7),
                  children: [
                    _CategoryPill(
                      label: 'Tất cả',
                      selected: _categoryId.isEmpty,
                      onTap: () {
                        setState(() => _categoryId = '');
                        _apply();
                      },
                    ),
                    const SizedBox(width: 8),
                    for (final category in _categories) ...[
                      _CategoryPill(
                        label: '${category['name'] ?? 'Danh mục'}',
                        selected:
                            _categoryId ==
                            '${category['destination_category_id'] ?? category['id'] ?? ''}',
                        onTap: () {
                          setState(() {
                            _categoryId =
                                '${category['destination_category_id'] ?? category['id'] ?? ''}';
                          });
                          _apply();
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
            if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: AppErrorState(error: _error!, onRetry: _load),
              )
            else if (_loading)
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: _DestinationSkeleton(),
              )
            else if (_items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState(
                  icon: Icons.travel_explore_rounded,
                  title: 'Không tìm thấy điểm đến',
                  subtitle: 'Hãy thử từ khóa hoặc danh mục khác.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                sliver: SliverList.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final item = _items[index];
                    return _LargeDestinationCard(
                      item: item,
                      saved: savedIds.contains(_id(item)),
                      onSave: () => _toggleSaved(item),
                      onTap: () => context.push('/destinations/${_id(item)}'),
                    );
                  },
                ),
              ),
            if (!_loading && _error == null && _totalPages > 1)
              SliverToBoxAdapter(
                child: _Pagination(
                  page: _page,
                  totalPages: _totalPages,
                  onChanged: (page) => _apply(page: page),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFF163A78) : Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF163A78) : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: selected ? Colors.white : AppColors.muted,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}

class _DestinationListCard extends StatelessWidget {
  const _DestinationListCard({
    required this.item,
    required this.saved,
    required this.onSave,
    required this.onTap,
  });
  final Map<String, dynamic> item;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = AppConfig.assetUrl(_image(item));
    final name = '${item['name'] ?? item['title'] ?? 'Điểm đến'}';
    final country = '${item['country'] ?? item['city'] ?? ''}';
    final categoryRaw = item['destination_category'] ?? item['category'];
    final subtitle = categoryRaw is Map
        ? '${categoryRaw['name'] ?? 'Điểm đến nổi bật'}'
        : '${item['short_description'] ?? item['category_name'] ?? 'Điểm đến nổi bật'}';
    final rating =
        double.tryParse('${item['average_rating'] ?? item['rating'] ?? 0}') ??
        0;
    final reviews =
        int.tryParse('${item['reviews_count'] ?? item['review_count'] ?? 0}') ??
        0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 116,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderLight),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
                child: SizedBox(
                  width: 112,
                  height: double.infinity,
                  child: image.isEmpty
                      ? const ColoredBox(
                          color: AppColors.borderLight,
                          child: Icon(
                            Icons.landscape_outlined,
                            color: AppColors.subtle,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: image,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              const ColoredBox(color: AppColors.borderLight),
                          errorWidget: (_, _, _) => const ColoredBox(
                            color: AppColors.borderLight,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: AppColors.subtle,
                            ),
                          ),
                        ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 4, 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        country.isEmpty ? name : '$name, $country',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _plainText(subtitle),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(fontSize: 10),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: AppColors.gold,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rating > 0 ? rating.toStringAsFixed(1) : 'Mới',
                            style: AppTextStyles.label.copyWith(fontSize: 10),
                          ),
                          if (reviews > 0) ...[
                            const SizedBox(width: 3),
                            Text(
                              '($reviews)',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: IconButton(
                  onPressed: onSave,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    saved
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 20,
                    color: saved ? const Color(0xFFFF4D5E) : AppColors.subtle,
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

class _LargeDestinationCard extends StatelessWidget {
  const _LargeDestinationCard({
    required this.item,
    required this.saved,
    required this.onSave,
    required this.onTap,
  });
  final Map<String, dynamic> item;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = AppConfig.assetUrl(_image(item));
    final name = '${item['name'] ?? item['title'] ?? 'Điểm đến'}';
    final country = '${item['country'] ?? item['city'] ?? ''}';
    final categoryRaw = item['destination_category'] ?? item['category'];
    final category = categoryRaw is Map
        ? '${categoryRaw['name'] ?? ''}'
        : '${item['category_name'] ?? categoryRaw ?? ''}';
    final region = '${item['region'] ?? item['area'] ?? ''}';
    final rating =
        double.tryParse('${item['average_rating'] ?? item['rating'] ?? 0}') ??
        0;
    final reviews =
        int.tryParse('${item['reviews_count'] ?? item['review_count'] ?? 0}') ??
        0;
    final price =
        double.tryParse(
          '${item['price_from'] ?? item['starting_price'] ?? item['min_price'] ?? 0}',
        ) ??
        0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D0F172A),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                height: 200,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (image.isEmpty)
                      const ColoredBox(
                        color: AppColors.borderLight,
                        child: Icon(
                          Icons.landscape_outlined,
                          size: 48,
                          color: AppColors.subtle,
                        ),
                      )
                    else
                      CachedNetworkImage(
                        imageUrl: image,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            const ColoredBox(color: AppColors.borderLight),
                        errorWidget: (_, _, _) => const ColoredBox(
                          color: AppColors.borderLight,
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    if (category.isNotEmpty)
                      Positioned(
                        left: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brand,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            category,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: SizedBox(
                        width: 38,
                        height: 38,
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: onSave,
                            customBorder: const CircleBorder(),
                            child: Icon(
                              saved
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 20,
                              color: saved
                                  ? const Color(0xFFFF4D5E)
                                  : AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                country.isEmpty ? name : '$name, $country',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  height: 1.25,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                              if (category.isNotEmpty || region.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  [category, region]
                                      .where((value) => value.isNotEmpty)
                                      .join(' • '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (price > 0) ...[
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Giá từ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                              Text(
                                '${_formatDestinationPrice(price)}đ',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppColors.gold,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rating > 0 ? rating.toStringAsFixed(1) : 'Mới',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (reviews > 0)
                          Text(' ($reviews)', style: AppTextStyles.caption),
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

String _formatDestinationPrice(double value) {
  final text = value.round().toString();
  return text.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
}

class _DestinationSkeleton extends StatelessWidget {
  const _DestinationSkeleton();

  @override
  Widget build(BuildContext context) => SliverList.separated(
    itemCount: 6,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (_, _) => Shimmer.fromColors(
      baseColor: const Color(0xFFE9EAED),
      highlightColor: const Color(0xFFF8F8F9),
      child: Container(
        height: 330,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
        ),
      ),
    ),
  );
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.totalPages,
    required this.onChanged,
  });
  final int page;
  final int totalPages;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PageButton(
          icon: Icons.chevron_left_rounded,
          enabled: page > 1,
          onTap: () => onChanged(page - 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text('$page / $totalPages', style: AppTextStyles.label),
        ),
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
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.border),
      borderRadius: BorderRadius.circular(10),
    ),
    child: InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 38,
        height: 38,
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppColors.ink : AppColors.subtle,
        ),
      ),
    ),
  );
}

int _id(Map item) =>
    int.tryParse(
      '${item['travel_destination_id'] ?? item['destination_id'] ?? item['id'] ?? 0}',
    ) ??
    0;

String? _image(Map item) =>
    item['thumbnail_url'] ??
    item['thumbnail'] ??
    item['image_url'] ??
    item['image'];

String _plainText(String value) => value
    .replaceAll(RegExp('<[^>]*>'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
