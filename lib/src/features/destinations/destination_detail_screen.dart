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
  Icons.info_outline,
  Icons.place_outlined,
  Icons.luggage_outlined,
  Icons.threesixty,
  Icons.map_outlined,
  Icons.star_outline,
  Icons.menu_book_outlined,
];

class DestinationDetailScreen extends ConsumerStatefulWidget {
  const DestinationDetailScreen({super.key, required this.id});
  final int id;
  @override
  ConsumerState<DestinationDetailScreen> createState() =>
      _DestinationDetailScreenState();
}

class _DestinationDetailScreenState
    extends ConsumerState<DestinationDetailScreen>
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
      final response = await ref
          .read(dioProvider)
          .get('/travel-destinations/${widget.id}');
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
      final ids = data is Map
          ? data['destination_ids'] ?? data['destinations']
          : null;
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
      await ref
          .read(dioProvider)
          .post('/saved/destinations/${widget.id}/toggle');
    } catch (e) {
      if (mounted) {
        setState(() => _saved = !_saved);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: _DetailSkeleton());
    if (_error != null || _item == null)
      return Scaffold(
        appBar: AppBar(),
        body: _Failure(
          message: _error ?? 'Destination not found.',
          retry: _load,
        ),
      );
    final item = _item!;
    final name = _text(item, ['name', 'title'], 'Destination');
    final country = _text(item, ['country', 'city'], 'Vietnam');
    final region = _text(item, ['region', 'address'], 'Vietnam');
    final description = _clean('${item['description'] ?? ''}');
    final image = AppConfig.assetUrl(_image(item));
    final rating =
        double.tryParse('${item['average_rating'] ?? item['rating'] ?? 0}') ??
        0;
    final reviews = item['reviews_count'] ?? item['review_count'] ?? 0;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 440,
            pinned: true,
            stretch: true,
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            actions: [
              IconButton.filledTonal(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text:
                          'https://travellens-gamma.vercel.app/destinations/${widget.id}',
                    ),
                  );
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Destination link copied.')),
                    );
                },
                icon: const Icon(Icons.share_outlined),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: IconButton.filledTonal(
                  onPressed: _toggleSaved,
                  icon: Icon(
                    _saved ? Icons.favorite : Icons.favorite_border,
                    color: _saved ? const Color(0xFFE11D48) : null,
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  image.isEmpty
                      ? const ColoredBox(color: Color(0xFF334155))
                      : CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x33000000), Color(0xE6000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 30,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0891B2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'TOP DESTINATION',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 13),
                        Text(
                          '$name, $country',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            height: 1.08,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 11),
                        Wrap(
                          spacing: 16,
                          runSpacing: 7,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFFBBF24),
                                  size: 19,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${rating > 0 ? rating.toStringAsFixed(1) : 'New'} ($reviews reviews)',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    region,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFDDE7EE),
                              height: 1.45,
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
          SliverToBoxAdapter(
            child: _QuickFacts(
              item: item,
              name: name,
              country: country,
              on360: () => context.push('/view360?destinationId=${widget.id}'),
            ),
          ),
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
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 34),
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

