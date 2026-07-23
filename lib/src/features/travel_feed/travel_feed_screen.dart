import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../config/app_config.dart';
import '../../core/network/api_client.dart';
import '../auth/auth_controller.dart';
import '../../design/app_colors.dart';
import '../../design/app_text_styles.dart';
import '../../design/app_widgets.dart';

class TravelFeedScreen extends ConsumerStatefulWidget {
  const TravelFeedScreen({super.key});
  @override
  ConsumerState<TravelFeedScreen> createState() => _TravelFeedScreenState();
}

class _TravelFeedScreenState extends ConsumerState<TravelFeedScreen> {
  final search = TextEditingController();
  List<Map<String, dynamic>> posts = [], stories = [];
  bool loading = true, loadingMore = false;
  String? error;
  int page = 1, totalPages = 1;
  String sort = 'newest';
  int feedTab = 0;

  List<Map<String, dynamic>> get visiblePosts => feedTab == 1
      ? posts.where((post) {
          final author = post['author'];
          return post['is_following'] == true ||
              (author is Map && author['is_following'] == true);
        }).toList()
      : posts;

  @override
  void initState() {
    super.initState();
    load();
    loadStories();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load({bool more = false}) async {
    if (more) {
      if (loadingMore || page >= totalPages) return;
      setState(() => loadingMore = true);
    } else
      setState(() {
        loading = true;
        error = null;
        page = 1;
      });
    try {
      final target = more ? page + 1 : 1;
      final response = await ref
          .read(dioProvider)
          .get(
            '/travel-feed',
            queryParameters: {
              'page': target,
              'limit': 10,
              'sort': sort,
              if (search.text.trim().isNotEmpty) 'search': search.text.trim(),
            },
          );
      final values = unwrapList(response.data, ['posts', 'feed']);
      final body = response.data is Map ? response.data as Map : const {};
      final data = body['data'] is Map ? body['data'] as Map : const {};
      final pagination = data['pagination'] is Map
          ? data['pagination'] as Map
          : body['pagination'] is Map
          ? body['pagination'] as Map
          : const {};
      if (mounted)
        setState(() {
          posts = more ? [...posts, ...values] : values;
          page = target;
          totalPages =
              int.tryParse(
                '${pagination['totalPages'] ?? pagination['total_pages'] ?? 1}',
              ) ??
              1;
        });
    } catch (e) {
      if (mounted) setState(() => error = apiError(e));
    } finally {
      if (mounted)
        setState(() {
          loading = false;
          loadingMore = false;
        });
    }
  }

  Future<void> loadStories() async {
    if (!ref.read(authProvider).authenticated) return;
    try {
      final response = await ref
          .read(dioProvider)
          .get('/travel-stories', queryParameters: {'page': 1, 'limit': 100});
      if (mounted) setState(() => stories = _flattenStories(response.data));
    } catch (_) {}
  }

  Future<void> toggleLike(Map<String, dynamic> post) async {
    if (!ref.read(authProvider).authenticated) {
      context.push('/login');
      return;
    }
    final id = _postId(post), liked = post['is_liked'] == true;
    setState(() {
      post['is_liked'] = !liked;
      post['like_count'] =
          ((post['like_count'] ?? 0) as num).toInt() + (liked ? -1 : 1);
    });
    try {
      if (liked)
        await ref.read(dioProvider).delete('/travel-feed/$id/like');
      else
        await ref.read(dioProvider).post('/travel-feed/$id/like');
    } catch (e) {
      setState(() {
        post['is_liked'] = liked;
        post['like_count'] =
            ((post['like_count'] ?? 0) as num).toInt() + (liked ? 1 : -1);
      });
    }
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: ref.watch(authProvider).authenticated
          ? FloatingActionButton(
              onPressed: openComposer,
              mini: true,
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: () async => Future.wait([load(), loadStories()]),
        child: CustomScrollView(
          slivers: [
            // App bar + header
            SliverToBoxAdapter(
              child: _FeedHeader(
                search: search,
                onSearch: load,
                sort: sort,
                selectedTab: feedTab,
                onTabChanged: (value) => setState(() => feedTab = value),
                onSortChanged: (v) {
                  sort = v;
                  load();
                },
              ),
            ),

            // Stories
            SliverToBoxAdapter(
              child: _StoriesSection(
                stories: stories,
                onTap: openStory,
                onAdd: ref.watch(authProvider).authenticated
                    ? openStoryComposer
                    : null,
              ),
            ),

            // Error
            if (error != null)
              SliverToBoxAdapter(
                child: _ErrorBanner(error: error!, onRetry: load),
              )
            else if (loading)
              const SliverPadding(
                padding: EdgeInsets.all(16),
                sliver: _FeedSkeleton(),
              )
            else if (visiblePosts.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: AppEmptyState(
                    icon: Icons.dynamic_feed_rounded,
                    title: 'Nothing to see here',
                    subtitle:
                        'Chưa có bài viết du lịch. Hãy là người đầu tiên chia sẻ!',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                sliver: SliverList.separated(
                  itemCount: visiblePosts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _PostCard(
                    post: visiblePosts[i],
                    onLike: () => toggleLike(visiblePosts[i]),
                    onComment: () => openComments(visiblePosts[i]),
                    onShare: () => share(visiblePosts[i]),
                    onMore: () => openPostActions(visiblePosts[i]),
                  ),
                ),
              ),

            // Load more
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                child: loadingMore
                    ? const Center(child: CircularProgressIndicator())
                    : page < totalPages
                    ? OutlinedButton(
                        onPressed: () => load(more: true),
                        child: const Text('Load more posts'),
                      )
                    : posts.isNotEmpty
                    ? Center(
                        child: Text(
                          "You're all caught up ✓",
                          style: AppTextStyles.bodySmall,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> share(Map<String, dynamic> post) async {
    final id = _postId(post);
    await ref
        .read(dioProvider)
        .post('/travel-feed/$id/share', data: {'platform': 'other'})
        .catchError((_) => Response(requestOptions: RequestOptions()));
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post share recorded.')));
  }

  Future<void> openComposer() async {
    if (!ref.read(authProvider).authenticated) {
      context.push('/login');
      return;
    }
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _Composer(),
    );
    if (created == true) load();
  }

  Future<void> openPostActions(Map<String, dynamic> post) async {
    if (!ref.read(authProvider).authenticated) {
      context.push('/login');
      return;
    }
    final currentUser =
        ref.read(authProvider).user ?? const <String, dynamic>{};
    final currentUserId = _authUserId(currentUser);
    final authorId = _authorId(post);
    final ownPost = currentUserId > 0 && currentUserId == authorId;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ownPost) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Chỉnh sửa bài viết'),
                onTap: () => Navigator.pop(sheetContext, 'edit'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Xóa bài viết',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () => Navigator.pop(sheetContext, 'delete'),
              ),
            ] else
              ListTile(
                leading: const Icon(
                  Icons.block_rounded,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Chặn người dùng',
                  style: TextStyle(color: AppColors.error),
                ),
                subtitle: const Text('Ẩn tất cả bài viết của người này'),
                onTap: authorId > 0
                    ? () => Navigator.pop(sheetContext, 'block')
                    : null,
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      final updated = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _Composer(post: post),
      );
      if (updated == true) await load();
    } else if (action == 'delete') {
      await _deletePost(post);
    } else if (action == 'block') {
      await _blockAuthor(post);
    }
  }

  Future<void> _deletePost(Map<String, dynamic> post) async {
    final id = _postId(post);
    if (id <= 0) return;
    final confirmed = await _confirmAction(
      title: 'Xóa bài viết?',
      message: 'Bài viết và toàn bộ nội dung liên quan sẽ bị xóa.',
      confirmLabel: 'Xóa',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(dioProvider).delete('/travel-feed/$id');
      if (!mounted) return;
      setState(() => posts.removeWhere((value) => _postId(value) == id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa bài viết.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(error))));
      }
    }
  }

  Future<void> _blockAuthor(Map<String, dynamic> post) async {
    final authorId = _authorId(post);
    if (authorId <= 0) return;
    final author = post['author'] is Map ? post['author'] as Map : const {};
    final name = '${author['name'] ?? 'người dùng này'}';
    final confirmed = await _confirmAction(
      title: 'Chặn $name?',
      message: 'Tất cả bài viết của người này sẽ bị ẩn khỏi cộng đồng.',
      confirmLabel: 'Chặn',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(dioProvider).post('/travel-feed/users/$authorId/block');
      if (!mounted) return;
      setState(
        () => posts.removeWhere((value) => _authorId(value) == authorId),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã chặn $name.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(error))));
      }
    }
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> openStoryComposer() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _StoryComposer(),
    );
    if (created == true) loadStories();
  }

  void openStory(int index) => showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .96),
    builder: (_) => _StoryViewer(stories: stories, index: index),
  );

  void openComments(Map<String, dynamic> post) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _Comments(postId: _postId(post)),
  );
}

