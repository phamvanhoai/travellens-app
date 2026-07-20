import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_config.dart';
import '../core/network/api_client.dart';

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
    appBar: AppBar(title: Text(widget.config.title)),
    body: Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: SearchBar(
            controller: search,
            hintText: 'Search ${widget.config.title.toLowerCase()}',
            backgroundColor: const WidgetStatePropertyAll(Color(0xFFF1F5F9)),
            elevation: const WidgetStatePropertyAll(0),
            side: const WidgetStatePropertyAll(
              BorderSide(color: Color(0xFFE2E8F0)),
            ),
            leading: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
            onSubmitted: (_) => reload(),
            trailing: [
              if (search.text.isNotEmpty)
                IconButton(
                  onPressed: () {
                    search.clear();
                    reload();
                  },
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => reload(),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done)
                  return const _ListLoading();
                if (snapshot.hasError)
                  return _ErrorState(
                    error: apiError(snapshot.error!),
                    retry: reload,
                  );
                final items = snapshot.data ?? [];
                if (items.isEmpty)
                  return ListView(
                    children: const [
                      SizedBox(height: 160),
                      Icon(
                        Icons.explore_off_rounded,
                        size: 52,
                        color: Color(0xFF94A3B8),
                      ),
                      SizedBox(height: 12),
                      Center(
                        child: Text(
                          'Nothing here yet.',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  );
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 122,
              height: 124,
              child: image.isEmpty
                  ? const ColoredBox(
                      color: Color(0xFFE2E8F0),
                      child: Icon(Icons.image_outlined),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.2,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                    if (item['price'] != null || item['total_amount'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${item['price'] ?? item['total_amount']} ${item['currency'] ?? 'VND'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0E7490),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Color(0xFF94A3B8),
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
    appBar: AppBar(title: Text(title)),
    body: FutureBuilder<Response>(
      future: ref.read(dioProvider).get(endpoint),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return _ErrorState(
            error: apiError(snapshot.error!),
            retry: () => context.pushReplacement(
              GoRouterState.of(context).uri.toString(),
            ),
          );
        dynamic data = unwrap(snapshot.data!.data);
        if (data is Map && data.length == 1 && data.values.first is Map)
          data = data.values.first;
        final item = Map<String, dynamic>.from(data as Map);
        final image = AppConfig.assetUrl(_image(item));
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
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
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (item['price'] != null)
                    Text(
                      '${item['price']} ${item['currency'] ?? 'VND'}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF0E7490),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    '${item['description'] ?? item['short_description'] ?? 'Details are not available.'}'
                        .replaceAll(RegExp('<[^>]*>'), ' '),
                  ),
                  const SizedBox(height: 20),
                  if (bookTour)
                    FilledButton.icon(
                      onPressed: () =>
                          context.push('/booking?tourId=${_id(item)}'),
                      icon: const Icon(Icons.calendar_month),
                      label: const Text('Book this tour'),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.retry});
  final String error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 48),
          const SizedBox(height: 12),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: retry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

class _ListLoading extends StatelessWidget {
  const _ListLoading();
  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
    itemCount: 5,
    separatorBuilder: (_, _) => const SizedBox(height: 12),
    itemBuilder: (_, _) => Container(
      height: 124,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8EDF3)),
      ),
      child: Row(
        children: [
          Container(
            width: 122,
            decoration: const BoxDecoration(
              color: Color(0xFFE8EDF3),
              borderRadius: BorderRadius.horizontal(left: Radius.circular(21)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 15,
                    width: 150,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EDF3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 11),
                  Container(
                    height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Container(
                    height: 11,
                    width: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

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
