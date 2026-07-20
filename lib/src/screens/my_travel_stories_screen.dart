import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../core/network/api_client.dart';
import '../design/app_colors.dart';
import '../design/app_widgets.dart';

class MyTravelStoriesScreen extends ConsumerStatefulWidget {
  const MyTravelStoriesScreen({super.key});

  @override
  ConsumerState<MyTravelStoriesScreen> createState() =>
      _MyTravelStoriesScreenState();
}

class _MyTravelStoriesScreenState extends ConsumerState<MyTravelStoriesScreen> {
  List<Map<String, dynamic>> _items = [];
  String _status = 'active';
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref
          .read(dioProvider)
          .get(
            '/travel-stories/mine',
            queryParameters: {'page': _page, 'limit': 6, 'status': _status},
          );
      final result = _parseStories(response.data);
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _total = result.total;
        _totalPages = math.max(1, result.totalPages);
      });
    } catch (error) {
      if (mounted) setState(() => _error = apiError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeStatus(String value) {
    if (value == _status) return;
    setState(() {
      _status = value;
      _page = 1;
      _items = [];
    });
    _load();
  }

  Future<void> _create() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _CreateStorySheet(),
    );
    if (created == true) {
      _status = 'active';
      _page = 1;
      await _load();
    }
  }

  Future<void> _delete(Map<String, dynamic> story) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa story?'),
        content: const Text('Story này sẽ bị xóa khỏi cộng đồng.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(dioProvider).delete('/travel-stories/${_storyId(story)}');
      await _load();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(error))));
    }
  }

  Future<void> _viewers(Map<String, dynamic> story) async {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _StoryViewers(story: story),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    appBar: AppBar(
      title: const Text('My Travel Stories'),
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded, size: 20),
        ),
        const SizedBox(width: 6),
      ],
    ),
    floatingActionButton: FloatingActionButton.small(
      onPressed: _create,
      child: const Icon(Icons.add_rounded),
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Story của tôi',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Quản lý story ảnh và video tồn tại trong 24 giờ.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _StoryTab(
                        label: 'Đang hoạt động',
                        selected: _status == 'active',
                        onTap: () => _changeStatus('active'),
                      ),
                      const SizedBox(width: 8),
                      _StoryTab(
                        label: 'Đã hết hạn',
                        selected: _status == 'expired',
                        onTap: () => _changeStatus('expired'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (_, _) => const AppShimmerBox(
                    width: null,
                    height: null,
                    borderRadius: 14,
                  ),
                  childCount: 6,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 3 / 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppErrorState(error: _error!, onRetry: _load),
            )
          else if (_items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.auto_stories_outlined,
                title: _status == 'active'
                    ? 'Chưa có story đang hoạt động'
                    : 'Chưa có story hết hạn',
                subtitle: _status == 'active'
                    ? 'Chia sẻ một khoảnh khắc từ chuyến đi của bạn.'
                    : 'Story hết hạn sẽ xuất hiện tại đây.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (_, index) => _StoryCard(
                    story: _items[index],
                    onDelete: () => _delete(_items[index]),
                    onViewers: () => _viewers(_items[index]),
                  ),
                  childCount: _items.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 3 / 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
              ),
            ),
          if (!_loading && _error == null && _totalPages > 1)
            SliverToBoxAdapter(
              child: _StoryPagination(
                page: _page,
                totalPages: _totalPages,
                total: _total,
                onChanged: (value) {
                  if (value < 1 || value > _totalPages || value == _page)
                    return;
                  setState(() => _page = value);
                  _load();
                },
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    ),
  );
}

