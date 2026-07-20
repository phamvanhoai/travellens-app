import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../config/app_config.dart';
import '../../core/network/api_client.dart';
import '../auth/auth_controller.dart';
import '../../design/app_colors.dart';
import '../../design/app_text_styles.dart';
import '../../design/app_widgets.dart';

const _destinationTabLabels = [
  'Overview',
  'Locations',
  'Tours',
  '360°',
  'Map',
  'Reviews',
  'Guide',
];
const _destinationTabIcons = [
  Icons.info_outline_rounded,
  Icons.place_outlined,
  Icons.luggage_outlined,
  Icons.threesixty_rounded,
  Icons.map_outlined,
  Icons.star_outline_rounded,
  Icons.menu_book_outlined,
];

class DestinationDetailScreen extends ConsumerStatefulWidget {
  const DestinationDetailScreen({super.key, required this.id});
  final int id;
  @override
  ConsumerState<DestinationDetailScreen> createState() => _DestinationDetailScreenState();
}

class _DestinationDetailScreenState extends ConsumerState<DestinationDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Map<String, dynamic>? _item;
  String? _error;
  bool _loading = true, _saved = false, _saving = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _destinationTabLabels.length, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(dioProvider).get('/travel-destinations/${widget.id}');
      dynamic data = unwrap(response.data);
      if (data is Map && data['destination'] is Map) data = data['destination'];
      if (data is Map && data['travel_destination'] is Map)
        data = data['travel_destination'];
      if (!mounted) return;
      setState(() => _item = Map<String, dynamic>.from(data as Map));
      await _loadSaved();
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSaved() async {
    if (!ref.read(authProvider).authenticated) return;
    try {
      final response = await ref.read(dioProvider).get('/saved/ids');
      final data = unwrap(response.data);
      final ids = data is Map ? data['destination_ids'] ?? data['destinations'] : null;
      if (mounted && ids is List)
        setState(() => _saved = ids.any((id) => '$id' == '${widget.id}'));
    } catch (_) {}
  }

  Future<void> _toggleSaved() async {
    if (!ref.read(authProvider).authenticated) {
      context.push('/login');
      return;
    }
    if (_saving) return;
    setState(() {
      _saving = true;
      _saved = !_saved;
    });
    try {
      await ref.read(dioProvider).post('/saved/destinations/${widget.id}/toggle');
    } catch (e) {
      if (mounted) {
        setState(() => _saved = !_saved);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiError(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(backgroundColor: AppColors.surface, body: _DetailSkeleton());
    if (_error != null || _item == null)
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.white),
        body: AppErrorState(error: _error ?? 'Destination not found.', onRetry: _load),
      );

    final item = _item!;
    final name = _text(item, ['name', 'title'], 'Destination');
    final country = _text(item, ['country', 'city'], 'Vietnam');
    final region = _text(item, ['region', 'address'], 'Vietnam');
    final description = _clean('${item['description'] ?? ''}');
    final image = AppConfig.assetUrl(_image(item) ?? '');
    final rating = double.tryParse('${item['average_rating'] ?? item['rating'] ?? 0}') ?? 0;
    final reviews = item['reviews_count'] ?? item['review_count'] ?? 0;
    final categoryRaw = item['destination_category'] ?? item['category'];
    final category = categoryRaw is Map
        ? '${categoryRaw['name'] ?? 'Destination'}'
        : '${categoryRaw ?? item['category_name'] ?? 'Destination'}';

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          // Hero SliverAppBar
          SliverAppBar(
            expandedHeight: 460,
            pinned: true,
            stretch: true,
            backgroundColor: AppColors.dark,
            foregroundColor: Colors.white,
            actions: [
              _HeroActionBtn(
                icon: Icons.share_outlined,
                onTap: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text: 'https://travellens-gamma.vercel.app/destinations/${widget.id}',
                    ),
                  );
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Destination link copied.')),
                    );
                },
              ),
              _HeroActionBtn(
                icon: _saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                iconColor: _saved ? const Color(0xFFFF4D6D) : Colors.white,
                onTap: _toggleSaved,
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  image.isEmpty
                      ? const ColoredBox(color: AppColors.dark)
                      : CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
                  const AppHeroOverlay(strong: true),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 32,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppBadge(label: category, color: AppColors.accent),
                        const SizedBox(height: 12),
                        Text(
                          '$name,\n$country',
                          style: AppTextStyles.h1White.copyWith(fontSize: 32),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: AppColors.gold, size: 18),
                            const SizedBox(width: 5),
                            Text(
                              '${rating > 0 ? rating.toStringAsFixed(1) : 'New'} · $reviews reviews',
                              style: AppTextStyles.bodySmallWhite,
                            ),
                            const SizedBox(width: 16),
                            const Icon(Icons.location_on_rounded, color: Colors.white60, size: 16),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(region, style: AppTextStyles.bodySmallWhite),
                            ),
                          ],
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmallWhite,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Quick facts
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(name, style: AppTextStyles.h3)),
                      AppBadge(label: category, soft: true, color: AppColors.accent),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _FactChip(Icons.calendar_today_outlined, 'Best time',
                            _text(item, ['best_time'], 'All year')),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _FactChip(Icons.language_rounded, 'Language', 'Vietnamese'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _FactChip(Icons.payments_outlined, 'Currency', 'VND'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _FactChip(
                          Icons.my_location_rounded,
                          'Coordinates',
                          '${item['latitude'] ?? '-'}, ${item['longitude'] ?? '-'}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => context.push('/view360?destinationId=${widget.id}'),
                    icon: const Icon(Icons.threesixty_rounded, size: 20),
                    label: const Text('Explore in 360°'),
                  ),
                ],
              ),
            ),
          ),

          // Tabs
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabsHeader(
              controller: _tabs,
              labels: _destinationTabLabels,
              icons: _destinationTabIcons,
            ),
          ),

          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _tabs,
              builder: (_, _) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
                child: _TabContent(
                  index: _tabs.index,
                  item: item,
                  destinationName: name,
                  fallbackImage: image,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroActionBtn extends StatelessWidget {
  const _HeroActionBtn({required this.icon, required this.onTap, this.iconColor = Colors.white});
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    icon: Icon(icon, color: iconColor, size: 20),
    style: IconButton.styleFrom(
      backgroundColor: Colors.black38,
    ),
  );
}

