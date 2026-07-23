import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../core/network/api_client.dart';
import '../design/app_colors.dart';
import '../design/app_widgets.dart';
import '../features/auth/auth_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _hero =
      'https://images.unsplash.com/photo-1528127269322-539801943592?auto=format&fit=crop&w=1200&q=90';
  static const _shortcuts = [
    (
      'Điểm đến',
      Icons.location_on_rounded,
      '/destinations',
      Color(0xFF8B5CF6),
      Color(0xFFF3E8FF),
    ),
    (
      'Tour',
      Icons.card_travel_rounded,
      '/tours',
      Color(0xFFEF4444),
      Color(0xFFFEE2E2),
    ),
    (
      'View360',
      Icons.threesixty_rounded,
      '/view360',
      Color(0xFF6366F1),
      Color(0xFFE0E7FF),
    ),
    (
      'Bản đồ',
      Icons.map_rounded,
      '/maps',
      Color(0xFF0EA5E9),
      Color(0xFFE0F2FE),
    ),
    (
      'Trợ lý AI',
      Icons.auto_awesome_rounded,
      '/ai',
      Color(0xFF9333EA),
      Color(0xFFF3E8FF),
    ),
    (
      'Cẩm nang',
      Icons.menu_book_rounded,
      '/blogs',
      Color(0xFF059669),
      Color(0xFFECFDF5),
    ),
  ];

  List<Map<String, dynamic>> _destinations = [];
  List<Map<String, dynamic>> _tours = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final results = await Future.wait([_fetchDestinations(), _fetchTours()]);
    if (!mounted) return;
    setState(() {
      _destinations = results[0];
      _tours = results[1];
      _loading = false;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchDestinations() async {
    try {
      final response = await ref
          .read(dioProvider)
          .get(
            '/travel-destinations',
            queryParameters: {'page': 1, 'limit': 6},
          );
      return unwrapList(response.data, ['destinations', 'travel_destinations']);
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchTours() async {
    try {
      final response = await ref
          .read(dioProvider)
          .get('/tours', queryParameters: {'page': 1, 'limit': 6});
      return unwrapList(response.data, ['tours']);
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user ?? const <String, dynamic>{};
    final fullName = '${user['name'] ?? 'Khách du lịch'}';
    final name = fullName.trim().isEmpty
        ? 'Khách du lịch'
        : fullName.trim().split(RegExp(r'\s+')).last;
    final avatar = AppConfig.assetUrl('${user['avatar_url'] ?? ''}');

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 9, 18, 92),
                sliver: SliverList.list(
                  children: [
                    _Greeting(name: name, fullName: fullName, avatar: avatar),
                    const SizedBox(height: 11),
                    const _SearchBox(),
                    const SizedBox(height: 11),
                    const _HeroBanner(image: _hero),
                    const SizedBox(height: 12),
                    const _ShortcutRow(items: _shortcuts),
                    ...[
                      const SizedBox(height: 17),
                      const _SectionTitle(
                        title: 'Điểm đến',
                        route: '/destinations',
                      ),
                      const SizedBox(height: 9),
                      if (_loading)
                        const SizedBox(
                          height: 150,
                          child: Row(
                            children: [
                              Expanded(
                                child: AppShimmerBox(
                                  width: null,
                                  height: 150,
                                  borderRadius: 13,
                                ),
                              ),
                              SizedBox(width: 9),
                              Expanded(
                                child: AppShimmerBox(
                                  width: null,
                                  height: 150,
                                  borderRadius: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_destinations.isEmpty)
                        const _CompactEmpty(label: 'Chưa có điểm đến')
                      else
                        SizedBox(
                          height: 150,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _destinations.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 9),
                            itemBuilder: (_, index) =>
                                _DestinationCard(item: _destinations[index]),
                          ),
                        ),
                      const SizedBox(height: 18),
                      const _SectionTitle(
                        title: 'Tour du lịch',
                        route: '/tours',
                      ),
                      const SizedBox(height: 9),
                      if (_loading)
                        const SizedBox(
                          height: 112,
                          child: Row(
                            children: [
                              AppShimmerBox(
                                width: 160,
                                height: 112,
                                borderRadius: 13,
                              ),
                              SizedBox(width: 9),
                              AppShimmerBox(
                                width: 160,
                                height: 112,
                                borderRadius: 13,
                              ),
                            ],
                          ),
                        )
                      else if (_tours.isEmpty)
                        const _CompactEmpty(label: 'Chưa có tour')
                      else
                        SizedBox(
                          height: 112,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _tours.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 9),
                            itemBuilder: (_, index) =>
                                _TourCard(item: _tours[index]),
                          ),
                        ),
                    ],
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

class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.name,
    required this.fullName,
    required this.avatar,
  });
  final String name, fullName, avatar;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      AppAvatar(
        name: fullName,
        imageUrl: avatar.isEmpty ? null : avatar,
        radius: 17,
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Xin chào, $name 👋',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 1),
            const Text(
              'Bạn muốn khám phá đâu hôm nay?',
              style: TextStyle(fontSize: 9.5, color: AppColors.muted),
            ),
          ],
        ),
      ),
      IconButton(
        onPressed: () => context.push('/invitations'),
        visualDensity: VisualDensity.compact,
        icon: const Badge(
          smallSize: 6,
          child: Icon(Icons.notifications_none_rounded, size: 21),
        ),
      ),
    ],
  );
}