// ─── Feed Header ─────────────────────────────────────────────────────────────

class _FeedHeader extends StatelessWidget {
  const _FeedHeader({
    required this.search,
    required this.onSearch,
    required this.sort,
    required this.onSortChanged,
    required this.selectedTab,
    required this.onTabChanged,
  });
  final TextEditingController search;
  final VoidCallback onSearch;
  final String sort;
  final ValueChanged<String> onSortChanged;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: SafeArea(
      bottom: false,
      child: Column(
        children: [
          SizedBox(
            height: 46,
            child: Padding(
              padding: const EdgeInsets.only(left: 18, right: 7),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Cộng đồng',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tìm bài viết',
                    onPressed: () => _openSearch(context),
                    icon: const Icon(Icons.search_rounded, size: 19),
                  ),
                  PopupMenuButton<String>(
                    initialValue: sort,
                    onSelected: onSortChanged,
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      size: 19,
                    ),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'newest', child: Text('Mới nhất')),
                      PopupMenuItem(value: 'oldest', child: Text('Cũ nhất')),
                      PopupMenuItem(value: 'popular', child: Text('Phổ biến')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 5),
              itemCount: 2,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (_, index) => _CommunityTab(
                label: const ['Bài viết', 'Đang theo dõi'][index],
                selected: selectedTab == index,
                onTap: () => onTabChanged(index),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),
        ],
      ),
    ),
  );

  Future<void> _openSearch(BuildContext context) async {
    final apply = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tìm bài viết'),
        content: SizedBox(
          height: 46,
          child: TextField(
            controller: search,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => Navigator.pop(dialogContext, true),
            decoration: const InputDecoration(
              hintText: 'Địa điểm, trải nghiệm...',
              prefixIcon: Icon(Icons.search_rounded, size: 19),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              search.clear();
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Xóa lọc'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Tìm'),
          ),
        ],
      ),
    );
    if (apply == true) onSearch();
  }
}

