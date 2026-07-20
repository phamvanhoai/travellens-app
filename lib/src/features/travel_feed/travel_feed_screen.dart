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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF6F8FB),
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: .5,
      toolbarHeight: 58,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      flexibleSpace: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F766E), Color(0xFF0891B2)],
          ),
        ),
      ),
      titleSpacing: 16,
      title: const Row(
        children: [
          _FeedLogo(),
          SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TravelLens',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.4,
                  color: Colors.white,
                ),
              ),
              Text(
                'Discover moments',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xCCFFFFFF),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          initialValue: sort,
          onSelected: (v) {
            sort = v;
            load();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'newest', child: Text('Newest')),
            PopupMenuItem(value: 'oldest', child: Text('Oldest')),
            PopupMenuItem(value: 'popular', child: Text('Popular')),
          ],
          icon: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.tune_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
    floatingActionButton: ref.watch(authProvider).authenticated
        ? FloatingActionButton.extended(
            onPressed: openComposer,
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
            elevation: 3,
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Share a moment',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          )
        : null,
    body: RefreshIndicator(
      onRefresh: () async {
        await Future.wait([load(), loadStories()]);
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F766E), Color(0xFF0891B2)],
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'See the world through\nother travelers’ eyes.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.7,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Real places. Real stories. Your next inspiration.',
                    style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
                  ),
                  const SizedBox(height: 13),
                  SearchBar(
                    controller: search,
                    backgroundColor: const WidgetStatePropertyAll(Colors.white),
                    elevation: const WidgetStatePropertyAll(0),
                    side: const WidgetStatePropertyAll(
                      BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    hintText: 'Search posts, places, experiences…',
                    leading: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF64748B),
                    ),
                    onSubmitted: (_) => load(),
                    trailing: [
                      if (search.text.isNotEmpty)
                        IconButton(
                          onPressed: () {
                            search.clear();
                            load();
                          },
                          icon: const Icon(Icons.close),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _Stories(
              stories: stories,
              onTap: openStory,
              onAdd: ref.watch(authProvider).authenticated
                  ? openStoryComposer
                  : null,
            ),
          ),
          if (error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFBE123C)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(error!)),
                      TextButton(
                        onPressed: () => load(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (loading)
            const SliverPadding(
              padding: EdgeInsets.all(12),
              sliver: _FeedSkeleton(),
            )
          else if (posts.isEmpty)
            const SliverToBoxAdapter(
              child: SizedBox(
                height: 300,
                child: Center(child: Text('No travel posts found.')),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 22),
              sliver: SliverList.separated(
                itemCount: posts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (_, i) => _PostCard(
                  post: posts[i],
                  onLike: () => toggleLike(posts[i]),
                  onComment: () => openComments(posts[i]),
                  onShare: () => share(posts[i]),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              child: loadingMore
                  ? const Center(child: CircularProgressIndicator())
                  : page < totalPages
                  ? OutlinedButton(
                      onPressed: () => load(more: true),
                      child: const Text('Load more posts'),
                    )
                  : posts.isNotEmpty
                  ? const Center(
                      child: Text(
                        "You're all caught up",
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    ),
  );
  Future<void> share(Map<String, dynamic> post) async {
    final id = _postId(post);
    await ref
        .read(dioProvider)
        .post('/travel-feed/$id/share', data: {'platform': 'other'})
        .catchError((_) {
          return Response(requestOptions: RequestOptions());
        });
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
    barrierColor: Colors.black.withValues(alpha: .95),
    builder: (_) => _StoryViewer(stories: stories, index: index),
  );
  void openComments(Map<String, dynamic> post) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _Comments(postId: _postId(post)),
  );
}

class _FeedLogo extends StatelessWidget {
  const _FeedLogo();
  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(11),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF14B8A6), Color(0xFF0E7490)],
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x3314B8A6),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: const Icon(
      Icons.travel_explore_rounded,
      color: Colors.white,
      size: 20,
    ),
  );
}

