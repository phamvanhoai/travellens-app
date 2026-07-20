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
      final response = await ref
          .read(dioProvider)
          .get('/destination-categories');
      if (!mounted) return;
      setState(
        () => _categories = unwrapList(response.data, [
          'categories',
          'destination_categories',
        ]),
      );
    } catch (_) {}
  }

  Future<void> _loadSavedIds() async {
    if (!ref.read(authProvider).authenticated) return;
    try {
      final response = await ref.read(dioProvider).get('/saved/ids');
      final data = unwrap(response.data);
      final source = data is Map
          ? data['destination_ids'] ?? data['destinations']
          : null;
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
        _total =
            int.tryParse('${pagination['total'] ?? items.length}') ??
            items.length;
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
  }

  Future<void> _toggleSaved(Map<String, dynamic> item) async {
    final auth = ref.read(authProvider);
    if (!auth.authenticated) {
      context.push('/login');
      return;
    }
    final id = _id(item);
    setState(
      () => _savedIds.contains(id) ? _savedIds.remove(id) : _savedIds.add(id),
    );
    try {
      await ref.read(dioProvider).post('/saved/destinations/$id/toggle');
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _savedIds.contains(id) ? _savedIds.remove(id) : _savedIds.add(id),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(apiError(e))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8FAFC),
    body: RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Hero(
              image: _heroImage,
              controller: _searchController,
              onSearch: () {
                _search = _searchController.text.trim();
                _apply();
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _CategoryChip(
                          label: 'All Destinations',
                          selected: _categoryId.isEmpty,
                          onTap: () {
                            _categoryId = '';
                            _apply();
                          },
                        ),
                        ..._categories.map((category) {
                          final id =
                              '${category['destination_category_id'] ?? category['id'] ?? ''}';
                          return _CategoryChip(
                            label: '${category['name'] ?? 'Category'}',
                            selected: _categoryId == id,
                            onTap: () {
                              _categoryId = id;
                              _apply();
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _search.isEmpty
                                  ? 'Travel destinations'
                                  : 'Results for “$_search”',
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _loading
                                  ? 'Finding inspiring places…'
                                  : '$_total destinations found',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<int>(
                        initialValue: _sortIndex,
                        onSelected: (value) {
                          _sortIndex = value;
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.tune, size: 17),
                              const SizedBox(width: 7),
                              Text(
                                _sorts[_sortIndex].$1,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _ErrorCard(message: _error!, retry: _load),
              ),
            )
          else if (_loading)
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 6, 16, 24),
              sliver: _DestinationSkeleton(),
            )
          else if (_items.isEmpty)
            const SliverToBoxAdapter(child: _EmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
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
                      childAspectRatio: columns == 1 ? 1.04 : .75,
                    ),
                    delegate: SliverChildBuilderDelegate((_, index) {
                      final item = _items[index];
                      return _DestinationCard(
                        item: item,
                        saved: _savedIds.contains(_id(item)),
                        onSave: () => _toggleSaved(item),
                        onTap: () => context.push('/destinations/${_id(item)}'),
                      );
                    }, childCount: _items.length),
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
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
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

class _Hero extends StatelessWidget {
  const _Hero({
    required this.image,
    required this.controller,
    required this.onSearch,
  });
  final String image;
  final TextEditingController controller;
  final VoidCallback onSearch;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 330,
    child: Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x660F172A), Color(0xCC0F172A)],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 42, 20, 22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Explore Destinations',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 31,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.7,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Find your next adventure from around the world',
                style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 15),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x330F172A),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 10),
                    const Icon(Icons.search, color: Color(0xFF0891B2)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => onSearch(),
                        decoration: const InputDecoration.collapsed(
                          hintText: 'Search destinations…',
                        ),
                      ),
                    ),
                    IconButton.filled(
                      onPressed: onSearch,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF0891B2),
                      ),
                      icon: const Icon(Icons.arrow_forward),
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

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 9),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: const Color(0xFF0891B2),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? const Color(0xFF0891B2) : const Color(0xFFE2E8F0),
      ),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF334155),
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
  );
}

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
    final region = '${item['region'] ?? item['address'] ?? 'Vietnam'}';
    final rating =
        double.tryParse('${item['average_rating'] ?? item['rating'] ?? 0}') ??
        0;
    final reviews = item['reviews_count'] ?? item['review_count'] ?? 0;
    final price =
        num.tryParse('${item['price_from'] ?? item['min_price'] ?? 0}') ?? 0;
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: const Color(0x220F172A),
      borderRadius: BorderRadius.circular(18),
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
                      ? const ColoredBox(
                          color: Color(0xFFE2E8F0),
                          child: Icon(Icons.landscape_outlined, size: 54),
                        )
                      : CachedNetworkImage(
                          imageUrl: image,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              const ColoredBox(color: Color(0xFFE2E8F0)),
                          errorWidget: (_, _, _) => const ColoredBox(
                            color: Color(0xFFE2E8F0),
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x44000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Material(
                      color: Colors.white.withValues(alpha: .94),
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: onSave,
                        icon: Icon(
                          saved ? Icons.favorite : Icons.favorite_border,
                          color: saved
                              ? const Color(0xFFE11D48)
                              : const Color(0xFF334155),
                        ),
                        iconSize: 21,
                      ),
                    ),
                  ),
                  if (item['badge'] != null)
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0891B2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${item['badge']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
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
                              '$name, $country',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$category · $region',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (price > 0)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'from',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            Text(
                              NumberFormat.compactCurrency(
                                locale: 'vi_VN',
                                symbol: '₫',
                              ).format(price),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFBBF24),
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rating > 0 ? rating.toStringAsFixed(1) : 'New',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '($reviews reviews)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_forward,
                        size: 18,
                        color: Color(0xFF0891B2),
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

class _DestinationSkeleton extends StatelessWidget {
  const _DestinationSkeleton();
  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (_, constraints) {
      final columns = constraints.crossAxisExtent >= 500 ? 2 : 1;
      return SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: columns == 1 ? 1.04 : .75,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, _) => Shimmer.fromColors(
            baseColor: const Color(0xFFE2E8F0),
            highlightColor: const Color(0xFFF8FAFC),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          childCount: 6,
        ),
      );
    },
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1F2),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: Color(0xFFBE123C)),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
        TextButton(onPressed: retry, child: const Text('Retry')),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 260,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.travel_explore, size: 58, color: Color(0xFF94A3B8)),
        SizedBox(height: 12),
        Text(
          'No destinations found',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 5),
        Text(
          'Try another search or category.',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      ],
    ),
  );
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.totalPages,
    required this.onChanged,
  });
  final int page, totalPages;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.outlined(
          onPressed: page > 1 ? () => onChanged(page - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            '$page / $totalPages',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton.outlined(
          onPressed: page < totalPages ? () => onChanged(page + 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
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
