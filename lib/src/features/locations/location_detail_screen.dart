import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../config/app_config.dart';
import '../../core/network/api_client.dart';
import '../auth/auth_controller.dart';

class LocationDetailScreen extends ConsumerStatefulWidget {
  const LocationDetailScreen({super.key, required this.id});
  final int id;
  @override
  ConsumerState<LocationDetailScreen> createState() =>
      _LocationDetailScreenState();
}

class _LocationDetailScreenState extends ConsumerState<LocationDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController tabs;
  Map<String, dynamic>? item;
  bool loading = true, reviewing = false;
  String? error;
  final comment = TextEditingController();
  int reviewRating = 5;
  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 4, vsync: this);
    load();
  }

  @override
  void dispose() {
    tabs.dispose();
    comment.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await ref
          .read(dioProvider)
          .get('/locations/${widget.id}');
      dynamic data = unwrap(response.data);
      if (data is Map && data['location'] is Map) data = data['location'];
      if (mounted)
        setState(() => item = Map<String, dynamic>.from(data as Map));
    } catch (e) {
      if (mounted) setState(() => error = apiError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> records(List<String> keys) {
    if (item == null) return [];
    final result = <Map<String, dynamic>>[], seen = <String>{};
    for (final key in keys) {
      final value = item![key];
      if (value is List)
        for (final raw in value.whereType<Map>()) {
          final row = Map<String, dynamic>.from(raw);
          final id =
              '${row['map_id'] ?? row['view360_id'] ?? row['view_id'] ?? row['review_id'] ?? row['id'] ?? row.hashCode}';
          if (seen.add(id)) result.add(row);
        }
    }
    return result;
  }

  Future<void> submitReview() async {
    if (!ref.read(authProvider).authenticated) {
      context.push('/login');
      return;
    }
    if (comment.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your review.')),
      );
      return;
    }
    setState(() => reviewing = true);
    try {
      await ref
          .read(dioProvider)
          .post(
            '/locations/${widget.id}/reviews',
            data: {'rating': reviewRating, 'comment': comment.text.trim()},
          );
      comment.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Review submitted.')));
        await load();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(e))));
    } finally {
      if (mounted) setState(() => reviewing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: _Skeleton());
    if (error != null || item == null)
      return Scaffold(
        appBar: AppBar(),
        body: _Failure(message: error ?? 'Location not found.', retry: load),
      );
    final x = item!;
    final name = _text(x, ['name', 'title'], 'Location');
    final destination = _destination(x);
    final destinationId = _destinationId(x);
    final image = AppConfig.assetUrl(_image(x));
    final description = _clean('${x['description'] ?? ''}');
    final maps = records(['maps', 'Maps']);
    final scenes = records(['view360', 'view360s', 'View360s']);
    final reviews = records(['reviews', 'Reviews']);
    final rating =
        double.tryParse('${x['average_rating'] ?? x['rating'] ?? 0}') ?? 0;
    final reviewCount =
        int.tryParse(
          '${x['reviews_count'] ?? x['review_count'] ?? reviews.length}',
        ) ??
        reviews.length;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 390,
            pinned: true,
            stretch: true,
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFF0F172A),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  image.isEmpty
                      ? const ColoredBox(
                          color: Color(0xFF334155),
                          child: Icon(
                            Icons.place,
                            color: Colors.white,
                            size: 70,
                          ),
                        )
                      : CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x33000000), Color(0xDD000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 26,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0891B2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'LOCATION DETAIL',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 31,
                            height: 1.08,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 15,
                          runSpacing: 6,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  destination,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                            if (rating > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Color(0xFFFBBF24),
                                    size: 19,
                                  ),
                                  Text(
                                    ' ${rating.toStringAsFixed(1)} ($reviewCount reviews)',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
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
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (description.isNotEmpty)
                    Text(
                      description,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        height: 1.6,
                      ),
                    ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          Icons.map_outlined,
                          '${maps.length}',
                          'Maps',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Stat(
                          Icons.threesixty,
                          '${scenes.length}',
                          'Scenes',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Stat(
                          Icons.star_outline,
                          '$reviewCount',
                          'Reviews',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () =>
                              context.push('/view360?locationId=${widget.id}'),
                          icon: const Icon(Icons.threesixty),
                          label: const Text('Open 360'),
                        ),
                      ),
                      if (destinationId > 0) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                context.push('/destinations/$destinationId'),
                            icon: const Icon(Icons.explore_outlined),
                            label: const Text('Destination'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(pinned: true, delegate: _Header(tabs)),
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: tabs,
              builder: (_, _) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 36),
                child: switch (tabs.index) {
                  0 => _Overview(item: x, destination: destination),
                  1 => _MapTab(maps: maps, location: x, name: name),
                  2 => _Reviews(
                    reviews: reviews,
                    rating: reviewRating,
                    onRating: (v) => setState(() => reviewRating = v),
                    controller: comment,
                    submitting: reviewing,
                    onSubmit: submitReview,
                  ),
                  _ => _Scenes(scenes: scenes, locationId: widget.id),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.value, this.label);
  final IconData icon;
  final String value, label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFFEFFBFF),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Icon(icon, color: const Color(0xFF0891B2), size: 22),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
      ],
    ),
  );
}