class _QuickFacts extends StatelessWidget {
  const _QuickFacts({
    required this.item,
    required this.name,
    required this.country,
    required this.on360,
  });
  final Map<String, dynamic> item;
  final String name, country;
  final VoidCallback on360;
  @override
  Widget build(BuildContext context) {
    final categoryRaw = item['destination_category'] ?? item['category'];
    final category = categoryRaw is Map
        ? '${categoryRaw['name'] ?? 'Destination'}'
        : '${categoryRaw ?? item['category_name'] ?? 'Destination'}';
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$name, $country',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  category,
                  style: const TextStyle(
                    color: Color(0xFF0369A1),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Fact(
                icon: Icons.calendar_today_outlined,
                label: 'Best time',
                value: _text(item, ['best_time'], 'All year'),
              ),
              const _Fact(
                icon: Icons.language,
                label: 'Language',
                value: 'Vietnamese',
              ),
              const _Fact(
                icon: Icons.payments_outlined,
                label: 'Currency',
                value: 'VND',
              ),
              _Fact(
                icon: Icons.my_location,
                label: 'Coordinates',
                value:
                    '${item['latitude'] ?? '-'}, ${item['longitude'] ?? '-'}',
              ),
            ],
          ),
          const SizedBox(height: 17),
          FilledButton.icon(
            onPressed: on360,
            icon: const Icon(Icons.threesixty),
            label: const Text('Explore in 360°'),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    width: (MediaQuery.sizeOf(context).width - 42) / 2,
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF0891B2)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TabsHeader extends SliverPersistentHeaderDelegate {
  _TabsHeader({
    required this.controller,
    required this.labels,
    required this.icons,
  });
  final TabController controller;
  final List<String> labels;
  final List<IconData> icons;
  @override
  double get minExtent => 62;
  @override
  double get maxExtent => 62;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Material(
    color: Colors.white,
    elevation: overlapsContent ? 2 : 0,
    child: TabBar(
      controller: controller,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      labelColor: const Color(0xFF0891B2),
      unselectedLabelColor: const Color(0xFF64748B),
      indicatorColor: const Color(0xFF0891B2),
      indicatorWeight: 3,
      tabs: List.generate(
        labels.length,
        (i) => Tab(icon: Icon(icons[i], size: 17), text: labels[i]),
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
    final keys = [
      null,
      'locations',
      'tours',
      'view360',
      'maps',
      'reviews',
      'blogs',
    ];
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
      return _Empty(
        title: 'No ${_destinationTabLabels[index].toLowerCase()} available',
        text: 'Content has not been added to $destinationName yet.',
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titles[index],
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 16),
        ...values.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 13),
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
      Text(
        'About $name',
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 12),
      Text(
        description.isEmpty
            ? 'No overview has been added for this destination.'
            : description,
        style: const TextStyle(
          fontSize: 15,
          height: 1.75,
          color: Color(0xFF475569),
        ),
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
    final resolved = AppConfig.assetUrl(_image(item));
    final image = resolved.isEmpty ? fallbackImage : resolved;
    final title = _text(item, [
      'name',
      'title',
      'user_name',
      'reviewer_name',
    ], 'Item');
    final description = _clean(
      '${item['description'] ?? item['comment'] ?? item['content'] ?? ''}',
    );
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            if (image.isNotEmpty && type != 5)
              SizedBox(
                width: 116,
                height: 116,
                child: CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _destinationTabIcons[type],
                          size: 18,
                          color: const Color(0xFF0891B2),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (type == 5) ...[
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFBBF24),
                            size: 18,
                          ),
                          Text(' ${item['rating'] ?? 0}'),
                        ],
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          height: 1.45,
                        ),
                      ),
                    ],
                    if (type == 2 && item['price'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        NumberFormat.currency(
                          locale: 'vi_VN',
                          symbol: '₫',
                        ).format(num.tryParse('${item['price']}') ?? 0),
                        style: const TextStyle(
                          color: Color(0xFF0891B2),
                          fontWeight: FontWeight.w800,
                        ),
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

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.text});
  final String title, text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 46),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFCBD5E1)),
    ),
    child: Column(
      children: [
        const Icon(Icons.inbox_outlined, size: 42, color: Color(0xFF94A3B8)),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF64748B)),
        ),
      ],
    ),
  );
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.travel_explore, size: 58),
          const SizedBox(height: 14),
          const Text(
            'Destination not available',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: retry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: const Color(0xFFE2E8F0),
    highlightColor: const Color(0xFFF8FAFC),
    child: ListView(
      children: [
        Container(height: 440, color: Colors.white),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 18),
              Container(height: 58, color: Colors.white),
              const SizedBox(height: 20),
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
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

String _clean(String value) => value
    .replaceAll(RegExp('<[^>]*>'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
String? _image(Map item) =>
    item['thumbnail_url'] ??
    item['thumbnail'] ??
    item['image_url'] ??
    item['image'] ??
    item['map_url'] ??
    item['map_file'];
int _relatedId(Map item, int type) =>
    int.tryParse(
      '${type == 1
          ? item['location_id'] ?? item['id']
          : type == 2
          ? item['tour_id'] ?? item['id']
          : item['id'] ?? 0}',
    ) ??
    0;
