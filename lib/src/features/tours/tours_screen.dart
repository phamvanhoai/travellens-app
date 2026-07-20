import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../design/app_colors.dart';
import '../../design/app_text_styles.dart';
import '../../design/app_widgets.dart';
import '../auth/auth_controller.dart';
import 'saved_tours_controller.dart';

class ToursScreen extends ConsumerStatefulWidget {
  const ToursScreen({super.key});
  @override
  ConsumerState<ToursScreen> createState() => _ToursScreenState();
}

class _ToursScreenState extends ConsumerState<ToursScreen> {
  final search = TextEditingController();
  List<Map<String, dynamic>> tours = [];
  bool loading = true;
  String? error;
  String sort = 'newest';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
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
          .get(
            '/tours',
            queryParameters: {
              'page': 1,
              'limit': 50,
              if (search.text.trim().isNotEmpty) 'search': search.text.trim(),
            },
          );
      final items = unwrapList(response.data, ['tours']);
      _sortTours(items);
      if (mounted) setState(() => tours = items);
    } catch (e) {
      if (mounted) setState(() => error = apiError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void showSort() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in const [
              ('newest', 'Mới nhất'),
              ('popular', 'Phổ biến'),
              ('price_asc', 'Giá thấp nhất'),
            ])
              RadioListTile<String>(
                value: option.$1,
                groupValue: sort,
                title: Text(option.$2),
                onChanged: (value) {
                  if (value == null) return;
                  Navigator.pop(sheetContext);
                  sort = value;
                  setState(() => _sortTours(tours));
                },
              ),
          ],
        ),
      ),
    );
  }

  void _sortTours(List<Map<String, dynamic>> items) {
    switch (sort) {
      case 'popular':
        items.sort((a, b) {
          final bScore = _tourNumber(
            b['booked_slots'] ?? b['review_count'] ?? b['reviews_count'],
          );
          final aScore = _tourNumber(
            a['booked_slots'] ?? a['review_count'] ?? a['reviews_count'],
          );
          return bScore.compareTo(aScore);
        });
        break;
      case 'price_asc':
        items.sort(
          (a, b) => _tourNumber(a['price']).compareTo(_tourNumber(b['price'])),
        );
        break;
      default:
        items.sort((a, b) {
          final bDate = DateTime.tryParse(
            '${b['created_at'] ?? b['createdAt'] ?? ''}',
          );
          final aDate = DateTime.tryParse(
            '${a['created_at'] ?? a['createdAt'] ?? ''}',
          );
          if (aDate == null || bDate == null) return 0;
          return bDate.compareTo(aDate);
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: const Text('Khám phá tour'),
      actions: [
        IconButton(
          icon: const Icon(Icons.favorite_border_rounded, size: 21),
          onPressed: () => context.push('/wishlist'),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: TextField(
                        controller: search,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => load(),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Tìm tour, điểm đến...',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                          ),
                          suffixIcon: search.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    search.clear();
                                    load();
                                  },
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                ),
                          contentPadding: EdgeInsets.zero,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: showSort,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(46, 46),
                      maximumSize: const Size(46, 46),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Icon(Icons.tune_rounded, size: 19),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 3, 16, 5),
                children: const [
                  _TourFilter('Tất cả', true),
                  _TourFilter('Trong nước', false),
                  _TourFilter('Quốc tế', false),
                  _TourFilter('Phổ biến', false),
                ],
              ),
            ),
          ),
          if (loading)
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: _TourSkeleton(),
            )
          else if (error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppErrorState(error: error!, onRetry: load),
            )
          else if (tours.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.card_travel_outlined,
                title: 'Không tìm thấy tour',
                subtitle: 'Hãy thử một từ khóa khác.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverList.separated(
                itemCount: tours.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) => _LargeTourCard(tour: tours[index]),
              ),
            ),
        ],
      ),
    ),
  );
}

class _TourFilter extends StatelessWidget {
  const _TourFilter(this.label, this.selected);
  final String label;
  final bool selected;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 15),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: selected ? const Color(0xFF163A78) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: selected ? const Color(0xFF163A78) : AppColors.border,
      ),
    ),
    child: Text(
      label,
      style: AppTextStyles.caption.copyWith(
        color: selected ? Colors.white : AppColors.muted,
      ),
    ),
  );
}

class _TourCard extends StatelessWidget {
  const _TourCard({required this.tour});
  final Map<String, dynamic> tour;