class _SearchBox extends StatelessWidget {
  const _SearchBox();
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.go('/destinations'),
    borderRadius: BorderRadius.circular(11),
    child: Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(11),
      ),
      child: const Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: AppColors.subtle),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tìm điểm đến, tour, trải nghiệm...',
              style: TextStyle(fontSize: 10.5, color: AppColors.subtle),
            ),
          ),
          Icon(Icons.tune_rounded, size: 17, color: AppColors.ink),
        ],
      ),
    ),
  );
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.image});
  final String image;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.go('/destinations'),
    borderRadius: BorderRadius.circular(14),
    child: Container(
      height: 142,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xB8001733)],
              ),
            ),
          ),
          const Positioned(
            left: 14,
            bottom: 13,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Khám phá thế giới',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Khám phá vẻ đẹp\nmuôn nơi trên thế giới',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.items});
  final List<(String, IconData, String, Color, Color)> items;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 62,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, index) {
        final item = items[index];
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push(item.$3),
          child: SizedBox(
            width: 56,
            child: Column(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: item.$5,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.$2, color: item.$4, size: 18),
                ),
                const SizedBox(height: 5),
                Text(
                  item.$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 8.5, color: AppColors.ink),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.route});
  final String title, route;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
      SizedBox(
        height: 28,
        child: TextButton(
          onPressed: () => context.push(route),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            minimumSize: const Size(0, 28),
          ),
          child: const Text('Xem tất cả', style: TextStyle(fontSize: 9.5)),
        ),
      ),
    ],
  );
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({required this.item});
  final Map<String, dynamic> item;
  @override
  Widget build(BuildContext context) {
    final id = _destinationId(item);
    final image = AppConfig.assetUrl(_image(item));
    final name = '${item['name'] ?? item['title'] ?? 'Điểm đến'}';
    final country = '${item['country'] ?? item['region'] ?? ''}';
    final rating = _number(item['average_rating'] ?? item['rating']);
    final reviews = _integer(item['review_count'] ?? item['reviews_count']);
    return InkWell(
      onTap: () => context.push('/destinations/$id'),
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: 156,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: AppColors.borderLight,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            image.isEmpty
                ? const ColoredBox(color: AppColors.borderLight)
                : CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xD0000000)],
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 8,
              bottom: 9,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    country.isEmpty ? name : '$name, $country',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: AppColors.gold,
                        size: 12,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        rating > 0 ? rating.toStringAsFixed(1) : 'Mới',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (reviews > 0)
                        Text(
                          ' ($reviews)',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 8,
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
    );
  }
}

class _TourCard extends StatelessWidget {
  const _TourCard({required this.item});
  final Map<String, dynamic> item;
  @override
  Widget build(BuildContext context) {
    final id = _integer(item['tour_id'] ?? item['id']);
    final image = AppConfig.assetUrl(_image(item));
    final name = '${item['name'] ?? item['title'] ?? 'Tour trải nghiệm'}';
    final price = _number(item['price'] ?? item['base_price']);
    return InkWell(
      onTap: () => context.push('/tours/$id'),
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: 160,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: double.infinity,
              child: image.isEmpty
                  ? const ColoredBox(color: AppColors.borderLight)
                  : CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    if (price > 0)
                      Text(
                        '${NumberFormat('#,##0', 'vi_VN').format(price)} ₫',
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brand,
                        ),
                      ),
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

class _CompactEmpty extends StatelessWidget {
  const _CompactEmpty({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    height: 84,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.borderLight),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
    ),
  );
}

int _destinationId(Map item) => _integer(
  item['travel_destination_id'] ?? item['destination_id'] ?? item['id'],
);
String _image(Map item) =>
    '${item['thumbnail_url'] ?? item['thumbnail'] ?? item['image_url'] ?? item['cover_image'] ?? ''}';
double _number(dynamic value) => double.tryParse('${value ?? 0}') ?? 0;
int _integer(dynamic value) => int.tryParse('${value ?? 0}') ?? 0;
