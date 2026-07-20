import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  Future<void> shareLocation() async {
    await Clipboard.setData(
      ClipboardData(
        text: 'https://travellens-gamma.vercel.app/locations/${widget.id}',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã sao chép liên kết địa điểm.')),
    );
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
    final image = AppConfig.assetUrl(_image(x) ?? '');
    final description = _clean('${x['description'] ?? ''}');
    final maps = records(['maps', 'Maps']);
    final scenes = records(['view360', 'view360s', 'View360s']);
    final reviews = records(['reviews', 'Reviews']);
    final gallery = records(['images', 'Images', 'photos', 'gallery']);
    final featuredImages = <String>{
      if (image.isNotEmpty) image,
      ...gallery.map((entry) => AppConfig.assetUrl(_image(entry) ?? '')),
      ...scenes.map((entry) => AppConfig.assetUrl(_image(entry) ?? '')),
    }.where((url) => url.isNotEmpty).take(3).toList();
    final rating =
        double.tryParse('${x['average_rating'] ?? x['rating'] ?? 0}') ?? 0;
    final reviewCount =
        int.tryParse(
          '${x['reviews_count'] ?? x['review_count'] ?? reviews.length}',
        ) ??
        reviews.length;

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: _HeroCircleButton(
            icon: Icons.arrow_back_rounded,
            onTap: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/locations');
              }
            },
          ),
        ),
        leadingWidth: 56,
        actions: [
          _HeroCircleButton(
            icon: Icons.ios_share_rounded,
            onTap: shareLocation,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 272,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  image.isEmpty
                      ? const ColoredBox(
                          color: AppColors.borderLight,
                          child: Icon(
                            Icons.place_rounded,
                            color: AppColors.subtle,
                            size: 64,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: image,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => const ColoredBox(
                            color: AppColors.borderLight,
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x22000000), Color(0x33000000)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Quick info
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTextStyles.h3.copyWith(fontSize: 20)),
                  const SizedBox(height: 5),
                  Text(destination, style: AppTextStyles.bodySmall),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: AppColors.gold,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rating > 0 ? rating.toStringAsFixed(1) : 'Mới',
                        style: AppTextStyles.label.copyWith(fontSize: 11),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '($reviewCount đánh giá)',
                        style: AppTextStyles.caption.copyWith(fontSize: 10),
                      ),
                      const SizedBox(width: 14),
                      const Icon(
                        Icons.radio_button_checked_rounded,
                        size: 13,
                        color: AppColors.brand,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Điểm tham quan',
                        style: AppTextStyles.caption.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
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
                        child: _CompactStat(
                          icon: Icons.map_outlined,
                          value: '${maps.length}',
                          label: 'Bản đồ',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CompactStat(
                          icon: Icons.threesixty_rounded,
                          value: '${scenes.length}',
                          label: 'Không gian',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CompactStat(
                          icon: Icons.star_outline_rounded,
                          value: '$reviewCount',
                          label: 'Đánh giá',
                        ),
                      ),
                    ],
                  ),
                  if (featuredImages.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Ảnh nổi bật',
                            style: AppTextStyles.h4.copyWith(fontSize: 14),
                          ),
                        ),
                        TextButton(
                          onPressed: () => tabs.animateTo(1),
                          child: const Text('Xem tất cả'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 106,
                      child: Row(
                        children: [
                          for (
                            var index = 0;
                            index < featuredImages.length;
                            index++
                          ) ...[
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CachedNetworkImage(
                                  imageUrl: featuredImages[index],
                                  height: 106,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            if (index < featuredImages.length - 1)
                              const SizedBox(width: 7),
                          ],
                        ],
                      ),
                    ),
                  ],
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
      bottomNavigationBar: AnimatedBuilder(
        animation: tabs,
        builder: (context, _) {
          if (tabs.index != 0 && tabs.index != 2) {
            return const SizedBox.shrink();
          }
          final view360 = tabs.index == 2;
          return SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.borderLight)),
              ),
              child: FilledButton.icon(
                onPressed: view360
                    ? () => context.push('/view360?locationId=${widget.id}')
                    : () => tabs.animateTo(3),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  maximumSize: const Size.fromHeight(48),
                ),
                icon: Icon(
                  view360 ? Icons.threesixty_rounded : Icons.map_outlined,
                  size: 20,
                ),
                label: Text(view360 ? 'Mở View360°' : 'Xem bản đồ'),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeroCircleButton extends StatelessWidget {
  const _HeroCircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .95),
    shape: const CircleBorder(),
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 38,
        height: 38,
        child: Icon(icon, size: 19, color: AppColors.ink),
      ),
    ),
  );
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

