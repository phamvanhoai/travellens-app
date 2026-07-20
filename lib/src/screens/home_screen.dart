import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_colors.dart';
import '../design/app_text_styles.dart';
import '../features/auth/auth_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _hero =
      'https://images.unsplash.com/photo-1528127269322-539801943592?auto=format&fit=crop&w=1200&q=90';
  static const _places = [
    ('Bali, Indonesia', 'Thiên đường nhiệt đới', 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?auto=format&fit=crop&w=700&q=85', '4.8 (326)'),
    ('Phú Quốc, Việt Nam', 'Biển xanh cát trắng', 'https://images.unsplash.com/photo-1583417319070-4a69db38a482?auto=format&fit=crop&w=700&q=85', '4.7 (189)'),
  ];
  static const _shortcuts = [
    ('Điểm đến', Icons.location_on_rounded, '/destinations', Color(0xFF8B5CF6), Color(0xFFF3E8FF)),
    ('Tour', Icons.card_travel_rounded, '/tours', Color(0xFFEF4444), Color(0xFFFEE2E2)),
    ('View360', Icons.threesixty_rounded, '/view360', Color(0xFF6366F1), Color(0xFFE0E7FF)),
    ('Bản đồ', Icons.map_rounded, '/maps', Color(0xFF0EA5E9), Color(0xFFE0F2FE)),
    ('AI Assistant', Icons.auto_awesome_rounded, '/ai', Color(0xFF9333EA), Color(0xFFF3E8FF)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final name = '${user?['name'] ?? 'Huy'}'.split(' ').last;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
              sliver: SliverList.list(children: [
                _Greeting(name: name),
                const SizedBox(height: 16),
                const _SearchBox(),
                const SizedBox(height: 16),
                _HeroBanner(image: _hero),
                const SizedBox(height: 16),
                _ShortcutRow(items: _shortcuts),
                const SizedBox(height: 20),
                const _SectionTitle(title: 'Gợi ý dành cho bạn', route: '/destinations'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 174,
                  child: Row(
                    children: [
                      for (var i = 0; i < _places.length; i++) ...[
                        Expanded(child: _PlaceCard(place: _places[i])),
                        if (i == 0) const SizedBox(width: 10),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const _SectionTitle(title: 'Tour phổ biến', route: '/tours'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 104,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 3,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: CachedNetworkImage(
                        imageUrl: _places[i % 2].$3,
                        width: 154,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) => Row(children: [
    const CircleAvatar(
      radius: 17,
      backgroundImage: NetworkImage('https://i.pravatar.cc/100?img=12'),
    ),
    const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Xin chào, $name 👋', style: AppTextStyles.label.copyWith(fontSize: 14)),
      const SizedBox(height: 2),
      Text('Bạn muốn khám phá đâu hôm nay?', style: AppTextStyles.caption),
    ])),
    IconButton(
      onPressed: () => context.push('/invitations'),
      icon: const Badge(smallSize: 7, child: Icon(Icons.notifications_none_rounded, size: 23)),
    ),
  ]);
}

class _SearchBox extends StatelessWidget {
  const _SearchBox();
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.go('/destinations'),
    child: Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.search_rounded, size: 20, color: AppColors.subtle),
        const SizedBox(width: 10),
        Expanded(child: Text('Tìm điểm đến, tour, trải nghiệm...', style: AppTextStyles.bodySmall)),
        const Icon(Icons.tune_rounded, size: 19, color: AppColors.ink),
      ]),
    ),
  );
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.image});
  final String image;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.go('/destinations'),
    child: Container(
      height: 188,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
      child: Stack(fit: StackFit.expand, children: [
        CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0xB8001733)],
        ))),
        Positioned(
          left: 17,
          bottom: 18,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Travel', style: AppTextStyles.h1White.copyWith(fontSize: 30, fontStyle: FontStyle.italic)),
            Text('Không phá vỡ đam mê,\nmuốn non trên thế giới', style: AppTextStyles.bodySmallWhite.copyWith(color: Colors.white)),
          ]),
        ),
      ]),
    ),
  );
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.items});
  final List<(String, IconData, String, Color, Color)> items;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: items.map((item) => InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push(item.$3),
      child: SizedBox(width: 62, child: Column(children: [
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(color: item.$5, shape: BoxShape.circle),
          child: Icon(item.$2, color: item.$4, size: 21),
        ),
        const SizedBox(height: 7),
        Text(item.$1, maxLines: 1, style: AppTextStyles.caption.copyWith(fontSize: 9, color: AppColors.ink)),
      ])),
    )).toList(),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.route});
  final String title, route;
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Text(title, style: AppTextStyles.h4.copyWith(fontSize: 15))),
    TextButton(onPressed: () => context.push(route), child: const Text('Xem tất cả')),
  ]);
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place});
  final (String, String, String, String) place;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.push('/destinations'),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(fit: StackFit.expand, children: [
        CachedNetworkImage(imageUrl: place.$3, fit: BoxFit.cover),
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0xC7000000)],
        ))),
        Positioned(left: 11, right: 9, bottom: 10, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(place.$1, style: AppTextStyles.label.copyWith(color: Colors.white, fontSize: 11)),
          Text(place.$2, style: AppTextStyles.caption.copyWith(color: Colors.white70, fontSize: 9)),
          const SizedBox(height: 5),
          Row(children: [
            const Icon(Icons.star_rounded, color: AppColors.gold, size: 13),
            const SizedBox(width: 3),
            Text(place.$4, style: AppTextStyles.caption.copyWith(color: Colors.white, fontSize: 9)),
          ]),
        ])),
      ]),
    ),
  );
}
