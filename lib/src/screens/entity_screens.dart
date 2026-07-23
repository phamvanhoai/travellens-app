import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_config.dart';
import '../core/network/api_client.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';
import '../design/app_widgets.dart';

class EntityConfig {
  const EntityConfig({
    required this.title,
    required this.endpoint,
    required this.keys,
    required this.detailBase,
    this.auth = false,
  });
  final String title, endpoint, detailBase;
  final List<String> keys;
  final bool auth;
}

class EntityListScreen extends ConsumerStatefulWidget {
  const EntityListScreen({super.key, required this.config});
  final EntityConfig config;
  @override
  ConsumerState<EntityListScreen> createState() => _EntityListScreenState();
}

class _EntityListScreenState extends ConsumerState<EntityListScreen> {
  late Future<List<Map<String, dynamic>>> future;
  final search = TextEditingController();
  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<List<Map<String, dynamic>>> load() async {
    final response = await ref
        .read(dioProvider)
        .get(
          widget.config.endpoint,
          queryParameters: {
            'page': 1,
            'limit': 50,
            if (search.text.trim().isNotEmpty) 'search': search.text.trim(),
          },
        );
    return unwrapList(response.data, widget.config.keys);
  }

  void reload() => setState(() {
    future = load();
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    appBar: AppBar(
      title: Text(widget.config.title),
      backgroundColor: Colors.white,
    ),
    body: Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: SearchBar(
            controller: search,
            hintText: 'Tìm kiếm ${widget.config.title.toLowerCase()}…',
            backgroundColor: WidgetStatePropertyAll(AppColors.surface),
            elevation: const WidgetStatePropertyAll(0),
            side: WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            leading: const Icon(
              Icons.search_rounded,
              color: AppColors.muted,
              size: 20,
            ),
            onSubmitted: (_) => reload(),
            trailing: [
              if (search.text.isNotEmpty)
                IconButton(
                  onPressed: () {
                    search.clear();
                    reload();
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.brand,
            onRefresh: () async => reload(),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done)
                  return _ListLoading();
                if (snapshot.hasError)
                  return AppErrorState(
                    error: apiError(snapshot.error!),
                    onRetry: reload,
                  );
                final items = snapshot.data ?? [];
                if (items.isEmpty)
                  return AppEmptyState(
                    icon: Icons.explore_off_rounded,
                    title: 'Nothing here yet',
                    subtitle: 'Hãy thử từ khóa khác hoặc quay lại sau.',
                  );
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => EntityCard(
                    item: items[i],
                    onTap: () {
                      final id = _id(items[i]);
                      if (widget.config.detailBase.isNotEmpty && id != '0')
                        context.push('${widget.config.detailBase}/$id');
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ],
    ),
  );
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }
}

class EntityCard extends StatelessWidget {
  const EntityCard({super.key, required this.item, this.onTap});
  final Map<String, dynamic> item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final image = AppConfig.assetUrl(_image(item));
    final title = _title(item);
    final subtitle =
        '${item['short_description'] ?? item['description'] ?? item['destination_name'] ?? item['status'] ?? ''}'
            .replaceAll(RegExp('<[^>]*>'), ' ');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 110,
              height: 110,
              child: image.isEmpty
                  ? ColoredBox(
                      color: AppColors.borderLight,
                      child: const Icon(
                        Icons.image_outlined,
                        color: AppColors.subtle,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h4,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall,
                    ),
                    if (item['price'] != null || item['total_amount'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${item['price'] ?? item['total_amount']} ${item['currency'] ?? 'VND'}',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.brand,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EntityDetailScreen extends ConsumerWidget {
  const EntityDetailScreen({
    super.key,
    required this.title,
    required this.endpoint,
    this.bookTour = false,
  });
  final String title, endpoint;
  final bool bookTour;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    backgroundColor: AppColors.surface,
    appBar: AppBar(title: Text(title), backgroundColor: Colors.white),
    body: FutureBuilder<Response>(
      future: ref.read(dioProvider).get(endpoint),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return AppErrorState(
            error: apiError(snapshot.error!),
            onRetry: () => context.pushReplacement(
              GoRouterState.of(context).uri.toString(),
            ),
          );
        dynamic data = unwrap(snapshot.data!.data);
        if (data is Map && data.length == 1 && data.values.first is Map)
          data = data.values.first;
        final item = Map<String, dynamic>.from(data as Map);
        final image = AppConfig.assetUrl(_image(item));
        return ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            if (image.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 10,
                child: CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title(item),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (item['price'] != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      '${item['price']} ${item['currency'] ?? 'VND'}',
                      style: AppTextStyles.price,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    '${item['description'] ?? item['short_description'] ?? 'Thông tin chi tiết đang được cập nhật.'}'
                        .replaceAll(RegExp('<[^>]*>'), ' '),
                    style: AppTextStyles.body,
                  ),
                  if (bookTour) ...[
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () =>
                          context.push('/booking?tourId=${_id(item)}'),
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: const Text('Đặt tour này'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

// ─── Loading skeleton ─────────────────────────────────────────────────────────

class _ListLoading extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
    itemCount: 5,
    separatorBuilder: (_, _) => const SizedBox(height: 12),
    itemBuilder: (_, _) => Container(
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 110,
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(17),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppShimmerBox(width: 160, height: 14),
                  const SizedBox(height: 10),
                  AppShimmerBox(width: double.infinity, height: 10),
                  const SizedBox(height: 7),
                  AppShimmerBox(width: 100, height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _id(Map item) =>
    '${item['tour_id'] ?? item['travel_destination_id'] ?? item['destination_id'] ?? item['location_id'] ?? item['post_id'] ?? item['group_trip_id'] ?? item['booking_id'] ?? item['payment_id'] ?? item['review_id'] ?? item['id'] ?? 0}';
String _title(Map item) =>
    '${item['name'] ?? item['title'] ?? item['tour_name'] ?? item['booking_code'] ?? item['payment_code'] ?? item['caption'] ?? 'Item'}';
String? _image(Map item) =>
    item['thumbnail_url'] ??
    item['thumbnail'] ??
    item['image_url'] ??
    item['image'] ??
    item['media_url'] ??
    item['avatar_url'];