class _CompactStat extends StatelessWidget {
  const _CompactStat({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
    decoration: BoxDecoration(
      color: AppColors.accentLight,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Icon(icon, size: 17, color: AppColors.brand),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.label.copyWith(
            color: AppColors.brand,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 1),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 9)),
      ],
    ),
  );
}

class _CompactInfo extends StatelessWidget {
  const _CompactInfo({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.borderLight),
    ),
    child: Row(
      children: [
        Icon(icon, size: 16, color: AppColors.brand),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption.copyWith(fontSize: 9)),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label.copyWith(fontSize: 9),
              ),
            ],
          ),
        ),
      ],
    ),
  );
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
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _CompactInfo(
              icon: Icons.location_on_outlined,
              label: 'Địa chỉ',
              value: '${item['address'] ?? destination}',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _CompactInfo(
              icon: Icons.my_location_rounded,
              label: 'Tọa độ',
              value: '${item['latitude'] ?? '-'}, ${item['longitude'] ?? '-'}',
            ),
          ),
        ],
      ),
    ],
  );
}

class _GalleryTab extends StatelessWidget {
  const _GalleryTab({
    required this.images,
    required this.scenes,
    required this.heroImage,
  });
  final List<Map<String, dynamic>> images;
  final List<Map<String, dynamic>> scenes;
  final String heroImage;

  @override
  Widget build(BuildContext context) {
    final urls = <String>{
      if (heroImage.isNotEmpty) heroImage,
      ...images.map((entry) => AppConfig.assetUrl(_image(entry) ?? '')),
      ...scenes.map((entry) => AppConfig.assetUrl(_image(entry) ?? '')),
    }.where((url) => url.isNotEmpty).toList();
    if (urls.isEmpty) {
      return const AppEmptyState(
        icon: Icons.photo_library_outlined,
        title: 'Chưa có hình ảnh',
        subtitle: 'Thư viện ảnh của địa điểm đang được cập nhật.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Thư viện ảnh', style: AppTextStyles.h4),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: const [
              _GalleryChip(label: 'Tất cả', selected: true),
              _GalleryChip(label: 'Toàn cảnh'),
              _GalleryChip(label: 'Điểm nổi bật'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(urls.length, (index) {
                final height = index % 3 == 0 ? 192.0 : 144.0;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: urls[index],
                    width: width,
                    height: height,
                    fit: BoxFit.cover,
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}

class _GalleryChip extends StatelessWidget {
  const _GalleryChip({required this.label, this.selected = false});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: selected ? AppColors.brand : AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: selected ? AppColors.brand : AppColors.border),
    ),
    child: Text(
      label,
      style: AppTextStyles.caption.copyWith(
        color: selected ? Colors.white : AppColors.muted,
      ),
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.borderLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 176,
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
                        size: 36,
                        color: AppColors.subtle,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Chưa có hình ảnh bản đồ',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brand.withValues(alpha: .3),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              maps.isEmpty
                  ? 'Sơ đồ tham quan $name'
                  : '${maps.first['name'] ?? maps.first['title'] ?? 'Sơ đồ tham quan $name'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(fontSize: 11),
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

  void _openReviewForm(BuildContext context) {
    var selectedRating = rating;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            0,
            18,
            MediaQuery.viewInsetsOf(context).bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chia sẻ trải nghiệm', style: AppTextStyles.h4),
              const SizedBox(height: 12),
              Row(
                children: List.generate(
                  5,
                  (index) => IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      selectedRating = index + 1;
                      onRating(selectedRating);
                      setSheetState(() {});
                    },
                    icon: Icon(
                      index < selectedRating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: AppColors.gold,
                      size: 25,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                maxLength: 1000,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Bạn cảm nhận thế nào về địa điểm này?',
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: submitting
                    ? null
                    : () {
                        Navigator.pop(sheetContext);
                        onSubmit();
                      },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Gửi đánh giá'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text('Đánh giá từ du khách', style: AppTextStyles.h4),
          ),
          OutlinedButton.icon(
            onPressed: () => _openReviewForm(context),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 11),
            ),
            icon: const Icon(Icons.edit_outlined, size: 15),
            label: const Text('Viết đánh giá'),
          ),
        ],
      ),
      const SizedBox(height: 12),
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
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppAvatar(name: '$reviewer', radius: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('$reviewer', style: AppTextStyles.label),
                    ),
                    AppRatingRow(rating: reviewRating, size: 13),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${r['comment'] ?? r['content'] ?? 'Không có nội dung đánh giá.'}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.muted,
                  ),
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
        Container(height: 272, color: Colors.white),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
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
