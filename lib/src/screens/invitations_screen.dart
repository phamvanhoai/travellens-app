import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../core/network/api_client.dart';
import '../design/app_colors.dart';
import '../design/app_widgets.dart';

class InvitationsScreen extends ConsumerStatefulWidget {
  const InvitationsScreen({super.key});

  @override
  ConsumerState<InvitationsScreen> createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends ConsumerState<InvitationsScreen> {
  static const _pageSize = 10;
  static const _filters = [
    ('pending', 'Đang chờ'),
    ('accepted', 'Đã chấp nhận'),
    ('declined', 'Đã từ chối'),
    ('expired', 'Hết hạn'),
    ('canceled', 'Đã hủy'),
    ('all', 'Tất cả'),
  ];

  List<Map<String, dynamic>> _items = [];
  String _status = 'pending';
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  int? _busyId;
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
      final response = await ref.read(dioProvider).get(
        '/group-trip-invites',
        queryParameters: {
          'page': _page,
          'limit': _pageSize,
          if (_status != 'all') 'status': _status,
        },
      );
      final result = _parseInvitations(response.data);
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

  void _changePage(int value) {
    if (value < 1 || value > _totalPages || value == _page) return;
    setState(() => _page = value);
    _load();
  }

  Future<void> _respond(Map<String, dynamic> invite, bool accept) async {
    final id = _inviteId(invite);
    if (id <= 0 || _busyId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(accept ? 'Chấp nhận lời mời?' : 'Từ chối lời mời?'),
        content: Text(
          accept
              ? 'Bạn sẽ tham gia “${_tripName(invite)}” với tư cách thành viên.'
              : 'Bạn có chắc muốn từ chối lời mời tham gia “${_tripName(invite)}”?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: accept
                ? null
                : FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(accept ? 'Chấp nhận' : 'Từ chối'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyId = id);
    try {
      await ref
          .read(dioProvider)
          .post('/group-trip-invites/$id/${accept ? 'accept' : 'decline'}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept ? 'Đã chấp nhận lời mời.' : 'Đã từ chối lời mời.',
          ),
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(apiError(error))));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    appBar: AppBar(
      title: const Text('Lời mời chuyến đi'),
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lời mời của bạn',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Xem và phản hồi lời mời tham gia chuyến đi nhóm.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                  const SizedBox(height: 13),
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 7),
                      itemBuilder: (_, index) {
                        final item = _filters[index];
                        final selected = item.$1 == _status;
                        return ChoiceChip(
                          label: Text(item.$2),
                          selected: selected,
                          onSelected: (_) => _changeStatus(item.$1),
                          showCheckmark: false,
                          visualDensity: VisualDensity.compact,
                          labelStyle: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : AppColors.muted,
                          ),
                          selectedColor: AppColors.brand,
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: selected
                                ? AppColors.brand
                                : AppColors.borderLight,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              sliver: SliverList.separated(
                itemCount: 3,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, _) => const _InvitationSkeleton(),
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
                icon: Icons.mark_email_read_outlined,
                title: 'Không có lời mời',
                subtitle: 'Các lời mời chuyến đi nhóm sẽ xuất hiện tại đây.',
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              sliver: SliverList.separated(
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final item = _items[index];
                  return _InvitationCard(
                    invite: item,
                    busy: _busyId == _inviteId(item),
                    onAccept: () => _respond(item, true),
                    onDecline: () => _respond(item, false),
                  );
                },
              ),
            ),
            if (_totalPages > 1)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 2, 18, 110),
                  child: _InvitationPagination(
                    page: _page,
                    totalPages: _totalPages,
                    total: _total,
                    onPageChanged: _changePage,
                  ),
                ),
              )
            else
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ],
      ),
    ),
  );
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.invite,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final Map<String, dynamic> invite;
  final bool busy;
  final VoidCallback onAccept, onDecline;

  @override
  Widget build(BuildContext context) {
    final trip = _trip(invite);
    final status = '${invite['status'] ?? 'pending'}'.toLowerCase();
    final image = AppConfig.assetUrl(
      '${trip['cover_image'] ?? trip['thumbnail_url'] ?? trip['image_url'] ?? ''}',
    );
    final destination = '${trip['destination_name'] ?? ''}'.trim();
    final dates = _dateRange(trip['start_date'], trip['end_date']);
    final expires = _formatDate(invite['expires_at']);

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: image.isEmpty
                      ? const ColoredBox(
                          color: AppColors.borderLight,
                          child: Icon(
                            Icons.groups_rounded,
                            color: AppColors.subtle,
                          ),
                        )
                      : CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _tripName(invite),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _StatusBadge(status: status),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Được mời bởi ${_inviterName(invite)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppColors.muted,
                      ),
                    ),
                    if (destination.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      _InfoLine(Icons.location_on_outlined, destination),
                    ],
                    if (dates.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      _InfoLine(Icons.calendar_month_outlined, dates),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (expires.isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoLine(Icons.schedule_rounded, 'Hết hạn $expires'),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: FilledButton.icon(
                      onPressed: busy ? null : onAccept,
                      icon: busy
                          ? const SizedBox.square(
                              dimension: 13,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 15),
                      label: const Text(
                        'Chấp nhận',
                        style: TextStyle(fontSize: 10.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : onDecline,
                      icon: const Icon(Icons.close_rounded, size: 15),
                      label: const Text(
                        'Từ chối',
                        style: TextStyle(fontSize: 10.5),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: Color(0xFFFECACA)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (status == 'accepted') ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton(
                onPressed: () {
                  final id = _tripId(invite);
                  if (id > 0) context.push('/group-trips/$id');
                },
                child: const Text(
                  'Xem chuyến đi',
                  style: TextStyle(fontSize: 10.5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 12, color: AppColors.muted),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 9, color: AppColors.muted),
        ),
      ),
    ],
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (status) {
      'accepted' => ('Đã nhận', const Color(0xFF15803D), const Color(0xFFDCFCE7)),
      'declined' => ('Từ chối', AppColors.error, const Color(0xFFFEE2E2)),
      'expired' => ('Hết hạn', const Color(0xFF64748B), const Color(0xFFF1F5F9)),
      'canceled' => ('Đã hủy', const Color(0xFF64748B), const Color(0xFFF1F5F9)),
      _ => ('Đang chờ', const Color(0xFFB45309), const Color(0xFFFEF3C7)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _InvitationSkeleton extends StatelessWidget {
  const _InvitationSkeleton();

  @override
  Widget build(BuildContext context) => Container(
    height: 150,
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: AppColors.borderLight),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppShimmerBox(width: 64, height: 64, borderRadius: 10),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppShimmerBox(width: 160, height: 12, borderRadius: 5),
              SizedBox(height: 8),
              AppShimmerBox(width: 120, height: 9, borderRadius: 5),
              SizedBox(height: 8),
              AppShimmerBox(width: 180, height: 9, borderRadius: 5),
              Spacer(),
              AppShimmerBox(width: double.infinity, height: 36, borderRadius: 9),
            ],
          ),
        ),
      ],
    ),
  );
}