class _CommunityTab extends StatelessWidget {
  const _CommunityTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFF172554) : Colors.transparent,
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.muted,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ),
  );
}

// Legacy promotional header retained for compatibility with earlier variants.
// ignore: unused_element
class _LegacyFeedHeader extends StatelessWidget {
  const _LegacyFeedHeader({
    required this.search,
    required this.onSearch,
    required this.sort,
    required this.onSortChanged,
  });
  final TextEditingController search;
  final VoidCallback onSearch;
  final String sort;
  final ValueChanged<String> onSortChanged;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: AppColors.brandGradient,
      ),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
    ),
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 8, 0),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.travel_explore_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 9),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TravelLens',
                      style: AppTextStyles.h4White.copyWith(letterSpacing: -.3),
                    ),
                    Text(
                      'Khám phá khoảnh khắc',
                      style: AppTextStyles.bodySmallWhite.copyWith(
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  initialValue: sort,
                  onSelected: onSortChanged,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'newest', child: Text('Mới nhất')),
                    PopupMenuItem(value: 'oldest', child: Text('Oldest')),
                    PopupMenuItem(value: 'popular', child: Text('Phổ biến')),
                  ],
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 11, 18, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "See the world through travelers' eyes.",
                  style: AppTextStyles.h3White.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'Câu chuyện thật, địa điểm thật, cảm hứng cho hành trình tiếp theo.',
                  style: AppTextStyles.bodySmallWhite.copyWith(fontSize: 9.5),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 7, 18, 12),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .15),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 7),
                  const Icon(
                    Icons.search_rounded,
                    color: AppColors.muted,
                    size: 18,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: TextField(
                      controller: search,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => onSearch(),
                      style: AppTextStyles.body,
                      decoration: InputDecoration(
                        hintText: 'Tìm bài viết, địa điểm, trải nghiệm…',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                        hintStyle: AppTextStyles.body.copyWith(
                          color: AppColors.subtle,
                        ),
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: onSearch,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(42, 36),
                      maximumSize: const Size(42, 36),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: const Icon(Icons.arrow_forward_rounded, size: 18),
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

// ─── Stories Section ─────────────────────────────────────────────────────────

class _StoriesSection extends StatelessWidget {
  const _StoriesSection({
    required this.stories,
    required this.onTap,
    this.onAdd,
  });
  final List<Map<String, dynamic>> stories;
  final ValueChanged<int> onTap;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final story in stories) {
      grouped.putIfAbsent(_storyUserId(story), () => []).add(story);
    }
    final groups = grouped.values.toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 5, 0, 0),
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stories',
                      style: AppTextStyles.h4.copyWith(fontSize: 13),
                    ),
                    Text(
                      'Shared in the last 24 hours',
                      style: AppTextStyles.caption.copyWith(fontSize: 9),
                    ),
                  ],
                ),
              ),
              if (onAdd != null)
                FilledButton.tonalIcon(
                  onPressed: onAdd,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 30),
                    maximumSize: const Size(80, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    backgroundColor: AppColors.successSoft,
                    foregroundColor: AppColors.success,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 14),
                  label: Text(
                    'Add',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 64,
            child: groups.isEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Chưa có tin nào đang hoạt động.',
                      style: AppTextStyles.bodySmall,
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: groups.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final story = groups[i].first;
                      final originalIndex = stories.indexOf(story);
                      final author = _author(story);
                      final avatar = AppConfig.assetUrl(_avatar(story) ?? '');
                      return GestureDetector(
                        onTap: () => onTap(originalIndex),
                        child: SizedBox(
                          width: 50,
                          child: Column(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFFD946EF),
                                      Color(0xFFF43F5E),
                                      Color(0xFFF59E0B),
                                    ],
                                  ),
                                ),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: CircleAvatar(
                                    backgroundColor: AppColors.borderLight,
                                    backgroundImage: avatar.isEmpty
                                        ? null
                                        : CachedNetworkImageProvider(avatar),
                                    child: avatar.isEmpty
                                        ? Text(
                                            author.characters.first
                                                .toUpperCase(),
                                            style: AppTextStyles.label.copyWith(
                                              fontSize: 13,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Post Card ────────────────────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onMore,
  });
  final Map<String, dynamic> post;
  final VoidCallback onLike, onComment, onShare, onMore;

  @override
  Widget build(BuildContext context) {
    final author = post['author'] is Map ? post['author'] as Map : const {};
    final avatar = AppConfig.assetUrl('${author['avatar_url'] ?? ''}');
    final photos = (post['photos'] is List ? post['photos'] as List : const [])
        .whereType<Map>()
        .toList();
    final liked = post['is_liked'] == true;
    final authorName = '${author['name'] ?? 'Khách du lịch'}';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author header
          Padding(
            padding: const EdgeInsets.all(11),
            child: Row(
              children: [
                AppAvatar(
                  name: authorName,
                  imageUrl: avatar.isEmpty ? null : avatar,
                  radius: 18,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: AppTextStyles.label.copyWith(fontSize: 11.5),
                      ),
                      Text(
                        _date('${post['created_at'] ?? ''}'),
                        style: AppTextStyles.caption.copyWith(fontSize: 9),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Tùy chọn bài viết',
                  onPressed: onMore,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    fixedSize: const Size(30, 30),
                    minimumSize: const Size(30, 30),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: AppColors.muted,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),

          // Content
          if ('${post['content'] ?? ''}'.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 0, 11, 9),
              child: Text(
                '${post['content']}',
                style: AppTextStyles.body.copyWith(fontSize: 11.5, height: 1.4),
              ),
            ),

          // Location
          if (post['destination_name'] != null || post['location_name'] != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 0, 11, 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.accent,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${post['location_name'] ?? post['destination_name']}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Photos
          if (photos.isNotEmpty) _PhotoGrid(photos: photos),

          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${post['like_count'] ?? 0} likes',
                  style: AppTextStyles.caption.copyWith(fontSize: 9),
                ),
                const Spacer(),
                Text(
                  '${post['comment_count'] ?? 0} comments · ${post['share_count'] ?? 0} shares',
                  style: AppTextStyles.caption.copyWith(fontSize: 9),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),

          // Action bar
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _ActionBtn(
                    icon: liked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: liked ? 'Đã thích' : 'Thích',
                    active: liked,
                    activeColor: const Color(0xFFFF4D6D),
                    onTap: onLike,
                  ),
                ),
                const VerticalDivider(width: 1, color: AppColors.borderLight),
                Expanded(
                  child: _ActionBtn(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Bình luận',
                    onTap: onComment,
                  ),
                ),
                const VerticalDivider(width: 1, color: AppColors.borderLight),
                Expanded(
                  child: _ActionBtn(
                    icon: Icons.share_outlined,
                    label: 'Share',
                    onTap: onShare,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.activeColor = AppColors.brand,
  });
  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      foregroundColor: active ? activeColor : AppColors.muted,
      padding: const EdgeInsets.symmetric(vertical: 9),
      shape: const RoundedRectangleBorder(),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: active ? activeColor : AppColors.muted),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: active ? activeColor : AppColors.muted,
            fontSize: 10.5,
          ),
        ),
      ],
    ),
  );
}