class _FactChip extends StatelessWidget {
  const _FactChip(this.icon, this.label, this.value);
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        Icon(icon, size: 16, color: AppColors.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: AppTextStyles.labelSmall),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TabsHeader extends SliverPersistentHeaderDelegate {
  _TabsHeader({required this.controller, required this.labels, required this.icons});
  final TabController controller;
  final List<String> labels;
  final List<IconData> icons;

  @override
  double get minExtent => 58;
  @override
  double get maxExtent => 58;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Material(
    color: Colors.white,
    elevation: overlapsContent ? 1.5 : 0,
    shadowColor: AppColors.dark.withValues(alpha: .08),
    child: TabBar(
      controller: controller,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      labelColor: AppColors.brand,
      unselectedLabelColor: AppColors.muted,
      indicatorColor: AppColors.brand,
      indicatorWeight: 2.5,
      dividerColor: AppColors.border,
      labelStyle: AppTextStyles.label.copyWith(fontSize: 13),
      unselectedLabelStyle: AppTextStyles.label.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      tabs: List.generate(
        labels.length,
        (i) => Tab(icon: Icon(icons[i], size: 16), text: labels[i]),
      ),
    ),
  );

  @override
  bool shouldRebuild(covariant _TabsHeader oldDelegate) => false;
}

class _TabContent extends StatelessWidget {
  const _TabContent({
    required this.index,
    required this.item,
    required this.destinationName,
    required this.fallbackImage,
  });
  final int index;
  final Map<String, dynamic> item;
  final String destinationName, fallbackImage;

