import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../design/app_colors.dart';
import '../../design/app_text_styles.dart';
import '../../design/app_widgets.dart';

class BlogsScreen extends ConsumerStatefulWidget {
  const BlogsScreen({super.key});

  @override
  ConsumerState<BlogsScreen> createState() => _BlogsScreenState();
}

class _BlogsScreenState extends ConsumerState<BlogsScreen> {
  final search = TextEditingController();
  List<Map<String, dynamic>> blogs = [];
  List<Map<String, dynamic>> categories = [];
  int? categoryId;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadCategories();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> loadCategories() async {
    try {
      final response = await ref
          .read(dioProvider)
          .get('/blog-categories', queryParameters: {'page': 1, 'limit': 100});
      final items = unwrapList(response.data, const ['blog_categories']);
      if (mounted) setState(() => categories = items);
    } catch (_) {}
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
            '/blogs',
            queryParameters: {
              'page': 1,
              'limit': 100,
              if (search.text.trim().isNotEmpty) 'search': search.text.trim(),
              if (categoryId != null) 'blog_category_id': categoryId,
            },
          );
      final items = unwrapList(response.data, const ['blogs']);
      if (mounted) setState(() => blogs = items);
    } catch (e) {
      if (mounted) setState(() => error = apiError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8FAFC),
    appBar: AppBar(title: const Text('Cẩm nang du lịch')),
    body: RefreshIndicator(
      onRefresh: load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF172554), Color(0xFF1D4ED8)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'KHÁM PHÁ · TRẢI NGHIỆM · KINH NGHIỆM',
                    style: TextStyle(
                      color: Color(0xFFBFDBFE),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Cảm hứng cho hành trình tiếp theo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 13),
                  SizedBox(
                    height: 46,
                    child: TextField(
                      controller: search,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => load(),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Tìm bài viết, địa điểm...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: search.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  search.clear();
                                  load();
                                },
                                icon: const Icon(Icons.close_rounded, size: 18),
                              ),
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 54,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 9, 16, 7),
                children: [
                  _CategoryChip(
                    label: 'Tất cả',
                    selected: categoryId == null,
                    onTap: () {
                      setState(() => categoryId = null);
                      load();
                    },
                  ),
                  for (final category in categories)
                    _CategoryChip(
                      label: '${category['name'] ?? 'Danh mục'}',
                      selected: categoryId == _id(category, category: true),
                      onTap: () {
                        setState(
                          () => categoryId = _id(category, category: true),
                        );
                        load();
                      },
                    ),
                ],
              ),
            ),
          ),
          if (loading)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
              sliver: SliverList.separated(
                itemCount: 4,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (_, _) => const AppShimmerCard(height: 300),
              ),
            )
          else if (error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppErrorState(error: error!, onRetry: load),
            )
          else if (blogs.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.menu_book_outlined,
                title: 'Không tìm thấy bài viết',
                subtitle: 'Hãy thử từ khóa hoặc danh mục khác.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
              sliver: SliverList.separated(
                itemCount: blogs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (_, index) => _BlogCard(item: blogs[index]),
              ),
            ),
        ],
      ),
    ),
  );
}

class _BlogCard extends StatelessWidget {
  const _BlogCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final image = AppConfig.assetUrl(
      '${item['thumbnail_url'] ?? item['thumbnail'] ?? ''}',
    );
    final categories = item['categories'] is List
        ? (item['categories'] as List)
              .whereType<Map>()
              .map((e) => '${e['name'] ?? ''}')
              .where((name) => name.isNotEmpty)
              .toList()
        : <String>[];
    final identifier = '${item['slug'] ?? item['blog_id'] ?? item['id'] ?? ''}';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: identifier.isEmpty
            ? null
            : () => context.push('/blogs/${Uri.encodeComponent(identifier)}'),
        child: Container(
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 160,
                width: double.infinity,
                child: image.isEmpty
                    ? const ColoredBox(
                        color: AppColors.borderLight,
                        child: Icon(
                          Icons.menu_book_outlined,
                          color: AppColors.subtle,
                          size: 42,
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
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (categories.isNotEmpty)
                        Text(
                          categories.join(' · ').toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.brand,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .8,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        '${item['title'] ?? 'Cẩm nang du lịch'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label.copyWith(fontSize: 14),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 13,
                            color: AppColors.subtle,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _date(item['published_at'] ?? item['date_created']),
                            style: AppTextStyles.caption,
                          ),
                          const Spacer(),
                          Text(
                            'Đọc bài',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.brand,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 15,
                            color: AppColors.brand,
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

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    ),
  );
}

int _id(Map item, {bool category = false}) =>
    int.tryParse(
      '${category ? item['blog_category_id'] ?? item['id'] : item['blog_id'] ?? item['id']}',
    ) ??
    0;

String _date(dynamic value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  if (date == null) return 'Đang cập nhật';
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