// ─── Photo Grid ───────────────────────────────────────────────────────────────

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.photos});
  final List<Map> photos;

  @override
  Widget build(BuildContext context) {
    void open(int index) => showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .96),
      builder: (_) => _PhotoViewer(photos: photos, initialIndex: index),
    );

    if (photos.length == 1)
      return GestureDetector(
        onTap: () => open(0),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: CachedNetworkImage(
            imageUrl: AppConfig.assetUrl(
              '${photos.first['image_url'] ?? photos.first['photo_url'] ?? ''}',
            ),
            fit: BoxFit.cover,
          ),
        ),
      );

    return SizedBox(
      height: 220,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: photos.length.clamp(0, 4),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => open(i),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: AppConfig.assetUrl(
                  '${photos[i]['image_url'] ?? photos[i]['photo_url'] ?? ''}',
                ),
                fit: BoxFit.cover,
              ),
              if (i == 3 && photos.length > 4)
                ColoredBox(
                  color: Colors.black54,
                  child: Center(
                    child: Text(
                      '+${photos.length - 4}',
                      style: AppTextStyles.h2White.copyWith(fontSize: 28),
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

// ─── Photo Viewer ─────────────────────────────────────────────────────────────

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.photos, required this.initialIndex});
  final List<Map> photos;
  final int initialIndex;
  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int index = widget.initialIndex;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    backgroundColor: Colors.black,
    child: Stack(
      children: [
        PageView.builder(
          controller: controller,
          itemCount: widget.photos.length,
          onPageChanged: (v) => setState(() => index = v),
          itemBuilder: (_, i) => InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: AppConfig.assetUrl(
                  '${widget.photos[i]['image_url'] ?? widget.photos[i]['photo_url'] ?? ''}',
                ),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          left: 8,
          right: 8,
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.black45),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${index + 1} / ${widget.photos.length}',
                  style: AppTextStyles.label.copyWith(color: Colors.white),
                ),
              ),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─── Composer ─────────────────────────────────────────────────────────────────

class _Composer extends ConsumerStatefulWidget {
  const _Composer({this.post});
  final Map<String, dynamic>? post;
  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  final content = TextEditingController();
  XFile? image;
  bool saving = false;

  bool get editing => widget.post != null;

  @override
  void initState() {
    super.initState();
    content.text = '${widget.post?['content'] ?? ''}';
  }

  @override
  void dispose() {
    content.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (content.text.trim().isEmpty && image == null) return;
    setState(() => saving = true);
    try {
      dynamic data;
      if (editing) {
        final post = widget.post!;
        final photos =
            (post['photos'] is List ? post['photos'] as List : const [])
                .whereType<Map>();
        data = FormData.fromMap({
          'content': content.text.trim(),
          'destination_id': post['destination_id'] ?? '',
          'location_id': post['location_id'] ?? '',
          'visibility': post['visibility'] ?? 'public',
          'keep_photo_ids':
              '[${photos.map(_photoId).where((id) => id > 0).join(',')}]',
          if (image != null)
            'photos': [
              await MultipartFile.fromFile(image!.path, filename: image!.name),
            ],
        });
      } else if (image == null)
        data = {'content': content.text.trim()};
      else
        data = FormData.fromMap({
          'content': content.text.trim(),
          'photos': [
            await MultipartFile.fromFile(image!.path, filename: image!.name),
          ],
        });
      if (editing) {
        await ref
            .read(dioProvider)
            .patch('/travel-feed/${_postId(widget.post!)}', data: data);
      } else {
        await ref.read(dioProvider).post('/travel-feed', data: data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(e))));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
    clipBehavior: Clip.antiAlias,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: const LinearGradient(
                    colors: AppColors.brandGradientLight,
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      editing ? 'Chỉnh sửa bài viết' : 'Chia sẻ khoảnh khắc',
                      style: AppTextStyles.h3,
                    ),
                    Text(
                      editing
                          ? 'Cập nhật nội dung bạn đã chia sẻ'
                          : 'Inspire travelers with your story',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: content,
            maxLines: 5,
            minLines: 3,
            decoration: const InputDecoration(
              hintText: 'Chia sẻ trải nghiệm du lịch của bạn…',
            ),
          ),
          if (image != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      File(image!.path),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      onPressed: () => setState(() => image = null),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        minimumSize: const Size(32, 32),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final x = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 85,
                  );
                  if (x != null) setState(() => image = x);
                },
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Photo'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: saving ? null : submit,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  saving
                      ? (editing ? 'Đang lưu…' : 'Publishing…')
                      : (editing ? 'Lưu thay đổi' : 'Publish'),
                ),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// ─── Story Composer ───────────────────────────────────────────────────────────

class _StoryComposer extends ConsumerStatefulWidget {
  const _StoryComposer();
  @override
  ConsumerState<_StoryComposer> createState() => _StoryComposerState();
}

class _StoryComposerState extends ConsumerState<_StoryComposer> {
  XFile? file;
  final caption = TextEditingController();
  bool saving = false;

  @override
  void dispose() {
    caption.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (file == null) return;
    setState(() => saving = true);
    try {
      final form = FormData.fromMap({
        'media_file': await MultipartFile.fromFile(
          file!.path,
          filename: file!.name,
        ),
        'caption': caption.text.trim(),
      });
      await ref.read(dioProvider).post('/travel-stories', data: form);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(e))));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      18,
      0,
      18,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tạo tin du lịch', style: AppTextStyles.h3),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () async {
            final x = await ImagePicker().pickMedia();
            if (x != null) setState(() => file = x);
          },
          child: Container(
            height: 210,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: file != null ? AppColors.brand : AppColors.border,
                width: file != null ? 2 : 1,
                style: BorderStyle.solid,
              ),
            ),
            child: file == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.upload_rounded,
                        size: 38,
                        color: AppColors.muted,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose an image or video',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: Image.file(File(file!.path), fit: BoxFit.contain),
                  ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: caption,
          maxLength: 1000,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Thêm chú thích…'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: saving ? null : submit,
          child: saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Publish Story'),
        ),
      ],
    ),
  );
}