class _Stories extends StatelessWidget {
  const _Stories({required this.stories, required this.onTap, this.onAdd});
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
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8EDF3))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Travel Stories',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: -.3,
                      ),
                    ),
                    Text(
                      'Shared in the last 24 hours',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (onAdd != null)
                TextButton.icon(
                  onPressed: onAdd,
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFECFDF5),
                    foregroundColor: const Color(0xFF0F766E),
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'Add story',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 72,
            child: groups.isEmpty
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'No active stories yet.',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: groups.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 13),
                    itemBuilder: (_, i) {
                      final story = groups[i].first;
                      final originalIndex = stories.indexOf(story);
                      final author = _author(story);
                      final avatar = AppConfig.assetUrl(_avatar(story));
                      return GestureDetector(
                        onTap: () => onTap(originalIndex),
                        child: SizedBox(
                          width: 60,
                          child: Column(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
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
                                child: CircleAvatar(
                                  backgroundColor: Colors.white,
                                  backgroundImage: avatar.isEmpty
                                      ? null
                                      : CachedNetworkImageProvider(avatar),
                                  child: avatar.isEmpty
                                      ? Text(
                                          author.characters.first.toUpperCase(),
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
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

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onShare,
  });
  final Map<String, dynamic> post;
  final VoidCallback onLike, onComment, onShare;
  @override
  Widget build(BuildContext context) {
    final author = post['author'] is Map ? post['author'] as Map : const {};
    final avatar = AppConfig.assetUrl('${author['avatar_url'] ?? ''}');
    final photos = (post['photos'] is List ? post['photos'] as List : const [])
        .whereType<Map>()
        .toList();
    final liked = post['is_liked'] == true;
    return Material(
      color: Colors.white,
      elevation: 0,
      shadowColor: const Color(0x180F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFE8EDF3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: const Color(0xFFE0F2FE),
                  backgroundImage: avatar.isEmpty
                      ? null
                      : CachedNetworkImageProvider(avatar),
                  child: avatar.isEmpty
                      ? Text('${author['name'] ?? 'T'}'.characters.first)
                      : null,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${author['name'] ?? 'Traveler'}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        _date('${post['created_at'] ?? ''}'),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.more_horiz_rounded,
                    color: Color(0xFF64748B),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          if ('${post['content'] ?? ''}'.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 13),
              child: Text(
                '${post['content']}',
                style: const TextStyle(fontSize: 15, height: 1.45),
              ),
            ),
          if (post['destination_name'] != null || post['location_name'] != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFEFF),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFF0E7490),
                      size: 15,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${post['location_name'] ?? post['destination_name']}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF0E7490),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (photos.isNotEmpty) _PhotoGrid(photos: photos),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Row(
              children: [
                Text(
                  '${post['like_count'] ?? 0} likes',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                const Spacer(),
                Text(
                  '${post['comment_count'] ?? 0} comments · ${post['share_count'] ?? 0} shares',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEF2F6)),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: onLike,
                  style: TextButton.styleFrom(
                    foregroundColor: liked
                        ? const Color(0xFFE11D48)
                        : const Color(0xFF475569),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    color: liked ? const Color(0xFFE11D48) : null,
                  ),
                  label: Text(liked ? 'Liked' : 'Like'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: onComment,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Comment'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: onShare,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
          aspectRatio: 4 / 3,
          child: CachedNetworkImage(
            imageUrl: AppConfig.assetUrl(
              '${photos.first['image_url'] ?? photos.first['photo_url'] ?? ''}',
            ),
            fit: BoxFit.cover,
          ),
        ),
      );
    return SizedBox(
      height: 260,
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
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
          onPageChanged: (value) => setState(() => index = value),
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
              IconButton.filledTonal(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
              const Spacer(),
              Text(
                '${index + 1}/${widget.photos.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
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

class _Composer extends ConsumerStatefulWidget {
  const _Composer();
  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  final content = TextEditingController();
  XFile? image;
  bool saving = false;
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
      if (image == null)
        data = {'content': content.text.trim()};
      else
        data = FormData.fromMap({
          'content': content.text.trim(),
          'photos': [
            await MultipartFile.fromFile(image!.path, filename: image!.name),
          ],
        });
      await ref.read(dioProvider).post('/travel-feed', data: data);
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
    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
    clipBehavior: Clip.antiAlias,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        18,
        18,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 22,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF14B8A6), Color(0xFF0891B2)],
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share a moment',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.5,
                      ),
                    ),
                    Text(
                      'Inspire travelers with your journey',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: content,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: "Share your travel experience…",
            ),
          ),
          if (image != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  File(image!.path),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          const SizedBox(height: 12),
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
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Photo'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: saving ? null : submit,
                child: saving
                    ? const CircularProgressIndicator()
                    : const Text('Publish'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

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
      MediaQuery.viewInsetsOf(context).bottom + 22,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Create Travel Story',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () async {
            final x = await ImagePicker().pickMedia();
            if (x != null) setState(() => file = x);
          },
          child: Container(
            height: 210,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: file == null
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.upload, size: 38),
                      Text('Choose an image or video'),
                    ],
                  )
                : Image.file(File(file!.path), fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: caption,
          maxLength: 1000,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Add a caption…'),
        ),
        FilledButton(
          onPressed: saving ? null : submit,
          child: saving
              ? const CircularProgressIndicator()
              : const Text('Publish Story'),
        ),
      ],
    ),
  );
}

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
    final s = widget.stories[index],
        media = AppConfig.assetUrl('${s['media_url'] ?? s['url'] ?? ''}');
    final video = '${s['media_type'] ?? ''}'.toLowerCase() == 'video';
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
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
                    Icon(Icons.play_circle_fill, color: Colors.white, size: 72),
                    SizedBox(height: 10),
                    Text('Video story', style: TextStyle(color: Colors.white)),
                  ],
                ),
              )
            else
              CachedNetworkImage(imageUrl: media, fit: BoxFit.contain),
            Positioned(
              left: 12,
              right: 12,
              top: 8,
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
                          ? const ColoredBox(color: Color(0xFF22D3EE))
                          : i == index
                          ? TweenAnimationBuilder<double>(
                              key: ValueKey('visible-story-progress-$index'),
                              tween: Tween(begin: 0, end: 1),
                              duration: duration,
                              builder: (_, value, child) =>
                                  FractionallySizedBox(
                                    widthFactor: value,
                                    alignment: Alignment.centerLeft,
                                    child: const ColoredBox(
                                      color: Color(0xFF22D3EE),
                                    ),
                                  ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _author(s),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (s['caption'] != null)
              Positioned(
                left: 14,
                right: 14,
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${s['caption']}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            Positioned(
              left: 4,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton.filledTonal(
                  onPressed: index > 0 ? () => _go(index - 1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
              ),
            ),
            Positioned(
              right: 4,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton.filledTonal(
                  onPressed: _next,
                  icon: const Icon(Icons.chevron_right),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
      barrierColor: Colors.black.withValues(alpha: .55),
      builder: (_) => const _DeleteCommentDialog(),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(dioProvider)
          .delete('/travel-feed/comments/${_commentId(comment)}');
      if (mounted) {
        setState(() {
          future = load();
        });
      }
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
          const Text(
            'Comments',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          Expanded(
            child: FutureBuilder(
              future: future,
              builder: (_, snap) {
                if (!snap.hasData)
                  return const Center(child: CircularProgressIndicator());
                final values = snap.data!;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
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
              color: const Color(0xFFEFF6FF),
              padding: const EdgeInsets.fromLTRB(16, 5, 8, 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      editingComment != null
                          ? 'Editing your comment'
                          : 'Replying to ${_commentAuthor(replyingTo!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF0369A1),
                        fontWeight: FontWeight.w700,
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
                    icon: const Icon(Icons.close, size: 18),
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
                      hintText: 'Write a comment…',
                    ),
                  ),
                ),
                IconButton.filled(
                  onPressed: sending ? null : send,
                  icon: sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _DeleteCommentDialog extends StatelessWidget {
  const _DeleteCommentDialog();

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 28),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFFE4E6),
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              size: 32,
              color: Color(0xFFE11D48),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Delete this comment?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'This comment will be permanently removed. This action cannot be undone.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B), height: 1.45),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: const Text('Keep comment'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: const Color(0xFFE11D48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),
            ],
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
    return Padding(
      padding: EdgeInsets.only(left: depth > 0 ? 28 : 0, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 17,
                child: Text(
                  _commentAuthor(comment).characters.first.toUpperCase(),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _commentAuthor(comment),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${comment['content'] ?? comment['comment'] ?? ''}',
                        style: const TextStyle(height: 1.35),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 43),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => onReply(comment),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(45, 28),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  child: const Text(
                    'Reply',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
                if (owner) ...[
                  TextButton(
                    onPressed: () => onEdit(comment),
                    child: const Text('Edit', style: TextStyle(fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: () => onDelete(comment),
                    child: const Text(
                      'Delete',
                      style: TextStyle(fontSize: 12, color: Color(0xFFBE123C)),
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

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();
  @override
  Widget build(BuildContext context) => SliverList.separated(
    itemCount: 3,
    separatorBuilder: (_, _) => const SizedBox(height: 14),
    itemBuilder: (_, _) => Shimmer.fromColors(
      baseColor: const Color(0xFFE2E8F0),
      highlightColor: const Color(0xFFF8FAFC),
      child: Container(
        height: 410,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    ),
  );
}

int _postId(Map p) => int.tryParse('${p['post_id'] ?? p['id'] ?? 0}') ?? 0;
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
  return '${c['user_name'] ?? c['customer_name'] ?? c['author_name'] ?? user['name'] ?? author['name'] ?? 'Traveler'}';
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
    '${(s['user'] is Map ? s['user']['name'] : null) ?? (s['author'] is Map ? s['author']['name'] : null) ?? 'Traveler'}';
String? _avatar(Map s) =>
    (s['user'] is Map ? s['user']['avatar_url'] : null) ??
    (s['author'] is Map ? s['author']['avatar_url'] : null);
String _date(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  return date == null ? 'Recently' : DateFormat('MMM d · HH:mm').format(date);
}