  @override
  Widget build(BuildContext context) {
    final id = int.tryParse('${tour['tour_id'] ?? tour['id'] ?? 0}') ?? 0;
    final image = AppConfig.assetUrl(
      '${tour['thumbnail_url'] ?? tour['image_url'] ?? tour['thumbnail'] ?? ''}',
    );
    final name = '${tour['name'] ?? tour['title'] ?? 'Tour trải nghiệm'}';
    final destination =
        '${tour['destination_name'] ?? tour['destination'] ?? ''}';
    final price =
        num.tryParse('${tour['price'] ?? tour['base_price'] ?? 0}') ?? 0;
    final rating =
        double.tryParse('${tour['average_rating'] ?? tour['rating'] ?? 0}') ??
        0;
    final duration = tour['duration_days'] ?? tour['duration'];
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: () => context.push('/tours/$id'),
        borderRadius: BorderRadius.circular(13),
        child: Container(
          height: 124,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderLight),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
                child: image.isEmpty
                    ? const SizedBox(
                        width: 116,
                        height: 124,
                        child: ColoredBox(color: AppColors.borderLight),
                      )
                    : CachedNetworkImage(
                        imageUrl: image,
                        width: 116,
                        height: 124,
                        fit: BoxFit.cover,
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label.copyWith(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      if (destination.isNotEmpty)
                        Text(
                          destination,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption,
                        ),
                      const Spacer(),
                      Row(
                        children: [
                          if (rating > 0) ...[
                            const Icon(
                              Icons.star_rounded,
                              size: 13,
                              color: AppColors.gold,
                            ),
                            Text(
                              ' ${rating.toStringAsFixed(1)}',
                              style: AppTextStyles.caption,
                            ),
                          ],
                          if (duration != null) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.schedule_rounded,
                              size: 12,
                              color: AppColors.subtle,
                            ),
                            Text(
                              ' $duration ngày',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ],
                      ),
                      if (price > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Từ ${NumberFormat.decimalPattern('vi').format(price)}đ',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.brand,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 19,
                  color: AppColors.subtle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

double _tourNumber(dynamic value) => double.tryParse('${value ?? 0}') ?? 0;

class _LargeTourCard extends ConsumerStatefulWidget {
  const _LargeTourCard({required this.tour});
  final Map<String, dynamic> tour;

  @override
  ConsumerState<_LargeTourCard> createState() => _LargeTourCardState();
}

class _LargeTourCardState extends ConsumerState<_LargeTourCard> {
  bool _saving = false;

  Map<String, dynamic> get tour => widget.tour;

  Future<void> _toggleSaved(int id) async {
    if (!ref.read(authProvider).authenticated) {
      context.push('/login');
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(savedToursProvider.notifier).toggle(id);
    } catch (e) {
      if (mounted) {
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
    final id = int.tryParse('${tour['tour_id'] ?? tour['id'] ?? 0}') ?? 0;
    final saved = ref.watch(savedToursProvider).contains(id);
    final rawImage =
        '${tour['thumbnail_url'] ?? tour['image_url'] ?? tour['thumbnail'] ?? ''}';
    final image = rawImage.isEmpty ? '' : AppConfig.assetUrl(rawImage);
    final name = '${tour['name'] ?? tour['title'] ?? 'Tour trải nghiệm'}';
    final destination = _tourDestination(tour);
    final price = _tourNumber(tour['price'] ?? tour['base_price']);
    final rating = _tourNumber(tour['average_rating'] ?? tour['rating']);
    final reviews = _tourInt(tour['review_count'] ?? tour['reviews_count']);
    final days = _tourInt(tour['duration_days']);
    final nights = _tourInt(tour['duration_nights']);
    final duration = days > 0
        ? nights > 0
              ? '$days ngày $nights đêm'
              : '$days ngày'
        : '${tour['duration'] ?? tour['schedule'] ?? 'Trong ngày'}';
    final capacity = _tourInt(tour['available_slots'] ?? tour['capacity']);
    final category = tour['tour_category'] is Map
        ? '${tour['tour_category']['name'] ?? ''}'
        : '${tour['category_name'] ?? tour['badge'] ?? ''}';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => context.push('/tours/$id'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D0F172A),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 200,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (image.isEmpty)
                      const ColoredBox(
                        color: AppColors.borderLight,
                        child: Icon(
                          Icons.landscape_rounded,
                          size: 48,
                          color: AppColors.subtle,
                        ),
                      )
                    else
                      CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
                    if (category.isNotEmpty)
                      Positioned(
                        left: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF97316),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            category,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: SizedBox(
                        width: 38,
                        height: 38,
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _toggleSaved(id),
                            child: _saving
                                ? const Padding(
                                    padding: EdgeInsets.all(11),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    saved
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    size: 20,
                                    color: saved
                                        ? AppColors.error
                                        : AppColors.ink,
                                  ),
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
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    if (destination.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              destination,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 13),
                    Wrap(
                      spacing: 15,
                      runSpacing: 8,
                      children: [
                        _TourMeta(icon: Icons.schedule_rounded, text: duration),
                        if (capacity > 0)
                          _TourMeta(
                            icon: Icons.groups_outlined,
                            text: '$capacity người',
                          ),
                      ],
                    ),
                    const SizedBox(height: 17),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 18,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          rating > 0 ? rating.toStringAsFixed(1) : 'Mới',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (reviews > 0)
                          Text(' ($reviews)', style: AppTextStyles.caption),
                        const Spacer(),
                        if (price > 0)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Giá từ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                              Text(
                                '${NumberFormat.decimalPattern('vi').format(price)}đ',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
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
    );
  }
}

class _TourMeta extends StatelessWidget {
  const _TourMeta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: AppColors.muted),
      const SizedBox(width: 5),
      Text(text, style: AppTextStyles.caption),
    ],
  );
}

int _tourInt(dynamic value) =>
    int.tryParse('${value ?? 0}') ?? _tourNumber(value).round();

String _tourDestination(Map<String, dynamic> tour) {
  final direct = tour['destination'];
  if (direct is Map) return '${direct['name'] ?? direct['title'] ?? ''}';
  final items = tour['destinations'] ?? tour['tour_destinations'];
  if (items is List) {
    return items
        .map(
          (item) =>
              item is Map ? '${item['name'] ?? item['title'] ?? ''}' : '$item',
        )
        .where((item) => item.isNotEmpty)
        .join(' • ');
  }
  return '${tour['destination_name'] ?? direct ?? ''}';
}

class _TourSkeleton extends StatelessWidget {
  const _TourSkeleton();
  @override
  Widget build(BuildContext context) => SliverList.separated(
    itemCount: 6,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (_, _) => Shimmer.fromColors(
      baseColor: const Color(0xFFE9EAED),
      highlightColor: const Color(0xFFF8F8F9),
      child: Container(
        height: 350,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
        ),
      ),
    ),
  );
}
