import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../core/network/api_client.dart';
import '../design/app_colors.dart';
import '../design/app_widgets.dart';

class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() =>
      _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  int? _busyUserId;
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
      final response = await ref.read(dioProvider).get(
        '/travel-feed/blocked-users',
        queryParameters: {'page': 1, 'limit': 100},
      );
      if (!mounted) return;
      setState(() {
        _items = unwrapList(response.data, ['users', 'blocked_users']);
      });
    } catch (error) {
      if (mounted) setState(() => _error = apiError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unblock(Map<String, dynamic> item) async {
    final id = _userId(item);
    if (id <= 0 || _busyUserId != null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bỏ chặn người dùng?'),
        content: Text(
          '${_name(item)} sẽ có thể xuất hiện lại trong cộng đồng của bạn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Bỏ chặn'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyUserId = id);
    try {
      await ref.read(dioProvider).delete('/travel-feed/users/$id/block');
      if (!mounted) return;
      setState(() => _items.removeWhere((value) => _userId(value) == id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã bỏ chặn ${_name(item)}.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(apiError(error))));
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    appBar: AppBar(
      title: const Text('Người dùng đã chặn'),
      actions: [
        IconButton(
          tooltip: 'Làm mới',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded, size: 20),
        ),
        const SizedBox(width: 6),
      ],
    ),
    body: RefreshIndicator(
      color: AppColors.brand,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(18, 12, 18, 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quản lý quyền riêng tư',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Xem và bỏ chặn những người bị ẩn khỏi cộng đồng của bạn.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              sliver: SliverList.separated(
                itemCount: 4,
                separatorBuilder: (_, _) => const SizedBox(height: 9),
                itemBuilder: (_, _) => const _BlockedUserSkeleton(),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppErrorState(error: _error!, onRetry: _load),
            )
          else if (_items.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.person_off_outlined,
                title: 'Không có người dùng bị chặn',
                subtitle: 'Những người bạn chặn sẽ xuất hiện tại đây.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
              sliver: SliverList.separated(
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 9),
                itemBuilder: (_, index) {
                  final item = _items[index];
                  return _BlockedUserCard(
                    item: item,
                    busy: _busyUserId == _userId(item),
                    onUnblock: () => _unblock(item),
                  );
                },
              ),
            ),
        ],
      ),
    ),
  );
}

class _BlockedUserCard extends StatelessWidget {
  const _BlockedUserCard({
    required this.item,
    required this.busy,
    required this.onUnblock,
  });

  final Map<String, dynamic> item;
  final bool busy;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final nested = _nestedUser(item);
    final name = _name(item);
    final email = '${item['email'] ?? nested['email'] ?? ''}'.trim();
    final avatar = AppConfig.assetUrl(
      '${item['avatar_url'] ?? nested['avatar_url'] ?? nested['avatar'] ?? ''}',
    );

    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          AppAvatar(
            name: name,
            imageUrl: avatar.isEmpty ? null : avatar,
            radius: 22,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 34,
            child: OutlinedButton(
              onPressed: busy ? null : onUnblock,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 11),
                foregroundColor: AppColors.brand,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Bỏ chặn',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockedUserSkeleton extends StatelessWidget {
  const _BlockedUserSkeleton();

  @override
  Widget build(BuildContext context) => Container(
    height: 72,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: AppColors.borderLight),
    ),
    child: const Row(
      children: [
        AppShimmerBox(width: 44, height: 44, borderRadius: 22),
        SizedBox(width: 11),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppShimmerBox(width: 125, height: 11, borderRadius: 5),
              SizedBox(height: 7),
              AppShimmerBox(width: 170, height: 9, borderRadius: 5),
            ],
          ),
        ),
        AppShimmerBox(width: 66, height: 34, borderRadius: 9),
      ],
    ),
  );
}

Map<String, dynamic> _nestedUser(Map<String, dynamic> item) {
  final value = item['blocked_user'] ?? item['blockedUser'] ?? item['user'];
  return value is Map ? Map<String, dynamic>.from(value) : {};
}

int _userId(Map<String, dynamic> item) {
  final user = _nestedUser(item);
  return int.tryParse(
        '${item['blocked_user_id'] ?? item['blockedUserId'] ?? item['user_id'] ?? item['id'] ?? user['user_id'] ?? user['id'] ?? 0}',
      ) ??
      0;
}

String _name(Map<String, dynamic> item) {
  final user = _nestedUser(item);
  final value = '${item['name'] ?? user['name'] ?? item['email'] ?? user['email'] ?? ''}'
      .trim();
  return value.isEmpty ? 'Người dùng #${_userId(item)}' : value;
}
