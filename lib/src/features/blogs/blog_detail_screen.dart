import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../design/app_colors.dart';
import '../../design/app_text_styles.dart';
import '../../design/app_widgets.dart';
import '../auth/auth_controller.dart';

class BlogDetailScreen extends ConsumerStatefulWidget {
  const BlogDetailScreen({super.key, required this.identifier});
  final String identifier;

  @override
  ConsumerState<BlogDetailScreen> createState() => _BlogDetailScreenState();
}

class _BlogDetailScreenState extends ConsumerState<BlogDetailScreen> {
  Map<String, dynamic>? blog;
  List<Map<String, dynamic>> comments = [];
  bool loading = true;
  bool commentsLoading = true;
  bool submitting = false;
  String? error;
  final commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    commentController.dispose();
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
          .get('/blogs/${Uri.encodeComponent(widget.identifier)}');
      dynamic data = unwrap(response.data);
      if (data is Map && data['blog'] is Map) data = data['blog'];
      if (data is! Map) throw StateError('Không tìm thấy bài viết.');
      if (mounted) {
        blog = Map<String, dynamic>.from(data);
        await loadComments();
      }
    } catch (e) {
      if (mounted) error = apiError(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadComments() async {
    final id = _integer(blog?['blog_id'] ?? blog?['id']);
    if (id <= 0) return;
    if (mounted) setState(() => commentsLoading = true);
    try {
      final response = await ref
          .read(dioProvider)
          .get(
            '/blogs/$id/comments',
            queryParameters: {'page': 1, 'limit': 50},
          );
      if (mounted) {
        comments = unwrapList(response.data, const ['comments', 'rows']);
      }
    } catch (_) {
      if (mounted) comments = [];
    } finally {
      if (mounted) setState(() => commentsLoading = false);
    }
  }

  Future<void> submitComment() async {
    final content = commentController.text.trim();
    if (content.isEmpty || submitting) return;
    if (!ref.read(authProvider).authenticated) {
      context.push(
        '/login?from=${Uri.encodeComponent('/blogs/${widget.identifier}')}',
      );
      return;
    }
    final id = _integer(blog?['blog_id'] ?? blog?['id']);
    setState(() => submitting = true);
    try {
      await ref
          .read(dioProvider)
          .post(
            '/blogs/$id/comments',
            data: {'content': content, 'comment': content},
          );
      commentController.clear();
      await loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(e))));
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Future<void> openCommentEditor(
    Map<String, dynamic> comment, {
    required bool replying,
  }) async {
    if (!ref.read(authProvider).authenticated) {
      context.push(
        '/login?from=${Uri.encodeComponent('/blogs/${widget.identifier}')}',
      );
      return;
    }
    final commentId = _commentId(comment);
    if (commentId <= 0) return;
    final content = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CommentEditorSheet(
        replying: replying,
        initialText: replying ? '' : _commentContent(comment),
      ),
    );
    if (content == null || !mounted) return;
    final blogId = _integer(blog?['blog_id'] ?? blog?['id']);
    try {
      if (replying) {
        await ref
            .read(dioProvider)
            .post(
              '/blogs/$blogId/comments/$commentId/replies',
              data: {'content': content, 'comment': content},
            );
      } else {
        await ref
            .read(dioProvider)
            .put(
              '/blogs/$blogId/comments/$commentId',
              data: {'content': content, 'comment': content},
            );
      }
      await loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(e))));
      }
    }
  }

  Future<void> deleteComment(Map<String, dynamic> comment) async {
    final commentId = _commentId(comment);
    if (commentId <= 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa bình luận?'),
        content: const Text('Bình luận này sẽ bị xóa và không thể khôi phục.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final blogId = _integer(blog?['blog_id'] ?? blog?['id']);
    try {
      await ref.read(dioProvider).delete('/blogs/$blogId/comments/$commentId');
      await loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: _BlogSkeleton());
    }
    if (blog == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cẩm nang')),
        body: AppErrorState(
          error: error ?? 'Không tìm thấy bài viết.',
          onRetry: load,
        ),
      );
    }
    final item = blog!;
    final currentUser = ref.watch(authProvider).user ?? const {};
    final currentUserId = _integer(
      currentUser['user_id'] ?? currentUser['id'] ?? currentUser['sub'],
    );
    final image = AppConfig.assetUrl(
      '${item['thumbnail_url'] ?? item['thumbnail'] ?? ''}',
    );
    final categories = _records(item['categories']);
    final locations = _records(item['locations']);
    final blocks = _htmlBlocks('${item['content'] ?? ''}');
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: _BlogCircleButton(
            icon: Icons.arrow_back_rounded,
            onTap: () =>
                context.canPop() ? context.pop() : context.go('/destinations'),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 272,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (image.isEmpty)
                    const ColoredBox(
                      color: AppColors.borderLight,
                      child: Icon(
                        Icons.menu_book_outlined,
                        color: AppColors.subtle,
                        size: 54,
                      ),
                    )
                  else
                    CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) =>
                          const ColoredBox(color: AppColors.borderLight),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x44000000), Color(0x88000000)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 44),
            sliver: SliverList.list(
              children: [
                const Text(
                  'CẨM NANG DU LỊCH',
                  style: TextStyle(
                    color: AppColors.brand,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                if (categories.isNotEmpty)
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: categories
                        .map(
                          (category) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentLight,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${category['name'] ?? 'Cẩm nang'}',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.brandDark,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                if (categories.isNotEmpty) const SizedBox(height: 14),
                Text(
                  '${item['title'] ?? 'Cẩm nang du lịch'}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 16,
                      color: AppColors.subtle,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '${item['author_name'] ?? item['user_name'] ?? 'Thành viên TravelLens'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 15,
                      color: AppColors.subtle,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _date(item['published_at'] ?? item['date_created']),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
                if (locations.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: locations
                        .map(
                          (location) => ActionChip(
                            avatar: const Icon(
                              Icons.place_outlined,
                              size: 15,
                              color: AppColors.brand,
                            ),
                            label: Text('${location['name'] ?? 'Địa điểm'}'),
                            labelStyle: AppTextStyles.caption.copyWith(
                              color: AppColors.brandDark,
                              fontWeight: FontWeight.w700,
                            ),
                            backgroundColor: AppColors.accentLight,
                            side: BorderSide.none,
                            onPressed: () {
                              final id = _integer(
                                location['location_id'] ?? location['id'],
                              );
                              if (id > 0) context.push('/locations/$id');
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 22),
                const Divider(),
                const SizedBox(height: 22),
                if (blocks.isEmpty)
                  Text(
                    'Nội dung bài viết đang được cập nhật.',
                    style: AppTextStyles.body,
                  )
                else
                  for (final block in blocks)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: block.heading ? 10 : 18,
                        top: block.heading ? 8 : 0,
                      ),
                      child: Text(
                        block.text,
                        style: block.heading
                            ? Theme.of(context).textTheme.titleLarge
                            : AppTextStyles.body.copyWith(height: 1.7),
                      ),
                    ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(
                      Icons.mode_comment_outlined,
                      color: AppColors.brand,
                      size: 24,
                    ),
                    const SizedBox(width: 9),
                    Text('Bình luận', style: AppTextStyles.h4),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_totalCommentCount(comments)}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.brand,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _CommentComposer(
                  controller: commentController,
                  submitting: submitting,
                  onSubmit: submitComment,
                ),
                const SizedBox(height: 18),
                if (commentsLoading)
                  const Center(child: CircularProgressIndicator())
                else if (comments.isEmpty)
                  Container(
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Text(
                      'Chưa có bình luận nào.',
                      style: AppTextStyles.bodySmall,
                    ),
                  )
                else
                  for (final comment in comments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CommentCard(
                        comment: comment,
                        currentUserId: currentUserId,
                        onReply: (item) =>
                            openCommentEditor(item, replying: true),
                        onEdit: (item) =>
                            openCommentEditor(item, replying: false),
                        onDelete: deleteComment,
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

class _ContentBlock {
  const _ContentBlock(this.text, this.heading);
  final String text;
  final bool heading;
}

class _CommentEditorSheet extends StatefulWidget {
  const _CommentEditorSheet({
    required this.replying,
    required this.initialText,
  });

  final bool replying;
  final String initialText;

  @override
  State<_CommentEditorSheet> createState() => _CommentEditorSheetState();
}

class _CommentEditorSheetState extends State<_CommentEditorSheet> {
  late final TextEditingController controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      18,
      0,
      18,
      18 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.replying ? 'Trả lời bình luận' : 'Chỉnh sửa bình luận',
          style: AppTextStyles.h4,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 7,
          maxLength: 2000,
          decoration: InputDecoration(
            hintText: widget.replying
                ? 'Nhập nội dung trả lời...'
                : 'Chỉnh sửa nội dung...',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isNotEmpty) Navigator.pop(context, value);
                },
                child: Text(widget.replying ? 'Gửi trả lời' : 'Lưu thay đổi'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.submitting,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Thêm bình luận', style: AppTextStyles.label),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          maxLength: 2000,
          decoration: const InputDecoration(
            hintText: 'Chia sẻ cảm nhận của bạn về bài viết...',
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            height: 44,
            child: FilledButton.icon(
              onPressed: submitting ? null : onSubmit,
              icon: submitting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 17),
              label: Text(submitting ? 'Đang gửi...' : 'Đăng bình luận'),
            ),
          ),
        ),
      ],
    ),
  );
}

class _BlogCircleButton extends StatelessWidget {
  const _BlogCircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .95),
    shape: const CircleBorder(),
    elevation: 1,
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

class _CommentCard extends StatelessWidget {
  const _CommentCard({
    required this.comment,
    required this.currentUserId,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    this.reply = false,
  });
  final Map<String, dynamic> comment;
  final int currentUserId;
  final ValueChanged<Map<String, dynamic>> onReply;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onDelete;
  final bool reply;

  @override
  Widget build(BuildContext context) {
    final user = comment['user'] is Map ? comment['user'] as Map : const {};
    final name =
        '${comment['user_name'] ?? comment['customer_name'] ?? user['name'] ?? user['email'] ?? 'Khách du lịch'}';
    final content = '${comment['content'] ?? comment['comment'] ?? ''}';
    final owner = currentUserId > 0 && _commentUserId(comment) == currentUserId;
    final replies = [
      ..._records(comment['replies']),
      ..._records(comment['Replies']),
    ];
    return Padding(
      padding: EdgeInsets.only(left: reply ? 18 : 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.accentLight,
                  child: Text(
                    name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                    style: AppTextStyles.label.copyWith(color: AppColors.brand),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _date(comment['created_at']),
                        style: AppTextStyles.caption.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),
                if (!reply)
                  IconButton(
                    tooltip: 'Trả lời',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onReply(comment),
                    icon: const Icon(
                      Icons.reply_rounded,
                      size: 18,
                      color: AppColors.muted,
                    ),
                  ),
                if (owner)
                  PopupMenuButton<String>(
                    tooltip: 'Tùy chọn',
                    onSelected: (action) {
                      if (action == 'edit') onEdit(comment);
                      if (action == 'delete') onDelete(comment);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined, size: 19),
                          title: Text('Chỉnh sửa'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.delete_outline_rounded,
                            size: 19,
                            color: AppColors.error,
                          ),
                          title: Text(
                            'Xóa',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (content.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                content,
                style: AppTextStyles.bodySmall.copyWith(height: 1.6),
              ),
            ],
            if (replies.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                height: 1,
                color: AppColors.borderLight,
              ),
              const SizedBox(height: 12),
              for (final item in replies)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _CommentCard(
                    comment: item,
                    currentUserId: currentUserId,
                    onReply: onReply,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    reply: true,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BlogSkeleton extends StatelessWidget {
  const _BlogSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.zero,
    children: [
      Container(height: 272, color: AppColors.borderLight),
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            AppShimmerBox(width: 100, height: 12),
            SizedBox(height: 16),
            AppShimmerBox(width: double.infinity, height: 28),
            SizedBox(height: 10),
            AppShimmerBox(width: 250, height: 28),
            SizedBox(height: 18),
            AppShimmerBox(width: 220, height: 12),
            SizedBox(height: 30),
            AppShimmerBox(width: double.infinity, height: 14),
            SizedBox(height: 10),
            AppShimmerBox(width: double.infinity, height: 14),
            SizedBox(height: 10),
            AppShimmerBox(width: 280, height: 14),
          ],
        ),
      ),
    ],
  );
}

List<_ContentBlock> _htmlBlocks(String html) {
  final matches = RegExp(
    r'<(h[1-6]|p|li)[^>]*>(.*?)</\1>',
    caseSensitive: false,
    dotAll: true,
  ).allMatches(html);
  if (matches.isEmpty) {
    final text = _clean(html);
    return text.isEmpty ? [] : [_ContentBlock(text, false)];
  }
  return matches
      .map((match) {
        final tag = match.group(1)!.toLowerCase();
        final text = _clean(match.group(2) ?? '');
        return _ContentBlock(
          tag == 'li' ? '• $text' : text,
          tag.startsWith('h'),
        );
      })
      .where((block) => block.text.isNotEmpty)
      .toList();
}

String _clean(String value) => value
    .replaceAll(RegExp(r'<[^>]*>'), ' ')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

List<Map<String, dynamic>> _records(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : [];

String _date(dynamic value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  if (date == null) return 'Đang cập nhật';
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

int _integer(dynamic value) => int.tryParse('$value') ?? 0;

int _commentId(Map comment) => _integer(
  comment['comment_id'] ??
      comment['blog_comment_id'] ??
      comment['commentId'] ??
      comment['blogCommentId'] ??
      comment['id'],
);

int _commentUserId(Map comment) {
  final user = comment['user'] is Map
      ? comment['user'] as Map
      : comment['User'] is Map
      ? comment['User'] as Map
      : const {};
  return _integer(comment['user_id'] ?? user['user_id'] ?? user['id']);
}

String _commentContent(Map comment) =>
    '${comment['content'] ?? comment['comment'] ?? ''}';

int _totalCommentCount(List<Map<String, dynamic>> items) {
  var total = items.length;
  for (final item in items) {
    final replies = [
      ..._records(item['replies']),
      ..._records(item['Replies']),
    ];
    total += _totalCommentCount(replies);
  }
  return total;
}
