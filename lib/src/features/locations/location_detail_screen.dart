import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../config/app_config.dart';
import '../../core/network/api_client.dart';
import '../auth/auth_controller.dart';
import '../../design/app_colors.dart';
import '../../design/app_text_styles.dart';
import '../../design/app_widgets.dart';

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
    tabs = TabController(length: 5, vsync: this);
    load();
  }

  @override
  void didUpdateWidget(covariant LocationDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      item = null;
      tabs.index = 0;
      load();
    }
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
        const SnackBar(content: Text('Vui lòng nhập nội dung đánh giá.')),
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
        ).showSnackBar(const SnackBar(content: Text('Đã gửi đánh giá.')));
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
    if (loading)
      return const Scaffold(backgroundColor: Colors.white, body: _Skeleton());
    if (error != null || item == null)
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.white),
        body: AppErrorState(
          error: error ?? 'Không tìm thấy địa điểm.',
          onRetry: load,
        ),
      );

    final x = item!;
    final name = _text(x, ['name', 'title'], 'Địa điểm');
    final destination = _destination(x);
    final destinationId = _destinationId(x);
    final image = AppConfig.assetUrl(_image(x) ?? '');
    final description = _clean('${x['description'] ?? ''}');
    final maps = records(['maps', 'Maps']);
    final scenes = records(['view360', 'view360s', 'View360s']);
    final reviews = records(['reviews', 'Reviews']);
    final gallery = records(['images', 'Images', 'photos', 'gallery']);
    final rating =
        double.tryParse('${x['average_rating'] ?? x['rating'] ?? 0}') ?? 0;
    final reviewCount =
        int.tryParse(
          '${x['reviews_count'] ?? x['review_count'] ?? reviews.length}',
        ) ??
        reviews.length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: false,
            stretch: true,
            backgroundColor: Colors.white,
            foregroundColor: AppColors.ink,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: IconButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/locations');
                  }
                },
                icon: const Icon(Icons.arrow_back_rounded, size: 19),
                style: IconButton.styleFrom(backgroundColor: Colors.white),
              ),
            ),
            leadingWidth: 58,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  image.isEmpty
                      ? const ColoredBox(
                          color: AppColors.dark,
                          child: Icon(
                            Icons.place_rounded,
                            color: Colors.white54,
                            size: 80,
                          ),
                        )
                      : CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
                  const AppHeroOverlay(),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppBadge(label: 'ĐỊA ĐIỂM'),
                        const SizedBox(height: 10),
                        Text(
                          name,
                          style: AppTextStyles.h1White.copyWith(fontSize: 26),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              color: Colors.white60,
                              size: 15,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              destination,
                              style: AppTextStyles.bodySmallWhite,
                            ),
                            if (rating > 0) ...[
                              const SizedBox(width: 14),
                              const Icon(
                                Icons.star_rounded,
                                color: AppColors.gold,
                                size: 15,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${rating.toStringAsFixed(1)} ($reviewCount đánh giá)',
                                style: AppTextStyles.bodySmallWhite,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Quick info
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (description.isNotEmpty) ...[
                    Text(
                      description,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.muted,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: AppStatCard(
                          icon: Icons.map_outlined,
                          value: '${maps.length}',
                          label: 'Bản đồ',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppStatCard(
                          icon: Icons.threesixty_rounded,
                          value: '${scenes.length}',
                          label: 'Không gian',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppStatCard(
                          icon: Icons.star_outline_rounded,
                          value: '$reviewCount',
                          label: 'Đánh giá',
                        ),
                      ),
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
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                child: switch (tabs.index) {
                  0 => _Overview(item: x, destination: destination),
                  1 => _GalleryTab(
                    images: gallery,
                    scenes: scenes,
                    heroImage: image,
                  ),
                  2 => _ScenesTab(scenes: scenes, locationId: widget.id),
                  3 => _MapTab(maps: maps, location: x, name: name),
                  _ => _Reviews(
                      reviews: reviews,
                    rating: reviewRating,
                    onRating: (v) => setState(() => reviewRating = v),
                    controller: comment,
                    submitting: reviewing,
                    onSubmit: submitReview,
                  ),
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.borderLight)),
          ),
          child: Row(
            children: [
              if (destinationId > 0) ...[
                OutlinedButton(
                  onPressed: () => context.push('/destinations/$destinationId'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(50, 48),
                    maximumSize: const Size(50, 48),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Icon(Icons.explore_outlined, size: 20),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      context.push('/view360?locationId=${widget.id}'),
                  icon: const Icon(Icons.threesixty_rounded, size: 20),
                  label: const Text('Trải nghiệm 360°'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends SliverPersistentHeaderDelegate {
  _Header(this.controller);
  final TabController controller;
  @override
  double get minExtent => 58;
  @override
  double get maxExtent => 58;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Material(
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.muted,
        indicator: BoxDecoration(
          color: AppColors.brand,
          borderRadius: BorderRadius.circular(11),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
        labelStyle: AppTextStyles.label.copyWith(fontSize: 11),
        unselectedLabelStyle: AppTextStyles.label.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(
            height: 44,
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 15),
                SizedBox(width: 6),
                Text('Tổng quan'),
              ],
            ),
          ),
          Tab(
            height: 44,
            child: Row(
              children: [
                Icon(Icons.photo_library_outlined, size: 15),
                SizedBox(width: 6),
                Text('Hình ảnh'),
              ],
            ),
          ),
          Tab(
            height: 44,
            child: Row(
              children: [
                Icon(Icons.threesixty_rounded, size: 15),
                SizedBox(width: 6),
                Text('View360'),
              ],
            ),
          ),
          Tab(
            height: 44,
            child: Row(
              children: [
                Icon(Icons.map_outlined, size: 15),
                SizedBox(width: 6),
                Text('Sơ đồ'),
              ],
            ),
          ),
          Tab(
            height: 44,
            child: Row(
              children: [
                Icon(Icons.star_outline_rounded, size: 15),
                SizedBox(width: 6),
                Text('Đánh giá'),
              ],
            ),
          ),
        ],
      ),
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
      Text('Thông tin địa điểm', style: AppTextStyles.h4),
      const SizedBox(height: 16),
      AppInfoRow(
        icon: Icons.location_on_outlined,
        label: 'Địa chỉ',
        value: '${item['address'] ?? destination}',
      ),
      const SizedBox(height: 10),
      AppInfoRow(
        icon: Icons.my_location_rounded,
        label: 'Tọa độ',
        value: '${item['latitude'] ?? '-'}, ${item['longitude'] ?? '-'}',
      ),
    ],
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
      height: 380,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.borderLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image.isNotEmpty)
            CachedNetworkImage(imageUrl: image, fit: BoxFit.cover)
          else
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.map_outlined,
                  size: 54,
                  color: AppColors.subtle,
                ),
                const SizedBox(height: 8),
                Text('Chưa có hình ảnh bản đồ', style: AppTextStyles.bodySmall),
              ],
            ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.brand,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brand.withValues(alpha: .4),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: Colors.white,
                size: 26,
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
      // Write a review
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chia sẻ trải nghiệm', style: AppTextStyles.h4),
            const SizedBox(height: 14),
            Row(
              children: List.generate(
                5,
                (i) => GestureDetector(
                  onTap: () => onRating(i + 1),
                  child: Icon(
                    i < rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: AppColors.gold,
                    size: 32,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLength: 1000,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Bạn cảm nhận thế nào về địa điểm này?',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: submitting ? null : onSubmit,
              child: submitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Gửi đánh giá'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Text('Đánh giá từ du khách', style: AppTextStyles.h4),
      const SizedBox(height: 14),
      if (reviews.isEmpty)
        AppEmptyState(
          icon: Icons.star_outline_rounded,
          title: 'Chưa có đánh giá',
          subtitle: 'Hãy là người đầu tiên chia sẻ trải nghiệm!',
        )
      else
        ...reviews.map((r) {
          final nestedUser = r['user'];
          final reviewer =
              r['user_name'] ??
              r['reviewer_name'] ??
              (nestedUser is Map ? nestedUser['name'] : null) ??
              'Du khách';
          final reviewRating = double.tryParse('${r['rating'] ?? 0}') ?? 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppAvatar(name: '$reviewer', radius: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('$reviewer', style: AppTextStyles.label),
                    ),
                    AppRatingRow(rating: reviewRating, size: 14),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${r['comment'] ?? r['content'] ?? 'Không có nội dung đánh giá.'}',
                  style: AppTextStyles.body.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          );
        }),
    ],
  );
}

class _ScenesTab extends StatelessWidget {
  const _ScenesTab({required this.scenes, required this.locationId});
  final List<Map<String, dynamic>> scenes;
  final int locationId;

  @override
  Widget build(BuildContext context) {
    if (scenes.isEmpty)
      return AppEmptyState(
        icon: Icons.threesixty_rounded,
        title: 'Chưa có không gian 360°',
        subtitle: 'Địa điểm này chưa được thêm không gian tham quan ảo.',
      );
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
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () =>
                  context.push('/view360?locationId=$locationId&sceneId=$id'),
              child: Row(
                children: [
                  Container(
                    width: 100,
                    height: 85,
                    color: AppColors.borderLight,
                    child: image.isEmpty
                        ? const Icon(
                            Icons.threesixty_rounded,
                            color: AppColors.accent,
                            size: 32,
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
                            style: AppTextStyles.label,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Mở trải nghiệm 360°',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.accent,
                      ),
                    ),
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

class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: const Color(0xFFE5E7EB),
    highlightColor: const Color(0xFFF9FAFB),
    child: ListView(
      children: [
        Container(height: 400, color: Colors.white),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 18),
              Container(height: 58, color: Colors.white),
              const SizedBox(height: 20),
              Container(
                height: 200,
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

// helpers
String _text(Map item, List<String> keys, String fallback) {
  for (final key in keys) {
    final v = item[key];
    if (v != null && '$v'.trim().isNotEmpty) return '$v';
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
    item['image'];

String _destination(Map item) {
  final dest = item['destination'] ?? item['travel_destination'];
  if (dest is Map) return '${dest['name'] ?? dest['title'] ?? 'Destination'}';
  return '${item['destination_name'] ?? 'Destination'}';
}

int _destinationId(Map item) {
  final dest = item['destination'] ?? item['travel_destination'];
  if (dest is Map)
    return int.tryParse(
          '${dest['travel_destination_id'] ?? dest['destination_id'] ?? dest['id'] ?? 0}',
        ) ??
        0;
  return int.tryParse(
        '${item['destination_id'] ?? item['travel_destination_id'] ?? 0}',
      ) ??
      0;
}
