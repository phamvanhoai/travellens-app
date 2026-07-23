import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../design/app_colors.dart';
import '../../design/app_text_styles.dart';
import '../../design/app_widgets.dart';
import '../../widgets/network_map_image.dart';
import '../auth/auth_controller.dart';
import 'saved_destinations_controller.dart';

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
  Map<String, dynamic>? _item;
  String? _error;
  bool _loading = true;
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabLabels.length, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DestinationDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _item = null;
      _tabs.index = 0;
      _load();
    }
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
      if (data is Map && data['destination'] is Map) {
        data = data['destination'];
      }
      if (data is Map && data['travel_destination'] is Map) {
        data = data['travel_destination'];
      }
      if (!mounted) return;
      setState(() => _item = Map<String, dynamic>.from(data as Map));
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleSaved() async {
    if (!ref.read(authProvider).authenticated) {
      context.push('/login');
      return;
    }
    try {
      await ref.read(savedDestinationsProvider.notifier).toggle(widget.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(e))));
      }
    }
  }

  Future<void> _share() async {
    await Clipboard.setData(
      ClipboardData(
        text: 'https://travellens-gamma.vercel.app/destinations/${widget.id}',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã sao chép liên kết điểm đến.')),
    );
  }

  void _exploreTours(List<Map<String, dynamic>> tours) {
    if (tours.isNotEmpty) {
      final id = _relatedId(tours.first, 'tour');
      if (id > 0) {
        context.push('/tours/$id');
        return;
      }
    }
    context.push('/tours');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: _DetailSkeleton(),
      );
    }
    if (_error != null || _item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: AppErrorState(
          error: _error ?? 'Không tìm thấy điểm đến.',
          onRetry: _load,
        ),
      );
    }

    final item = _item!;
    final name = _text(item, ['name', 'title'], 'Điểm đến');
    final country = _text(item, ['country', 'city'], 'Việt Nam');
    final categoryRaw = item['destination_category'] ?? item['category'];
    final subtitle = categoryRaw is Map
        ? '${categoryRaw['name'] ?? 'Điểm đến nổi bật'}'
        : '${categoryRaw ?? item['category_name'] ?? 'Điểm đến nổi bật'}';
    final description = _clean('${item['description'] ?? ''}');
    final image = AppConfig.assetUrl(_image(item) ?? '');
    final rating =
        double.tryParse('${item['average_rating'] ?? item['rating'] ?? 0}') ??
        0;
    final reviews =
        int.tryParse('${item['reviews_count'] ?? item['review_count'] ?? 0}') ??
        0;
    final locations = _records(item['locations']);
    final tours = _records(item['tours']);
    final scenes = _records(item['view360']);
    final maps = _records(item['maps']);
    final reviewItems = _records(item['reviews']);
    final blogs = _records(item['blogs']);
    final temperature =
        '${item['temperature'] ?? item['weather_temperature'] ?? '28'}';
    final weather = '${item['weather'] ?? item['weather_condition'] ?? 'Nắng'}';
    final saved = ref.watch(savedDestinationsProvider).contains(widget.id);

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: _CircleAction(
            icon: Icons.arrow_back_rounded,
            onTap: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/destinations');
              }
            },
          ),
        ),
        leadingWidth: 56,
        actions: [
          _CircleAction(
            icon: saved
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: saved ? const Color(0xFFFF4D5E) : AppColors.ink,
            onTap: _toggleSaved,
          ),
          const SizedBox(width: 8),
          _CircleAction(icon: Icons.ios_share_rounded, onTap: _share),
          const SizedBox(width: 12),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 272,
              child: image.isEmpty
                  ? const ColoredBox(
                      color: AppColors.borderLight,
                      child: Icon(
                        Icons.landscape_outlined,
                        size: 64,
                        color: AppColors.subtle,
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
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$name, $country',
                    style: AppTextStyles.h3.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 14),
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
                        '($reviews đánh giá)',
                        style: AppTextStyles.caption.copyWith(fontSize: 10),
                      ),
                      const SizedBox(width: 14),
                      const _Dot(),
                      const SizedBox(width: 14),
                      const Icon(
                        Icons.wb_sunny_outlined,
                        color: AppColors.subtle,
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$temperature°C · $weather',
                        style: AppTextStyles.caption.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(
                    description.isEmpty
                        ? 'Khám phá vẻ đẹp, văn hóa và những trải nghiệm độc đáo tại $name.'
                        : description,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.muted,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _DestinationTabBar(controller: _tabs),
                  const SizedBox(height: 20),
                  AnimatedBuilder(
                    animation: _tabs,
                    builder: (context, _) => AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _DestinationTabContent(
                        key: ValueKey(_tabs.index),
                        index: _tabs.index,
                        destinationId: widget.id,
                        destinationName: name,
                        description: description,
                        item: item,
                        locations: locations,
                        tours: tours,
                        scenes: scenes,
                        maps: maps,
                        reviews: reviewItems,
                        blogs: blogs,
                        fallbackImage: image,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: AppColors.borderLight)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .04),
                blurRadius: 14,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: _toggleSaved,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(50, 48),
                  maximumSize: const Size(50, 48),
                  padding: EdgeInsets.zero,
                ),
                child: Icon(
                  saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 21,
                  color: saved ? AppColors.brand : AppColors.ink,
                ),
              ),
              if (tours.isNotEmpty) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _exploreTours(tours),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(50, 48),
                    maximumSize: const Size(50, 48),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Icon(
                    Icons.card_travel_outlined,
                    size: 20,
                    color: AppColors.ink,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      context.push('/view360?destinationId=${widget.id}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.threesixty_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Trải nghiệm 360°'),
                    ],
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

const _tabLabels = [
  'Tổng quan',
  'Địa điểm',
  'Tour',
  '360°',
  'Bản đồ',
  'Đánh giá',
  'Cẩm nang',
];

const _tabIcons = [
  Icons.info_outline_rounded,
  Icons.place_outlined,
  Icons.card_travel_outlined,
  Icons.threesixty_rounded,
  Icons.map_outlined,
  Icons.star_outline_rounded,
  Icons.menu_book_outlined,
];

class _DestinationTabBar extends StatelessWidget {
  const _DestinationTabBar({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) => Container(
    height: 58,
    color: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 7),
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
      tabs: List.generate(
        _tabLabels.length,
        (index) => Tab(
          height: 44,
          child: Row(
            children: [
              Icon(_tabIcons[index], size: 15),
              const SizedBox(width: 6),
              Text(_tabLabels[index]),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DestinationTabContent extends StatelessWidget {
  const _DestinationTabContent({
    super.key,
    required this.index,
    required this.destinationId,
    required this.destinationName,
    required this.description,
    required this.item,
    required this.locations,
    required this.tours,
    required this.scenes,
    required this.maps,
    required this.reviews,
    required this.blogs,
    required this.fallbackImage,
  });
  final int index;
  final int destinationId;
  final String destinationName;
  final String description;
  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> locations;
  final List<Map<String, dynamic>> tours;
  final List<Map<String, dynamic>> scenes;
  final List<Map<String, dynamic>> maps;
  final List<Map<String, dynamic>> reviews;
  final List<Map<String, dynamic>> blogs;
  final String fallbackImage;

  @override
  Widget build(BuildContext context) {
    switch (index) {
      case 0:
        return _OverviewTab(
          name: destinationName,
          description: description,
          item: item,
        );
      case 1:
        return _RecordsTab(
          title: 'Địa điểm tại $destinationName',
          emptyMessage: 'Chưa có địa điểm thuộc điểm đến này.',
          icon: Icons.place_outlined,
          items: locations,
          fallbackImage: fallbackImage,
          type: 'location',
        );
      case 2:
        return _RecordsTab(
          title: 'Tour tại $destinationName',
          emptyMessage: 'Chưa có tour đang hoạt động tại điểm đến này.',
          icon: Icons.card_travel_outlined,
          items: tours,
          fallbackImage: fallbackImage,
          type: 'tour',
        );
      case 3:
        return _ExperienceTab(
          destinationId: destinationId,
          destinationName: destinationName,
          scenes: scenes,
          fallbackImage: fallbackImage,
        );
      case 4:
        return _MapsTab(
          destinationName: destinationName,
          maps: maps,
          fallbackImage: fallbackImage,
        );
      case 5:
        return _ReviewsTab(reviews: reviews);
      case 6:
        return _RecordsTab(
          title: 'Cẩm nang du lịch $destinationName',
          emptyMessage: 'Chưa có bài viết cẩm nang cho điểm đến này.',
          icon: Icons.menu_book_outlined,
          items: blogs,
          fallbackImage: fallbackImage,
          type: 'blog',
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.name,
    required this.description,
    required this.item,
  });
  final String name;
  final String description;
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Giới thiệu về $name', style: AppTextStyles.h4),
      const SizedBox(height: 10),
      Text(
        description.isEmpty
            ? 'Chưa có thông tin tổng quan cho điểm đến này.'
            : description,
        style: AppTextStyles.bodySmall.copyWith(height: 1.65),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: _InfoTile(
              icon: Icons.calendar_today_outlined,
              label: 'Thời điểm đẹp',
              value: _text(item, ['best_time'], 'Quanh năm'),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: _InfoTile(
              icon: Icons.language_rounded,
              label: 'Ngôn ngữ',
              value: 'Tiếng Việt',
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          const Expanded(
            child: _InfoTile(
              icon: Icons.payments_outlined,
              label: 'Tiền tệ',
              value: 'VND',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _InfoTile(
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

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.borderLight),
    ),
    child: Row(
      children: [
        Icon(icon, size: 17, color: AppColors.brand),
        const SizedBox(width: 8),
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
                style: AppTextStyles.label.copyWith(fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RecordsTab extends StatelessWidget {
  const _RecordsTab({
    required this.title,
    required this.emptyMessage,
    required this.icon,
    required this.items,
    required this.fallbackImage,
    required this.type,
  });
  final String title;
  final String emptyMessage;
  final IconData icon;
  final List<Map<String, dynamic>> items;
  final String fallbackImage;
  final String type;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _InlineEmpty(icon: icon, message: emptyMessage);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.h4),
        const SizedBox(height: 12),
        for (final record in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RecordCard(
              item: record,
              fallbackImage: fallbackImage,
              type: type,
              onTap: () {
                final id = _relatedId(record, type);
                if (type == 'location' && id > 0) {
                  context.push('/locations/$id');
                } else if (type == 'tour' && id > 0) {
                  context.push('/tours/$id');
                } else if (type == 'blog' && id > 0) {
                  context.push('/blogs/$id');
                }
              },
            ),
          ),
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.item,
    required this.fallbackImage,
    required this.type,
    required this.onTap,
  });
  final Map<String, dynamic> item;
  final String fallbackImage;
  final String type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final resolved = AppConfig.assetUrl(_image(item) ?? '');
    final image = resolved.isEmpty ? fallbackImage : resolved;
    final title = _text(item, ['name', 'title'], 'Nội dung');
    final description = _clean(
      '${item['description'] ?? item['summary'] ?? item['content'] ?? ''}',
    );
    final price = num.tryParse(
      '${item['price'] ?? item['adult_price'] ?? item['min_price'] ?? 0}',
    );
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 112,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              if (image.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(11),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: image,
                    width: 108,
                    height: 112,
                    fit: BoxFit.cover,
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label.copyWith(fontSize: 12),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption,
                        ),
                      ],
                      const Spacer(),
                      if (type == 'tour' && price != null && price > 0)
                        Text(
                          NumberFormat.currency(
                            locale: 'vi_VN',
                            symbol: 'đ',
                            decimalDigits: 0,
                          ).format(price),
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.brand,
                            fontSize: 10,
                          ),
                        )
                      else
                        Row(
                          children: [
                            Icon(
                              iconForType(type),
                              size: 13,
                              color: AppColors.brand,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              type == 'location'
                                  ? 'Xem địa điểm'
                                  : 'Đọc cẩm nang',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.brand,
                              ),
                            ),
                          ],
                        ),
                    ],
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

IconData iconForType(String type) =>
    type == 'location' ? Icons.place_outlined : Icons.menu_book_outlined;

class _ExperienceTab extends StatelessWidget {
  const _ExperienceTab({
    required this.destinationId,
    required this.destinationName,
    required this.scenes,
    required this.fallbackImage,
  });
  final int destinationId;
  final String destinationName;
  final List<Map<String, dynamic>> scenes;
  final String fallbackImage;

  @override
  Widget build(BuildContext context) {
    if (scenes.isEmpty) {
      return const _InlineEmpty(
        icon: Icons.threesixty_rounded,
        message: 'Chưa có trải nghiệm 360° cho điểm đến này.',
      );
    }
    final featured = scenes.first;
    final resolved = AppConfig.assetUrl(_image(featured) ?? '');
    final image = resolved.isEmpty ? fallbackImage : resolved;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trải nghiệm 360°', style: AppTextStyles.h4),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => context.push('/view360?destinationId=$destinationId'),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 220,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (image.isNotEmpty)
                  CachedNetworkImage(imageUrl: image, fit: BoxFit.cover)
                else
                  const ColoredBox(color: AppColors.borderLight),
                const DecoratedBox(
                  decoration: BoxDecoration(color: Color(0x55000000)),
                ),
                const Center(
                  child: CircleAvatar(
                    radius: 29,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 34,
                      color: AppColors.brand,
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Text(
                    _text(featured, ['title', 'name'], destinationName),
                    style: AppTextStyles.h4.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${scenes.length} không gian 360° đang sẵn sàng',
          style: AppTextStyles.bodySmall,
        ),
      ],
    );
  }
}

class _MapsTab extends StatelessWidget {
  const _MapsTab({
    required this.destinationName,
    required this.maps,
    required this.fallbackImage,
  });
  final String destinationName;
  final List<Map<String, dynamic>> maps;
  final String fallbackImage;

  @override
  Widget build(BuildContext context) {
    if (maps.isEmpty) {
      return const _InlineEmpty(
        icon: Icons.map_outlined,
        message: 'Chưa có bản đồ cho điểm đến này.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bản đồ $destinationName', style: AppTextStyles.h4),
        const SizedBox(height: 12),
        for (final map in maps)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MapCard(item: map, fallbackImage: fallbackImage),
          ),
      ],
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({required this.item, required this.fallbackImage});
  final Map<String, dynamic> item;
  final String fallbackImage;

  @override
  Widget build(BuildContext context) {
    final resolved = AppConfig.assetUrl(_image(item) ?? '');
    final image = resolved.isEmpty ? fallbackImage : resolved;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (image.isNotEmpty)
            SizedBox(height: 176, child: NetworkMapImage(url: image)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _text(item, ['name', 'title'], 'Bản đồ tham quan'),
              style: AppTextStyles.label,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewsTab extends StatelessWidget {
  const _ReviewsTab({required this.reviews});
  final List<Map<String, dynamic>> reviews;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return const _InlineEmpty(
        icon: Icons.star_outline_rounded,
        message: 'Chưa có đánh giá cho điểm đến này.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Đánh giá từ du khách', style: AppTextStyles.h4),
        const SizedBox(height: 12),
        for (final review in reviews)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.accentLight,
                      child: Icon(
                        Icons.person_outline_rounded,
                        size: 17,
                        color: AppColors.brand,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _text(review, [
                          'user_name',
                          'reviewer_name',
                          'name',
                        ], 'Du khách'),
                        style: AppTextStyles.label.copyWith(fontSize: 11),
                      ),
                    ),
                    const Icon(
                      Icons.star_rounded,
                      color: AppColors.gold,
                      size: 15,
                    ),
                    Text(
                      ' ${review['rating'] ?? 0}',
                      style: AppTextStyles.label.copyWith(fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  _clean('${review['comment'] ?? review['content'] ?? ''}'),
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.onTap,
    this.color = AppColors.ink,
  });
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

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
        child: Icon(icon, size: 19, color: color),
      ),
    ),
  );
}

class _Dot extends StatelessWidget {
  const _Dot();
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 3,
    height: 3,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.subtle,
        shape: BoxShape.circle,
      ),
    ),
  );
}

// Compact alternative retained for related-content layouts.
// ignore: unused_element
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.showAll,
    required this.onShowAll,
  });
  final String title;
  final bool showAll;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: AppTextStyles.h4.copyWith(fontSize: 15)),
      ),
      if (showAll)
        TextButton(onPressed: onShowAll, child: const Text('Xem tất cả')),
    ],
  );
}