class _Header extends SliverPersistentHeaderDelegate {
  _Header(this.controller);
  final TabController controller;
  @override
  double get minExtent => 60;
  @override
  double get maxExtent => 60;
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
      tabs: const [
        Tab(icon: Icon(Icons.info_outline, size: 17), text: 'Overview'),
        Tab(icon: Icon(Icons.map_outlined, size: 17), text: 'Map'),
        Tab(icon: Icon(Icons.star_outline, size: 17), text: 'Reviews'),
        Tab(icon: Icon(Icons.threesixty, size: 17), text: '360 Scenes'),
      ],
    ),
  );
  @override
  bool shouldRebuild(covariant _Header oldDelegate) => false;
}

class _Overview extends StatelessWidget {
  const _Overview({required this.item, required this.destination});
  final Map<String, dynamic> item;
  final String destination;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Location Information',
        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 15),
      _Info(
        Icons.location_on_outlined,
        'Address',
        '${item['address'] ?? destination}',
      ),
      const SizedBox(height: 11),
      _Info(
        Icons.my_location,
        'Coordinates',
        '${item['latitude'] ?? '-'}, ${item['longitude'] ?? '-'}',
      ),
    ],
  );
}

class _Info extends StatelessWidget {
  const _Info(this.icon, this.label, this.value);
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: const Color(0xFF0891B2)),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MapTab extends StatelessWidget {
  const _MapTab({
    required this.maps,
    required this.location,
    required this.name,
  });
  final List<Map<String, dynamic>> maps;
  final Map<String, dynamic> location;
  final String name;
  @override
  Widget build(BuildContext context) {
    final image = maps.isEmpty
        ? ''
        : AppConfig.assetUrl(
            '${maps.first['map_url'] ?? maps.first['map_file'] ?? maps.first['image_url'] ?? ''}',
          );
    return Container(
      height: 390,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image.isNotEmpty)
            CachedNetworkImage(imageUrl: image, fit: BoxFit.cover)
          else
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined, size: 54, color: Color(0xFF64748B)),
                  SizedBox(height: 8),
                  Text('No map image available'),
                ],
              ),
            ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFF0891B2),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 15)],
              ),
              child: const Icon(
                Icons.location_on,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Reviews extends StatelessWidget {
  const _Reviews({
    required this.reviews,
    required this.rating,
    required this.onRating,
    required this.controller,
    required this.submitting,
    required this.onSubmit,
  });
  final List<Map<String, dynamic>> reviews;
  final int rating;
  final ValueChanged<int> onRating;
  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Write a Review',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(
                5,
                (i) => IconButton(
                  onPressed: () => onRating(i + 1),
                  icon: Icon(
                    i < rating ? Icons.star_rounded : Icons.star_outline,
                    color: const Color(0xFFFBBF24),
                    size: 29,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLength: 1000,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Share your experience at this location…',
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: submitting ? null : onSubmit,
              child: submitting
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Review'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      const Text(
        'Location Reviews',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 12),
      if (reviews.isEmpty)
        const _EmptyBox('No reviews yet.')
      else
        ...reviews.map((r) {
          final nestedUser = r['user'];
          final reviewer =
              r['user_name'] ??
              r['reviewer_name'] ??
              (nestedUser is Map ? nestedUser['name'] : null) ??
              'Traveler';
          return Container(
            margin: const EdgeInsets.only(bottom: 11),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$reviewer',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFBBF24),
                      size: 18,
                    ),
                    Text(" ${r['rating'] ?? 0}"),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${r['comment'] ?? r['content'] ?? 'No written comment.'}',
                  style: const TextStyle(color: Color(0xFF475569), height: 1.5),
                ),
              ],
            ),
          );
        }),
    ],
  );
}