class _InvitationPagination extends StatelessWidget {
  const _InvitationPagination({
    required this.page,
    required this.totalPages,
    required this.total,
    required this.onPageChanged,
  });
  final int page, totalPages, total;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          '$total lời mời · Trang $page/$totalPages',
          style: const TextStyle(fontSize: 9.5, color: AppColors.muted),
        ),
      ),
      IconButton.outlined(
        onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
        icon: const Icon(Icons.chevron_left_rounded, size: 18),
        visualDensity: VisualDensity.compact,
      ),
      const SizedBox(width: 7),
      IconButton.outlined(
        onPressed: page < totalPages ? () => onPageChanged(page + 1) : null,
        icon: const Icon(Icons.chevron_right_rounded, size: 18),
        visualDensity: VisualDensity.compact,
      ),
    ],
  );
}

({List<Map<String, dynamic>> items, int totalPages, int total})
_parseInvitations(dynamic body) {
  final items = unwrapList(body, ['invites', 'invitations']);
  final root = body is Map ? body : const {};
  final data = root['data'] is Map ? root['data'] as Map : root;
  final pagination = data['pagination'] is Map
      ? data['pagination'] as Map
      : root['pagination'] is Map
      ? root['pagination'] as Map
      : const {};
  final total = int.tryParse('${pagination['total'] ?? items.length}') ?? items.length;
  final totalPages = int.tryParse(
        '${pagination['totalPages'] ?? pagination['total_pages'] ?? 1}',
      ) ??
      1;
  return (items: items, totalPages: totalPages, total: total);
}

Map<String, dynamic> _trip(Map<String, dynamic> invite) {
  final value = invite['group_trip'] ?? invite['trip'];
  return value is Map ? Map<String, dynamic>.from(value) : {};
}

int _inviteId(Map<String, dynamic> invite) =>
    int.tryParse('${invite['group_trip_invite_id'] ?? invite['invite_id'] ?? invite['id'] ?? 0}') ?? 0;
int _tripId(Map<String, dynamic> invite) {
  final trip = _trip(invite);
  return int.tryParse('${invite['group_trip_id'] ?? trip['group_trip_id'] ?? trip['id'] ?? 0}') ?? 0;
}

String _tripName(Map<String, dynamic> invite) {
  final trip = _trip(invite);
  return '${trip['name'] ?? invite['group_trip_name'] ?? 'Chuyến đi nhóm #${_tripId(invite)}'}';
}

String _inviterName(Map<String, dynamic> invite) {
  final value = invite['inviter'] ?? invite['invited_by_user'];
  final inviter = value is Map ? value : const {};
  return '${inviter['name'] ?? invite['inviter_name'] ?? 'Trưởng nhóm'}';
}

String _formatDate(dynamic value) {
  final date = DateTime.tryParse('${value ?? ''}')?.toLocal();
  return date == null ? '' : DateFormat('dd/MM/yyyy, HH:mm').format(date);
}

String _dateRange(dynamic start, dynamic end) {
  final startDate = DateTime.tryParse('${start ?? ''}')?.toLocal();
  final endDate = DateTime.tryParse('${end ?? ''}')?.toLocal();
  if (startDate == null) return '';
  final formatter = DateFormat('dd/MM/yyyy');
  return endDate == null
      ? formatter.format(startDate)
      : '${formatter.format(startDate)} – ${formatter.format(endDate)}';
}