// Compact alternative retained for related-content layouts.
// ignore: unused_element
class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.item,
    required this.fallbackImage,
    required this.onTap,
  });
  final Map<String, dynamic> item;
  final String fallbackImage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final resolved = AppConfig.assetUrl(_image(item) ?? '');
    final image = resolved.isEmpty ? fallbackImage : resolved;
    final title = _text(item, ['name', 'title'], 'Địa điểm');
    return SizedBox(
      width: 126,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: image.isEmpty
                  ? const ColoredBox(
                      color: AppColors.borderLight,
                      child: SizedBox(width: 126, height: 102),
                    )
                  : CachedNetworkImage(
                      imageUrl: image,
                      width: 126,
                      height: 102,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(height: 7),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

// Compact alternative retained for related-content layouts.
// ignore: unused_element
class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.item,
    required this.fallbackImage,
    required this.onTap,
  });
  final Map<String, dynamic> item;
  final String fallbackImage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final resolved = AppConfig.assetUrl(_image(item) ?? '');
    final image = resolved.isEmpty ? fallbackImage : resolved;
    final title = _text(item, ['name', 'title'], 'Tour trải nghiệm');
    final price =
        num.tryParse('${item['price'] ?? item['adult_price'] ?? 0}') ?? 0;
    return SizedBox(
      width: 220,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(11),
                ),
                child: image.isEmpty
                    ? const SizedBox(
                        width: 88,
                        height: double.infinity,
                        child: ColoredBox(color: AppColors.borderLight),
                      )
                    : CachedNetworkImage(
                        imageUrl: image,
                        width: 88,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label.copyWith(fontSize: 11),
                      ),
                      const SizedBox(height: 7),
                      if (price > 0)
                        Text(
                          NumberFormat.currency(
                            locale: 'vi_VN',
                            symbol: 'đ',
                            decimalDigits: 0,
                          ).format(price),
                          style: AppTextStyles.label.copyWith(
                            fontSize: 10,
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
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    height: 84,
    width: double.infinity,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.borderLight),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: AppColors.subtle),
        const SizedBox(width: 8),
        Text(message, style: AppTextStyles.bodySmall),
      ],
    ),
  );
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: const Color(0xFFE9EAED),
    highlightColor: const Color(0xFFF8F8F9),
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(height: 272, color: Colors.white),
        Container(
          height: 430,
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
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

int _relatedId(Map item, String type) =>
    int.tryParse(
      '${type == 'location'
          ? item['location_id'] ?? item['id']
          : type == 'blog'
          ? item['blog_id'] ?? item['id']
          : item['tour_id'] ?? item['id'] ?? 0}',
    ) ??
    0;