// ─── Story Viewer ─────────────────────────────────────────────────────────────

class _StoryViewer extends StatefulWidget {
  const _StoryViewer({required this.stories, required this.index});
  final List<Map<String, dynamic>> stories;
  final int index;
  @override
  State<_StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<_StoryViewer> {
  late int index;
  Timer? timer;
  static const duration = Duration(seconds: 6);

  @override
  void initState() {
    super.initState();
    index = widget.index;
    _startTimer();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    timer?.cancel();
    timer = Timer(duration, _next);
  }

  void _go(int value) {
    if (value < 0) return;
    if (value >= widget.stories.length) {
      Navigator.pop(context);
      return;
    }
    setState(() => index = value);
    _startTimer();
  }

  void _next() => _go(index + 1);

  @override
  Widget build(BuildContext context) {
    final s = widget.stories[index];
    final media = AppConfig.assetUrl('${s['media_url'] ?? s['url'] ?? ''}');
    final video = '${s['media_type'] ?? ''}'.toLowerCase() == 'video';
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (video)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 72,
                    ),
                    SizedBox(height: 10),
                    Text('Video story', style: TextStyle(color: Colors.white)),
                  ],
                ),
              )
            else
              CachedNetworkImage(imageUrl: media, fit: BoxFit.contain),
            // Progress bars
            Positioned(
              left: 12,
              right: 12,
              top: 10,
              child: Row(
                children: List.generate(
                  widget.stories.length,
                  (i) => Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: i < index
                          ? const ColoredBox(color: AppColors.accent)
                          : i == index
                          ? TweenAnimationBuilder<double>(
                              key: ValueKey('progress-$index'),
                              tween: Tween(begin: 0, end: 1),
                              duration: duration,
                              builder: (_, v, _) => FractionallySizedBox(
                                widthFactor: v,
                                alignment: Alignment.centerLeft,
                                child: const ColoredBox(
                                  color: AppColors.accent,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
            // Author bar
            Positioned(
              left: 12,
              right: 12,
              top: 24,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _author(s),
                      style: AppTextStyles.label.copyWith(color: Colors.white),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
            // Caption
            if (s['caption'] != null)
              Positioned(
                left: 14,
                right: 14,
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${s['caption']}',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyWhite,
                  ),
                ),
              ),
            // Navigation areas
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.sizeOf(context).width * .35,
              child: GestureDetector(onTap: () => _go(index - 1)),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.sizeOf(context).width * .35,
              child: GestureDetector(onTap: _next),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Comments ─────────────────────────────────────────────────────────────────

class _Comments extends ConsumerStatefulWidget {
  const _Comments({required this.postId});
  final int postId;
  @override
  ConsumerState<_Comments> createState() => _CommentsState();
}

class _CommentsState extends ConsumerState<_Comments> {
  final input = TextEditingController();
  late Future<List<Map<String, dynamic>>> future;
  Map<String, dynamic>? replyingTo;
  Map<String, dynamic>? editingComment;
  bool sending = false;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> load() async {
    final r = await ref
        .read(dioProvider)
        .get(
          '/travel-feed/${widget.postId}/comments',
          queryParameters: {'page': 1, 'limit': 100},
        );
    return _commentTree(unwrapList(r.data, ['comments']));
  }

  Future<void> send() async {
    if (input.text.trim().isEmpty || sending) return;
    setState(() => sending = true);
    try {
      if (editingComment != null) {
        await ref
            .read(dioProvider)
            .patch(
              '/travel-feed/comments/${_commentId(editingComment!)}',
              data: {'content': input.text.trim()},
            );
        input.clear();
        setState(() {
          editingComment = null;
          future = load();
        });
        return;
      }
      final parentId = _commentId(replyingTo ?? const {});
      await ref
          .read(dioProvider)
          .post(
            '/travel-feed/${widget.postId}/comments',
            data: {
              'content': input.text.trim(),
              if (parentId > 0) 'parent_comment_id': parentId,
            },
          );
      input.clear();
      setState(() {
        replyingTo = null;
        future = load();
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(e))));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  void editComment(Map<String, dynamic> comment) {
    input.text = '${comment['content'] ?? comment['comment'] ?? ''}';
    input.selection = TextSelection.collapsed(offset: input.text.length);
    setState(() {
      editingComment = comment;
      replyingTo = null;
    });
  }

  Future<void> deleteComment(Map<String, dynamic> comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bình luận này?'),
        content: const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('This comment will be permanently removed.'),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(dioProvider)
          .delete('/travel-feed/comments/${_commentId(comment)}');
      if (mounted)
        setState(() {
          future = load();
        });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(e))));
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .72,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
            child: Text('Bình luận', style: AppTextStyles.h3),
          ),
          Expanded(
            child: FutureBuilder(
              future: future,
              builder: (_, snap) {
                if (!snap.hasData)
                  return const Center(child: CircularProgressIndicator());
                final values = snap.data!;
                if (values.isEmpty)
                  return AppEmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Chưa có bình luận',
                    subtitle: 'Hãy bắt đầu cuộc trò chuyện!',
                  );
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  itemCount: values.length,
                  itemBuilder: (_, i) => _CommentItem(
                    comment: values[i],
                    onReply: (comment) => setState(() => replyingTo = comment),
                    currentUserId: _authUserId(ref.watch(authProvider).user),
                    onEdit: editComment,
                    onDelete: deleteComment,
                  ),
                );
              },
            ),
          ),
          if (replyingTo != null || editingComment != null)
            Container(
              width: double.infinity,
              color: AppColors.accentLight,
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      editingComment != null
                          ? 'Editing your comment'
                          : 'Đang trả lời ${_commentAuthor(replyingTo!)}',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.accent,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      input.clear();
                      setState(() {
                        replyingTo = null;
                        editingComment = null;
                      });
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    decoration: const InputDecoration(
                      hintText: 'Viết bình luận…',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: sending ? null : send,
                  icon: sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _CommentItem extends StatelessWidget {
  const _CommentItem({
    required this.comment,
    required this.onReply,
    required this.currentUserId,
    required this.onEdit,
    required this.onDelete,
    this.depth = 0,
  });
  final Map<String, dynamic> comment;
  final ValueChanged<Map<String, dynamic>> onReply;
  final ValueChanged<Map<String, dynamic>> onEdit, onDelete;
  final int currentUserId;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final replies =
        (comment['replies'] is List ? comment['replies'] as List : const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
    final owner = currentUserId > 0 && currentUserId == _commentUserId(comment);
    final authorName = _commentAuthor(comment);

    return Padding(
      padding: EdgeInsets.only(left: depth > 0 ? 28 : 0, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(name: authorName, radius: 17),
              const SizedBox(width: 9),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: AppTextStyles.label.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${comment['content'] ?? comment['comment'] ?? ''}',
                        style: AppTextStyles.body.copyWith(
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => onReply(comment),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(40, 28),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    foregroundColor: AppColors.muted,
                  ),
                  child: Text(
                    'Trả lời',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (owner) ...[
                  TextButton(
                    onPressed: () => onEdit(comment),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(40, 28),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      foregroundColor: AppColors.muted,
                    ),
                    child: Text('Edit', style: AppTextStyles.caption),
                  ),
                  TextButton(
                    onPressed: () => onDelete(comment),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(40, 28),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      foregroundColor: AppColors.error,
                    ),
                    child: Text(
                      'Delete',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          for (final reply in replies)
            _CommentItem(
              comment: reply,
              onReply: onReply,
              currentUserId: currentUserId,
              onEdit: onEdit,
              onDelete: onDelete,
              depth: depth + 1,
            ),
        ],
      ),
    );
  }
}

// ─── Error Banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: .2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

// ─── Feed Skeleton ────────────────────────────────────────────────────────────

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();
  @override
  Widget build(BuildContext context) => SliverList.separated(
    itemCount: 3,
    separatorBuilder: (_, _) => const SizedBox(height: 14),
    itemBuilder: (_, _) => Shimmer.fromColors(
      baseColor: const Color(0xFFE5E7EB),
      highlightColor: const Color(0xFFF9FAFB),
      child: Container(
        height: 380,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    ),
  );
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

int _postId(Map p) => int.tryParse('${p['post_id'] ?? p['id'] ?? 0}') ?? 0;
int _authorId(Map post) {
  final author = post['author'] is Map ? post['author'] as Map : const {};
  final user = post['user'] is Map ? post['user'] as Map : const {};
  return int.tryParse(
        '${post['user_id'] ?? post['customer_id'] ?? post['author_id'] ?? author['user_id'] ?? author['customer_id'] ?? author['id'] ?? user['user_id'] ?? user['id'] ?? 0}',
      ) ??
      0;
}

int _photoId(Map photo) =>
    int.tryParse(
      '${photo['photo_id'] ?? photo['media_id'] ?? photo['id'] ?? 0}',
    ) ??
    0;
int _commentId(Map c) =>
    int.tryParse('${c['comment_id'] ?? c['id'] ?? 0}') ?? 0;
int _commentUserId(Map c) {
  final user = c['user'] is Map ? c['user'] as Map : const {};
  final author = c['author'] is Map ? c['author'] as Map : const {};
  return int.tryParse(
        '${c['user_id'] ?? c['customer_id'] ?? user['user_id'] ?? user['id'] ?? author['user_id'] ?? author['id'] ?? 0}',
      ) ??
      0;
}

int _authUserId(Map<String, dynamic>? user) =>
    int.tryParse(
      '${user?['user_id'] ?? user?['customer_id'] ?? user?['id'] ?? 0}',
    ) ??
    0;

String _commentAuthor(Map c) {
  final user = c['user'] is Map ? c['user'] as Map : const {};
  final author = c['author'] is Map ? c['author'] as Map : const {};
  return '${c['user_name'] ?? c['customer_name'] ?? c['author_name'] ?? user['name'] ?? author['name'] ?? 'Khách du lịch'}';
}

String _storyUserId(Map s) {
  final user = s['user'] is Map ? s['user'] as Map : const {};
  final author = s['author'] is Map ? s['author'] as Map : const {};
  return '${s['user_id'] ?? s['customer_id'] ?? user['user_id'] ?? user['id'] ?? author['user_id'] ?? author['id'] ?? _author(s)}';
}

List<Map<String, dynamic>> _flattenStories(dynamic payload) {
  final direct = unwrapList(payload, ['stories']);
  if (direct.isNotEmpty) return direct;
  final groups = unwrapList(payload, ['story_groups', 'groups']);
  final result = <Map<String, dynamic>>[];
  for (final group in groups) {
    final nested = group['stories'];
    if (nested is List) {
      for (final story in nested.whereType<Map>()) {
        final item = Map<String, dynamic>.from(story);
        item.putIfAbsent(
          'user_id',
          () => group['user_id'] ?? group['customer_id'],
        );
        item.putIfAbsent('user', () => group['user'] ?? group['author']);
        result.add(item);
      }
    } else if (group['story_id'] != null || group['media_url'] != null) {
      result.add(group);
    }
  }
  return result;
}

List<Map<String, dynamic>> _commentTree(List<Map<String, dynamic>> source) {
  final byId = <int, Map<String, dynamic>>{};
  for (final value in source) {
    final item = Map<String, dynamic>.from(value);
    item['replies'] =
        (item['replies'] is List ? item['replies'] as List : const [])
            .whereType<Map>()
            .map((reply) => Map<String, dynamic>.from(reply))
            .toList();
    byId[_commentId(item)] = item;
  }
  final roots = <Map<String, dynamic>>[];
  for (final item in byId.values) {
    final parentId = int.tryParse('${item['parent_comment_id'] ?? 0}') ?? 0;
    final parent = byId[parentId];
    if (parentId > 0 && parent != null) {
      (parent['replies'] as List<Map<String, dynamic>>).add(item);
    } else {
      roots.add(item);
    }
  }
  return roots;
}

String _author(Map s) =>
    '${(s['user'] is Map ? s['user']['name'] : null) ?? (s['author'] is Map ? s['author']['name'] : null) ?? 'Khách du lịch'}';
String? _avatar(Map s) =>
    (s['user'] is Map ? s['user']['avatar_url'] : null) ??
    (s['author'] is Map ? s['author']['avatar_url'] : null);
String _date(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  return date == null ? 'Recently' : DateFormat('MMM d · HH:mm').format(date);
}