class _Scenes extends StatelessWidget {
  const _Scenes({required this.scenes, required this.locationId});
  final List<Map<String, dynamic>> scenes;
  final int locationId;
  @override
  Widget build(BuildContext context) {
    if (scenes.isEmpty)
      return const _EmptyBox('No 360 scenes available for this location.');
    return Column(
      children: scenes.asMap().entries.map((e) {
        final s = e.value;
        final id = s['view_id'] ?? s['view360_id'] ?? s['id'];
        final image = AppConfig.assetUrl(
          '${s['thumbnail_url'] ?? s['image_url'] ?? s['image'] ?? ''}',
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () =>
                  context.push('/view360?locationId=$locationId&sceneId=$id'),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    height: 92,
                    child: image.isEmpty
                        ? const ColoredBox(
                            color: Color(0xFFE0F2FE),
                            child: Icon(
                              Icons.threesixty,
                              color: Color(0xFF0891B2),
                              size: 38,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: image,
                            fit: BoxFit.cover,
                          ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${s['title'] ?? s['name'] ?? 'Scene ${e.key + 1}'}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Open 360° experience',
                            style: TextStyle(
                              color: Color(0xFF0891B2),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Color(0xFF64748B)),
    ),
  );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: const Color(0xFFE2E8F0),
    highlightColor: const Color(0xFFF8FAFC),
    child: ListView(
      children: [
        Container(height: 390, color: Colors.white),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 18),
              Container(height: 60, color: Colors.white),
              const SizedBox(height: 18),
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
          const Icon(Icons.location_off_outlined, size: 58),
          const SizedBox(height: 12),
          const Text(
            'Location not available',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
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

String _text(Map x, List<String> keys, String fallback) {
  for (final k in keys) {
    if (x[k] != null && '${x[k]}'.trim().isNotEmpty) return '${x[k]}';
  }
  return fallback;
}

String _clean(String v) =>
    v.replaceAll(RegExp('<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
String? _image(Map x) =>
    x['thumbnail_url'] ??
    x['thumbnail'] ??
    x['image_url'] ??
    x['image'] ??
    (x['travel_destination'] is Map
        ? (x['travel_destination']['thumbnail_url'] ??
              x['travel_destination']['thumbnail'])
        : null);
String _destination(Map x) =>
    '${x['travel_destination_name'] ?? (x['travel_destination'] is Map ? x['travel_destination']['name'] : null) ?? (x['TravelDestination'] is Map ? x['TravelDestination']['name'] : null) ?? 'Travel destination'}';
int _destinationId(Map x) =>
    int.tryParse(
      '${x['travel_destination_id'] ?? (x['travel_destination'] is Map ? (x['travel_destination']['travel_destination_id'] ?? x['travel_destination']['destination_id'] ?? x['travel_destination']['id']) : null) ?? 0}',
    ) ??
    0;
