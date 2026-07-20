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
              'sort': sort,
              if (search.text.trim().isNotEmpty) 'search': search.text.trim(),
            },
          );
      if (mounted)
        setState(() => tours = unwrapList(response.data, ['tours']));
    } catch (e) {
      if (mounted) setState(() => error = apiError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    body: RefreshIndicator(
      color: AppColors.brand,
      onRefresh: load,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            title: const Text('Curated Tours'),
            actions: [
              IconButton(
                icon: const Icon(Icons.favorite_border_rounded),
                onPressed: () => context.push('/wishlist'),
                style: IconButton.styleFrom(foregroundColor: AppColors.ink),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Header section
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              decoration: const BoxDecoration(color: Colors.white),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Travel deeper,\nwithout the\nguesswork.',
                    style: AppTextStyles.h1,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Thoughtfully curated experiences led by people who truly know each place.',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 14),
                        const Icon(Icons.search_rounded, color: AppColors.muted, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: search,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => load(),
                            style: AppTextStyles.body,
                            decoration: InputDecoration(
                              hintText: 'Search tours and experiences…',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              hintStyle: AppTextStyles.body.copyWith(color: AppColors.subtle),
                            ),
                          ),
                        ),
                        if (search.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              search.clear();
                              load();
                            },
                          ),
                        Padding(
                          padding: const EdgeInsets.only(right: 5),
                          child: FilledButton(
                            onPressed: load,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(56, 46),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Icon(Icons.arrow_forward_rounded, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Controls row
                  Row(
                    children: [
                      Text(
                        loading ? 'Loading…' : '${tours.length} experiences',
                        style: AppTextStyles.bodySmall,
                      ),
                      const Spacer(),
                      // Sort dropdown
                      PopupMenuButton<String>(
                        initialValue: sort,
                        onSelected: (v) {
                          sort = v;
                          load();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'newest', child: Text('Newest')),
                          PopupMenuItem(value: 'popular', child: Text('Popular')),
                          PopupMenuItem(value: 'price_asc', child: Text('Lowest price')),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.tune_rounded, size: 15, color: AppColors.muted),
                              const SizedBox(width: 6),
                              Text(
                                sort == 'price_asc'
                                    ? 'Lowest price'
                                    : sort == 'popular'
                                    ? 'Popular'
                                    : 'Newest',
                                style: AppTextStyles.label.copyWith(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Content
          if (loading)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
              sliver: SliverList.separated(
                itemCount: 4,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (_, _) => const _TourSkeleton(),
              ),
            )
          else if (error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AppErrorState(error: error!, onRetry: load),
              ),
            )
          else if (tours.isEmpty)
            SliverToBoxAdapter(
              child: AppEmptyState(
                icon: Icons.luggage_rounded,
                title: 'No tours found',
                subtitle: 'Try different search terms.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
              sliver: SliverList.separated(
                itemCount: tours.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (_, index) => _TourCard(tour: tours[index]),
              ),
            ),
        ],
      ),
    ),
  );
}

// ─── Tour Card ────────────────────────────────────────────────────────────────

class _TourCard extends StatelessWidget {
  const _TourCard({required this.tour});
  final Map<String, dynamic> tour;

  @override
  Widget build(BuildContext context) {
    final id = int.tryParse('${tour['tour_id'] ?? tour['id'] ?? 0}') ?? 0;
    final image = AppConfig.assetUrl(
      '${tour['thumbnail_url'] ?? tour['image_url'] ?? tour['thumbnail'] ?? ''}',
    );
    final price = num.tryParse('${tour['price'] ?? tour['base_price'] ?? 0}') ?? 0;
    final duration = tour['duration_days'] ?? tour['duration'];
    final rating = double.tryParse('${tour['rating'] ?? 0}') ?? 0;
    final category =
        '${tour['tour_category_name'] ?? tour['category_name'] ?? 'Experience'}';
    final name = '${tour['name'] ?? tour['title'] ?? 'Tour Experience'}';
    final destination = tour['destination_name'];

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: () => context.push('/tours/$id'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area
            SizedBox(
              height: 210,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  image.isEmpty
                      ? const ColoredBox(
                          color: AppColors.borderLight,
                          child: Icon(Icons.landscape_rounded, size: 54, color: AppColors.subtle),
                        )
                      : CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
                  const AppHeroOverlay(),
                  // Category badge
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: AppColors.brandGradientLight),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category,
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  // Rating badge
                  if (rating > 0)
                    Positioned(
                      top: 14,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, color: AppColors.gold, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Bottom text
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (destination != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on_rounded, color: Colors.white60, size: 13),
                              const SizedBox(width: 4),
                              Text(
                                '$destination',
                                style: AppTextStyles.caption.copyWith(color: Colors.white70),
                              ),
                            ],
                          ),
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.h3White.copyWith(fontSize: 19),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Details row
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (duration != null) ...[
                    const Icon(Icons.schedule_rounded, size: 16, color: AppColors.muted),
                    const SizedBox(width: 5),
                    Text('$duration days', style: AppTextStyles.bodySmall),
                    const SizedBox(width: 16),
                  ],
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'From',
                        style: AppTextStyles.caption,
                      ),
                      Text(
                        '${NumberFormat.decimalPattern('vi').format(price)} ${tour['currency'] ?? 'VND'}',
                        style: AppTextStyles.price,
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: AppColors.brand,
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
}

// ─── Skeleton ─────────────────────────────────────────────────────────────────

class _TourSkeleton extends StatelessWidget {
  const _TourSkeleton();
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: const Color(0xFFE5E7EB),
    highlightColor: const Color(0xFFF9FAFB),
    child: Container(
      height: 290,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
    ),
  );
}
