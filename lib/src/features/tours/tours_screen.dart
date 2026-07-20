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
                itemBuilder: (_, index) => _TourCard(tour: tours[index]),
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
        height: 124,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
        ),
      ),
    ),
  );
}
