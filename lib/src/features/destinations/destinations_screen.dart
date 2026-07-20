import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../features/auth/auth_controller.dart';
import '../../design/app_colors.dart';
import '../../design/app_text_styles.dart';
import '../../design/app_widgets.dart';

class DestinationsScreen extends ConsumerStatefulWidget {
  const DestinationsScreen({super.key});

  @override
  ConsumerState<DestinationsScreen> createState() => _DestinationsScreenState();
}

class _DestinationsScreenState extends ConsumerState<DestinationsScreen> {
  static const _heroImage =
      'https://images.unsplash.com/photo-1570077188670-e3a8d69ac5ff?auto=format&fit=crop&w=1400&q=85';
  static const _sorts = [
    ('Newest', 'created_at', 'DESC'),
    ('Oldest', 'created_at', 'ASC'),
    ('Name A–Z', 'name', 'ASC'),
    ('Name Z–A', 'name', 'DESC'),
  ];

  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _categories = [];
  Set<int> _savedIds = {};
  String _search = '';
  String _categoryId = '';
  int _sortIndex = 0;
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.wait([_loadCategories(), _loadSavedIds()]);
    _load();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await ref.read(dioProvider).get('/destination-categories');
      if (!mounted) return;
      setState(
        () => _categories = unwrapList(response.data, ['categories', 'destination_categories']),
      );
    } catch (_) {}
  }

  Future<void> _loadSavedIds() async {
    if (!ref.read(authProvider).authenticated) return;
    try {
      final response = await ref.read(dioProvider).get('/saved/ids');
      final data = unwrap(response.data);
      final source = data is Map ? data['destination_ids'] ?? data['destinations'] : null;
      if (!mounted || source is! List) return;
      setState(
        () => _savedIds = source.map((e) => int.tryParse('$e') ?? 0).toSet(),
      );
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
              if (_categoryId.isNotEmpty) 'destination_category_id': _categoryId,
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
        _total = int.tryParse('${pagination['total'] ?? items.length}') ?? items.length;
        _totalPages = math.max(
          1,
          int.tryParse('${pagination['totalPages'] ?? pagination['total_pages'] ?? 1}') ?? 1,
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
  }

  Future<void> _toggleSaved(Map<String, dynamic> item) async {
    final auth = ref.read(authProvider);
    if (!auth.authenticated) {
      context.push('/login');
      return;
    }
    final id = _id(item);
    setState(() => _savedIds.contains(id) ? _savedIds.remove(id) : _savedIds.add(id));
    try {
      await ref.read(dioProvider).post('/saved/destinations/$id/toggle');
    } catch (e) {
      if (!mounted) return;
      setState(() => _savedIds.contains(id) ? _savedIds.remove(id) : _savedIds.add(id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiError(e))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    body: RefreshIndicator(
      color: AppColors.brand,
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          // Hero
          SliverToBoxAdapter(
            child: _DestinationHero(
              image: _heroImage,
              controller: _searchController,
              onSearch: () {
                _search = _searchController.text.trim();
                _apply();
              },
            ),
          ),

          // Category chips + controls
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        AppFilterChip(
                          label: 'All',
                          selected: _categoryId.isEmpty,
                          onTap: () {
                            _categoryId = '';
                            _apply();
                          },
                        ),
                        const SizedBox(width: 8),
                        ..._categories.map((cat) {
                          final id = '${cat['destination_category_id'] ?? cat['id'] ?? ''}';
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: AppFilterChip(
                              label: '${cat['name'] ?? 'Category'}',
                              selected: _categoryId == id,
                              onTap: () {
                                _categoryId = id;
                                _apply();
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _search.isEmpty ? 'Travel destinations' : 'Results for "$_search"',
                                style: AppTextStyles.h3,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _loading ? 'Finding places…' : '$_total destinations found',
                                style: AppTextStyles.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<int>(
                          initialValue: _sortIndex,
                          onSelected: (v) {
                            _sortIndex = v;
                            _apply();
                          },
                          itemBuilder: (_) => List.generate(
                            _sorts.length,
                            (i) => PopupMenuItem(
                              value: i,
                              child: Text(_sorts[i].$1),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.tune_rounded, size: 16, color: AppColors.muted),
                                const SizedBox(width: 6),
                                Text(
                                  _sorts[_sortIndex].$1,
                                  style: AppTextStyles.label.copyWith(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AppErrorState(error: _error!, onRetry: _load),
              ),
            )
          else if (_loading)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              sliver: _DestinationSkeleton(),
            )
          else if (_items.isEmpty)
            SliverToBoxAdapter(
              child: AppEmptyState(
                icon: Icons.travel_explore_rounded,
                title: 'No destinations found',
                subtitle: 'Try another search or category.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.crossAxisExtent >= 760
                      ? 3
                      : constraints.crossAxisExtent >= 500
                      ? 2
                      : 1;
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: columns == 1 ? 1.1 : .78,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, index) {
                        final item = _items[index];
                        return _DestinationCard(
                          item: item,
                          saved: _savedIds.contains(_id(item)),
                          onSave: () => _toggleSaved(item),
                          onTap: () => context.push('/destinations/${_id(item)}'),
                        );
                      },
                      childCount: _items.length,
                    ),
                  );
                },
              ),
            ),

          // Pagination
          if (!_loading && _error == null && _totalPages > 1)
            SliverToBoxAdapter(
              child: _Pagination(
                page: _page,
                totalPages: _totalPages,
                onChanged: (page) => _apply(page: page),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    ),
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// ─── Hero ─────────────────────────────────────────────────────────────────────

class _DestinationHero extends StatelessWidget {
  const _DestinationHero({
    required this.image,
    required this.controller,
    required this.onSearch,
  });
  final String image;
  final TextEditingController controller;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 310,
    child: Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
        const AppHeroOverlay(),
        // Back button
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Material(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.canPop() ? context.pop() : null,
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Text + search
        Positioned(
          left: 20,
          right: 20,
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explore\nDestinations',
                style: AppTextStyles.h1White.copyWith(fontSize: 34),
              ),
              const SizedBox(height: 6),
              Text(
                'Discover your next great adventure',
                style: AppTextStyles.bodySmallWhite,
              ),
              const SizedBox(height: 18),
              // Search bar
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 10),
                    const Icon(Icons.search_rounded, color: AppColors.muted, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => onSearch(),
                        style: AppTextStyles.body,
                        decoration: InputDecoration(
                          hintText: 'Search destinations…',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                          hintStyle: AppTextStyles.body.copyWith(color: AppColors.subtle),
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: onSearch,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(50, 42),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Icon(Icons.arrow_forward_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─── Destination Card ─────────────────────────────────────────────────────────

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({
    required this.item,
    required this.saved,
    required this.onSave,
    required this.onTap,
  });
  final Map<String, dynamic> item;
  final bool saved;
  final VoidCallback onSave, onTap;

  @override
  Widget build(BuildContext context) {
    final image = AppConfig.assetUrl(_image(item));
    final name = '${item['name'] ?? item['title'] ?? 'Destination'}';
    final country = '${item['country'] ?? item['city'] ?? 'Vietnam'}';
    final categoryRaw = item['destination_category'] ?? item['category'];
    final category = categoryRaw is Map
        ? '${categoryRaw['name'] ?? 'Destination'}'
        : '${categoryRaw ?? item['category_name'] ?? 'Destination'}';
    final rating = double.tryParse('${item['average_rating'] ?? item['rating'] ?? 0}') ?? 0;
    final reviews = item['reviews_count'] ?? item['review_count'] ?? 0;
    final price = num.tryParse('${item['price_from'] ?? item['min_price'] ?? 0}') ?? 0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  image.isEmpty
                      ? ColoredBox(
                          color: AppColors.borderLight,
                          child: const Icon(Icons.landscape_outlined, size: 54, color: AppColors.subtle),
                        )
                      : CachedNetworkImage(
                          imageUrl: image,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => const ColoredBox(color: AppColors.borderLight),
                          errorWidget: (_, _, _) => const ColoredBox(
                            color: AppColors.borderLight,
                            child: Icon(Icons.broken_image_outlined, color: AppColors.subtle),
                          ),
                        ),
                  // Bottom gradient
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x55000000)],
                          stops: [0.5, 1],
                        ),
                      ),
                    ),
                  ),
                  // Save button
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Material(
                      color: Colors.black.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: onSave,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: saved ? const Color(0xFFFF4D6D) : Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Category badge
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category,
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$name, $country',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h4,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      AppRatingRow(rating: rating, count: reviews as int),
                      const Spacer(),
                      if (price > 0)
                        Text(
                          NumberFormat.compactCurrency(
                            locale: 'vi_VN',
                            symbol: '₫',
                          ).format(price),
                          style: AppTextStyles.label.copyWith(color: AppColors.brand),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Skeleton ─────────────────────────────────────────────────────────────────

class _DestinationSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (_, constraints) {
      final columns = constraints.crossAxisExtent >= 500 ? 2 : 1;
      return SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: columns == 1 ? 1.1 : .78,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, _) => Shimmer.fromColors(
            baseColor: const Color(0xFFE5E7EB),
            highlightColor: const Color(0xFFF9FAFB),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          childCount: 6,
        ),
      );
    },
  );
}

// ─── Pagination ───────────────────────────────────────────────────────────────

class _Pagination extends StatelessWidget {
  const _Pagination({required this.page, required this.totalPages, required this.onChanged});
  final int page, totalPages;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PaginationBtn(
          icon: Icons.chevron_left_rounded,
          enabled: page > 1,
          onTap: () => onChanged(page - 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '$page / $totalPages',
            style: AppTextStyles.label,
          ),
        ),
        _PaginationBtn(
          icon: Icons.chevron_right_rounded,
          enabled: page < totalPages,
          onTap: () => onChanged(page + 1),
        ),
      ],
    ),
  );
}

class _PaginationBtn extends StatelessWidget {
  const _PaginationBtn({required this.icon, required this.enabled, required this.onTap});
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: enabled ? Colors.white : AppColors.borderLight,
    borderRadius: BorderRadius.circular(12),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(
          icon,
          color: enabled ? AppColors.ink : AppColors.subtle,
          size: 22,
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
    item['thumbnail_url'] ?? item['thumbnail'] ?? item['image_url'] ?? item['image'];