  @override
  Widget build(BuildContext context) {
    if (index == 0)
      return _Overview(
        name: destinationName,
        description: _clean('${item['description'] ?? ''}'),
      );
    final keys = [null, 'locations', 'tours', 'view360', 'maps', 'reviews', 'blogs'];
    final values = _records(item[keys[index]]);
    final titles = [
      '',
      'Locations in $destinationName',
      'Tours in $destinationName',
      '360° Experiences',
      '$destinationName Maps',
      'Traveler Reviews',
      'Travel Guides',
    ];
    if (values.isEmpty)
      return AppEmptyState(
        icon: _destinationTabIcons[index],
        title: 'No ${_destinationTabLabels[index].toLowerCase()} yet',
        subtitle: 'Content has not been added to $destinationName yet.',
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titles[index], style: AppTextStyles.h3),
        const SizedBox(height: 16),
        ...values.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RelatedCard(
              item: entry.value,
              type: index,
              fallbackImage: fallbackImage,
              onTap: () {
                final id = _relatedId(entry.value, index);
                if (index == 1 && id > 0) context.push('/locations/$id');
                if (index == 2 && id > 0) context.push('/tours/$id');
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.name, required this.description});
  final String name, description;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('About $name', style: AppTextStyles.h3),
      const SizedBox(height: 14),
      Text(
        description.isEmpty
            ? 'No overview has been added for this destination.'
            : description,
        style: AppTextStyles.body.copyWith(color: AppColors.muted),
      ),
    ],
  );
}

class _RelatedCard extends StatelessWidget {
  const _RelatedCard({
    required this.item,
    required this.type,
    required this.fallbackImage,
    required this.onTap,
  });
  final Map<String, dynamic> item;
  final int type;
  final String fallbackImage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final resolved = AppConfig.assetUrl(_image(item) ?? '');
    final image = resolved.isEmpty ? fallbackImage : resolved;
    final title = _text(item, ['name', 'title', 'user_name', 'reviewer_name'], 'Item');
    final description = _clean(
      '${item['description'] ?? item['comment'] ?? item['content'] ?? ''}',
    );
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            if (image.isNotEmpty && type != 5)
              SizedBox(
                width: 100,
                height: 100,
                child: CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(_destinationTabIcons[type], size: 14, color: AppColors.accent),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.h4.copyWith(fontSize: 15),
                          ),
                        ),
                        if (type == 5) ...[
                          const Icon(Icons.star_rounded, color: AppColors.gold, size: 15),
                          Text(' ${item['rating'] ?? 0}', style: AppTextStyles.label),
                        ],
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                    if (type == 2 && item['price'] != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(
                          num.tryParse('${item['price']}') ?? 0,
                        ),
                        style: AppTextStyles.label.copyWith(color: AppColors.brand),
                      ),
                    ],
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

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: const Color(0xFFE5E7EB),
    highlightColor: const Color(0xFFF9FAFB),
    child: ListView(
      children: [
        Container(height: 460, color: Colors.white),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                height: 130,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 18),
              Container(height: 58, color: Colors.white),
              const SizedBox(height: 20),
              Container(
                height: 240,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

List<Map<String, dynamic>> _records(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : [];

String _text(Map item, List<String> keys, String fallback) {
  for (final key in keys) {
    final value = item[key];
    if (value != null && '$value'.trim().isNotEmpty) return '$value';
  }
  return fallback;
}

String _clean(String value) =>
    value.replaceAll(RegExp('<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

String? _image(Map item) =>
    item['thumbnail_url'] ??
    item['thumbnail'] ??
    item['image_url'] ??
    item['image'] ??
    item['map_url'] ??
    item['map_file'];

int _relatedId(Map item, int type) =>
    int.tryParse(
      '${type == 1 ? item['location_id'] ?? item['id'] : type == 2 ? item['tour_id'] ?? item['id'] : item['id'] ?? 0}',
    ) ??
    0;