class _StoryTab extends StatelessWidget {
  const _StoryTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.brandDark : Colors.white,
    borderRadius: BorderRadius.circular(17),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? AppColors.brandDark : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.muted,
          ),
        ),
      ),
    ),
  );
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.story,
    required this.onDelete,
    required this.onViewers,
  });
  final Map<String, dynamic> story;
  final VoidCallback onDelete, onViewers;
  @override
  Widget build(BuildContext context) {
    final media = AppConfig.assetUrl(
      '${story['media_url'] ?? story['url'] ?? ''}',
    );
    final video = '${story['media_type'] ?? ''}'.toLowerCase() == 'video';
    final caption = '${story['caption'] ?? ''}';
    final views = int.tryParse('${story['viewer_count'] ?? 0}') ?? 0;
    final expires = DateTime.tryParse(
      '${story['expires_at'] ?? ''}',
    )?.toLocal();
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: const Color(0xFF111827),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (video)
              ColoredBox(
                color: const Color(0xFF1F2937),
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  size: 44,
                  color: Colors.white.withValues(alpha: .9),
                ),
              )
            else if (media.isNotEmpty)
              CachedNetworkImage(imageUrl: media, fit: BoxFit.cover)
            else
              const ColoredBox(
                color: AppColors.borderLight,
                child: Icon(Icons.image_not_supported_outlined),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xDD000000)],
                  stops: [.45, 1],
                ),
              ),
            ),
            Positioned(
              top: 7,
              right: 7,
              child: IconButton.filled(
                onPressed: onDelete,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                  foregroundColor: const Color(0xFFFFCDD2),
                  minimumSize: const Size(30, 30),
                  maximumSize: const Size(30, 30),
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 9,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (caption.isNotEmpty)
                    Text(
                      caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (caption.isNotEmpty) const SizedBox(height: 7),
                  Row(
                    children: [
                      InkWell(
                        onTap: onViewers,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.visibility_outlined,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$views lượt xem',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (expires != null)
                        Text(
                          DateFormat('HH:mm dd/MM').format(expires),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 8,
                          ),
                        ),
                    ],
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

class _CreateStorySheet extends ConsumerStatefulWidget {
  const _CreateStorySheet();
  @override
  ConsumerState<_CreateStorySheet> createState() => _CreateStorySheetState();
}

class _CreateStorySheetState extends ConsumerState<_CreateStorySheet> {
  final _caption = TextEditingController();
  XFile? _file;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final file = await ImagePicker().pickMedia();
    if (file != null && mounted)
      setState(() {
        _file = file;
        _error = null;
      });
  }

  Future<void> _submit() async {
    if (_file == null) {
      setState(() => _error = 'Vui lòng chọn ảnh hoặc video.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final form = FormData.fromMap({
        'media_file': await MultipartFile.fromFile(
          _file!.path,
          filename: _file!.name,
        ),
        if (_caption.text.trim().isNotEmpty) 'caption': _caption.text.trim(),
      });
      await ref.read(dioProvider).post('/travel-stories', data: form);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = apiError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final image =
        _file != null &&
        !RegExp(
          r'\.(mp4|webm|mov)$',
          caseSensitive: false,
        ).hasMatch(_file!.path);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        0,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Thêm Travel Story',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _saving ? null : _pick,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 210,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: _file == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.upload_rounded,
                            size: 32,
                            color: AppColors.brand,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Chọn ảnh hoặc video',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      )
                    : image
                    ? Image.file(File(_file!.path), fit: BoxFit.cover)
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.videocam_rounded,
                            size: 38,
                            color: AppColors.brand,
                          ),
                          SizedBox(height: 7),
                          Text('Video đã được chọn'),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _caption,
              minLines: 2,
              maxLines: 4,
              maxLength: 1000,
              decoration: const InputDecoration(hintText: 'Viết chú thích...'),
            ),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 11),
              ),
            const SizedBox(height: 10),
            SizedBox(
              height: 46,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Đăng story'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryViewers extends ConsumerWidget {
  const _StoryViewers({required this.story});
  final Map<String, dynamic> story;
  @override
  Widget build(BuildContext context, WidgetRef ref) => FutureBuilder<Response>(
    future: ref
        .read(dioProvider)
        .get(
          '/travel-stories/${_storyId(story)}/viewers',
          queryParameters: {'page': 1, 'limit': 100},
        ),
    builder: (context, snapshot) {
      final viewers = snapshot.hasData
          ? unwrapList(snapshot.data!.data, ['viewers', 'items'])
          : <Map<String, dynamic>>[];
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * .56,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Người đã xem',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${story['viewer_count'] ?? viewers.length} lượt',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: snapshot.connectionState != ConnectionState.done
                  ? const Center(child: CircularProgressIndicator())
                  : viewers.isEmpty
                  ? const Center(
                      child: Text(
                        'Chưa có người xem.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      itemCount: viewers.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final viewer = viewers[index];
                        final name = '${viewer['name'] ?? 'Traveler'}';
                        final avatar = AppConfig.assetUrl(
                          '${viewer['avatar_url'] ?? ''}',
                        );
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: AppAvatar(
                            name: name,
                            imageUrl: avatar.isEmpty ? null : avatar,
                            radius: 18,
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            _dateTime(viewer['viewed_at']),
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.muted,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    },
  );
}

class _StoryPagination extends StatelessWidget {
  const _StoryPagination({
    required this.page,
    required this.totalPages,
    required this.total,
    required this.onChanged,
  });
  final int page, totalPages, total;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '$total story · Trang $page/$totalPages',
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
          ),
        ),
        _PageButton(
          icon: Icons.chevron_left_rounded,
          enabled: page > 1,
          onTap: () => onChanged(page - 1),
        ),
        const SizedBox(width: 7),
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            '$page',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 7),
        _PageButton(
          icon: Icons.chevron_right_rounded,
          enabled: page < totalPages,
          onTap: () => onChanged(page + 1),
        ),
      ],
    ),
  );
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 34,
    height: 34,
    child: OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 34),
        padding: EdgeInsets.zero,
      ),
      child: Icon(icon, size: 17),
    ),
  );
}

({List<Map<String, dynamic>> items, int totalPages, int total}) _parseStories(
  dynamic body,
) {
  final root = body is Map ? body : const {};
  final raw = root['data'];
  final items = raw is List
      ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];
  final p = root['pagination'] is Map ? root['pagination'] as Map : const {};
  return (
    items: items,
    totalPages:
        int.tryParse('${p['totalPages'] ?? p['total_pages'] ?? 1}') ?? 1,
    total: int.tryParse('${p['total'] ?? items.length}') ?? items.length,
  );
}

int _storyId(Map story) =>
    int.tryParse(
      '${story['story_id'] ?? story['travel_story_id'] ?? story['id'] ?? 0}',
    ) ??
    0;
String _dateTime(dynamic value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  return date == null ? '' : DateFormat('HH:mm · dd/MM/yyyy').format(date);
}
