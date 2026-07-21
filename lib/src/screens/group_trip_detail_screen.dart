import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../core/network/api_client.dart';
import '../design/app_colors.dart';
import '../design/app_widgets.dart';

class GroupTripDetailScreen extends ConsumerStatefulWidget {
  const GroupTripDetailScreen({super.key, required this.id});
  final int id;

  @override
  ConsumerState<GroupTripDetailScreen> createState() =>
      _GroupTripDetailScreenState();
}

class _GroupTripDetailScreenState extends ConsumerState<GroupTripDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);
  Map<String, dynamic>? _trip;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _invites = [];
  bool _loading = true;
  bool _loadingMembers = true;
  bool _loadingInvites = true;
  String? _error;

  bool get _leader {
    final current = _trip?['current_member'];
    return current is Map &&
        '${current['status'] ?? ''}' == 'active' &&
        '${current['role'] ?? ''}' == 'leader';
  }

  bool get _member {
    final current = _trip?['current_member'];
    return current is Map && '${current['status'] ?? ''}' == 'active';
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await _loadTrip();
    if (_trip != null) {
      await Future.wait([_loadMembers(), if (_leader) _loadInvites()]);
    }
  }

  Future<void> _loadTrip() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref
          .read(dioProvider)
          .get('/group-trips/${widget.id}');
      if (!mounted) return;
      setState(() => _trip = _unwrapTrip(response.data));
    } catch (error) {
      if (mounted) setState(() => _error = apiError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final response = await ref
          .read(dioProvider)
          .get(
            '/group-trips/${widget.id}/members',
            queryParameters: {'page': 1, 'limit': 100},
          );
      if (mounted) {
        setState(() => _members = unwrapList(response.data, ['members']));
      }
    } catch (_) {
      if (mounted) setState(() => _members = []);
    } finally {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _loadInvites() async {
    setState(() => _loadingInvites = true);
    try {
      final response = await ref
          .read(dioProvider)
          .get(
            '/group-trips/${widget.id}/invites',
            queryParameters: {'page': 1, 'limit': 100},
          );
      if (mounted) {
        setState(
          () =>
              _invites = unwrapList(response.data, ['invites', 'invitations']),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _invites = []);
    } finally {
      if (mounted) setState(() => _loadingInvites = false);
    }
  }

  Future<void> _refresh() async {
    await _loadTrip();
    if (_trip != null) {
      await Future.wait([_loadMembers(), if (_leader) _loadInvites()]);
    }
  }

  Future<void> _showActions() async {
    if (_trip == null) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_leader) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Chỉnh sửa chuyến đi'),
                onTap: () => Navigator.pop(sheetContext, 'edit'),
              ),
              if ('${_trip!['visibility']}' == 'public')
                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: const Text('Sao chép liên kết công khai'),
                  onTap: () => Navigator.pop(sheetContext, 'share'),
                ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Xóa chuyến đi',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () => Navigator.pop(sheetContext, 'delete'),
              ),
            ] else if (_member)
              ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Rời chuyến đi',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () => Navigator.pop(sheetContext, 'leave'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      final changed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _EditTripSheet(trip: _trip!, id: widget.id),
      );
      if (changed == true) await _refresh();
    } else if (action == 'share') {
      await Clipboard.setData(ClipboardData(text: '/group-trips/${widget.id}'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã sao chép liên kết chuyến đi.')),
        );
      }
    } else if (action == 'delete') {
      await _removeTrip();
    } else if (action == 'leave') {
      await _leaveTrip();
    }
  }

  Future<void> _removeTrip() async {
    if (!await _confirm(
      'Xóa chuyến đi?',
      'Chuyến đi sẽ bị lưu trữ và các lời mời đang chờ sẽ bị hủy.',
      'Xóa',
    )) {
      return;
    }
    try {
      await ref.read(dioProvider).delete('/group-trips/${widget.id}');
      if (mounted) context.go('/group-trips');
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _leaveTrip() async {
    if (!await _confirm(
      'Rời chuyến đi?',
      'Bạn sẽ cần một lời mời mới để tham gia lại.',
      'Rời nhóm',
    )) {
      return;
    }
    try {
      await ref.read(dioProvider).post('/group-trips/${widget.id}/leave');
      if (mounted) context.go('/group-trips');
    } catch (error) {
      _showError(error);
    }
  }

  Future<bool> _confirm(String title, String message, String label) async =>
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
              child: Text(label),
            ),
          ],
        ),
      ) ??
      false;

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(apiError(error))));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _DetailSkeleton();
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết chuyến đi')),
        body: AppErrorState(error: _error!, onRetry: _refresh),
      );
    }
    final trip = _trip;
    if (trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết chuyến đi')),
        body: const AppEmptyState(
          icon: Icons.groups_outlined,
          title: 'Không tìm thấy chuyến đi',
          subtitle: 'Chuyến đi có thể đã bị xóa hoặc lưu trữ.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Chi tiết chuyến đi'),
        actions: [
          if (_leader || _member)
            IconButton(
              onPressed: _showActions,
              icon: const Icon(Icons.more_horiz_rounded, size: 20),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          _TripHeader(trip: trip, leader: _leader),
          Material(
            color: Colors.white,
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelPadding: const EdgeInsets.symmetric(horizontal: 14),
              labelStyle: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
              tabs: const [
                Tab(text: 'Tổng quan'),
                Tab(text: 'Lịch trình'),
                Tab(text: 'Thành viên'),
                Tab(text: 'Lời mời'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _OverviewTab(trip: trip, onRefresh: _refresh),
                _ItineraryTab(trip: trip, leader: _leader, onChanged: _refresh),
                _MembersTab(
                  members: _members,
                  loading: _loadingMembers,
                  trip: trip,
                  leader: _leader,
                  onChanged: _refresh,
                ),
                _InvitesTab(
                  tripId: widget.id,
                  leader: _leader,
                  invites: _invites,
                  loading: _loadingInvites,
                  onChanged: _loadInvites,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TripHeader extends StatelessWidget {
  const _TripHeader({required this.trip, required this.leader});
  final Map<String, dynamic> trip;
  final bool leader;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1D4ED8), Color(0xFF0891B2)],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SmallBadge(
              icon: '${trip['visibility']}' == 'public'
                  ? Icons.public_rounded
                  : Icons.lock_outline_rounded,
              text: '${trip['visibility']}' == 'public'
                  ? 'Công khai'
                  : 'Riêng tư',
            ),
            if (leader) ...[
              const SizedBox(width: 6),
              const _SmallBadge(
                icon: Icons.workspace_premium,
                text: 'Trưởng nhóm',
              ),
            ],
          ],
        ),
        const SizedBox(height: 9),
        Text(
          '${trip['name'] ?? 'Chuyến đi nhóm'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            height: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _HeaderInfo(
                Icons.location_on_outlined,
                '${trip['destination_name'] ?? 'Địa điểm đang cập nhật'}',
              ),
            ),
            const SizedBox(width: 10),
            _HeaderInfo(
              Icons.groups_outlined,
              '${_int(trip['member_count'])}${_int(trip['max_members']) > 0 ? '/${_int(trip['max_members'])}' : ''}',
            ),
          ],
        ),
      ],
    ),
  );
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .18),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: Colors.white),
        const SizedBox(width: 3),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _HeaderInfo extends StatelessWidget {
  const _HeaderInfo(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: Colors.white70),
      const SizedBox(width: 4),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 190),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 9.5),
        ),
      ),
    ],
  );
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.trip, required this.onRefresh});
  final Map<String, dynamic> trip;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 110),
      children: [
        const _SectionTitle('Thông tin chuyến đi'),
        const SizedBox(height: 9),
        _InfoCard(
          children: [
            _DetailRow(
              Icons.calendar_month_outlined,
              'Thời gian',
              _dateRange(trip['start_date'], trip['end_date']),
            ),
            _DetailRow(
              Icons.location_on_outlined,
              'Điểm đến',
              '${trip['destination_name'] ?? 'Đang cập nhật'}',
            ),
            _DetailRow(
              Icons.groups_outlined,
              'Thành viên',
              '${_int(trip['member_count'])}${_int(trip['max_members']) > 0 ? ' / ${_int(trip['max_members'])}' : ''} người',
              last: true,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _SectionTitle('Mô tả'),
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: _cardDecoration(),
          child: Text(
            '${trip['description'] ?? ''}'.trim().isEmpty
                ? 'Chưa có mô tả cho chuyến đi này.'
                : '${trip['description']}',
            style: const TextStyle(
              fontSize: 11,
              height: 1.55,
              color: AppColors.muted,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ItineraryTab extends ConsumerStatefulWidget {
  const _ItineraryTab({
    required this.trip,
    required this.leader,
    required this.onChanged,
  });
  final Map<String, dynamic> trip;
  final bool leader;
  final Future<void> Function() onChanged;

  @override
  ConsumerState<_ItineraryTab> createState() => _ItineraryTabState();
}

class _ItineraryTabState extends ConsumerState<_ItineraryTab> {
  bool _working = false;

  List<Map<String, dynamic>> get _items {
    final items =
        (widget.trip['itinerary'] is List
                ? widget.trip['itinerary'] as List
                : const [])
            .whereType<Map>()
            .map((value) => Map<String, dynamic>.from(value))
            .toList();
    items.sort(_compareItinerary);
    return items;
  }

  Future<void> _openForm([Map<String, dynamic>? item]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItineraryFormSheet(trip: widget.trip, item: item),
    );
    if (changed == true) await widget.onChanged();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa hoạt động?'),
        content: Text(
          '“${item['title'] ?? 'Hoạt động'}” sẽ bị xóa khỏi lịch trình.',
        ),
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
    setState(() => _working = true);
    try {
      await ref
          .read(dioProvider)
          .delete(
            '/group-trips/${_int(widget.trip['group_trip_id'])}/itinerary/${_itineraryId(item)}',
          );
      await widget.onChanged();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(error))));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 110),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lịch trình chuyến đi',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Các điểm dừng được sắp xếp theo ngày và giờ.',
                    style: TextStyle(fontSize: 9.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            if (widget.leader)
              SizedBox(
                height: 34,
                child: FilledButton.icon(
                  onPressed: _working ? null : () => _openForm(),
                  icon: const Icon(Icons.add_rounded, size: 15),
                  label: const Text('Thêm', style: TextStyle(fontSize: 10)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 55),
            child: AppEmptyState(
              icon: Icons.route_outlined,
              title: 'Chưa có lịch trình',
              subtitle: 'Thêm hoạt động đầu tiên cho chuyến đi.',
            ),
          )
        else
          ..._timeline(items),
      ],
    );
  }

  List<Widget> _timeline(List<Map<String, dynamic>> items) {
    final widgets = <Widget>[];
    String? currentDate;
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final date = _dayKey(item['itinerary_date']);
      if (date != currentDate) {
        if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 12));
        widgets.add(_ItineraryDayHeader(date: item['itinerary_date']));
        widgets.add(const SizedBox(height: 7));
        currentDate = date;
      }
      final nextSameDate =
          index + 1 < items.length &&
          _dayKey(items[index + 1]['itinerary_date']) == date;
      widgets.add(
        _ItineraryTimelineCard(
          item: item,
          showLine: nextSameDate,
          leader: widget.leader,
          working: _working,
          onEdit: () => _openForm(item),
          onDelete: () => _delete(item),
        ),
      );
    }
    return widgets;
  }
}

class _ItineraryDayHeader extends StatelessWidget {
  const _ItineraryDayHeader({required this.date});
  final dynamic date;
  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse('${date ?? ''}')?.toLocal();
    final label = parsed == null
        ? '${date ?? ''}'
        : _vietnameseDayLabel(parsed);
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(
            Icons.calendar_today_rounded,
            size: 13,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _ItineraryTimelineCard extends StatelessWidget {
  const _ItineraryTimelineCard({
    required this.item,
    required this.showLine,
    required this.leader,
    required this.working,
    required this.onEdit,
    required this.onDelete,
  });
  final Map<String, dynamic> item;
  final bool showLine, leader, working;
  final VoidCallback onEdit, onDelete;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 28,
          child: Column(
            children: [
              const SizedBox(height: 13),
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
              if (showLine)
                Expanded(
                  child: Container(width: 1.5, color: const Color(0xFFBFDBFE)),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(11, 9, 7, 9),
            decoration: _cardDecoration(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 43,
                  child: Text(
                    _time(item['start_time']),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.brand,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item['title'] ?? 'Hoạt động'}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              _itineraryLocation(item),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if ('${item['description'] ?? ''}'.trim().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          '${item['description']}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9.5,
                            height: 1.35,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (leader)
                  PopupMenuButton<String>(
                    enabled: !working,
                    padding: EdgeInsets.zero,
                    iconSize: 17,
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Xóa',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _ItineraryFormSheet extends ConsumerStatefulWidget {
  const _ItineraryFormSheet({required this.trip, this.item});
  final Map<String, dynamic> trip;
  final Map<String, dynamic>? item;
  @override
  ConsumerState<_ItineraryFormSheet> createState() =>
      _ItineraryFormSheetState();
}

class _ItineraryFormSheetState extends ConsumerState<_ItineraryFormSheet> {
  late final _title = TextEditingController(
    text: '${widget.item?['title'] ?? ''}',
  );
  late final _description = TextEditingController(
    text: '${widget.item?['description'] ?? ''}',
  );
  late final _order = TextEditingController(
    text: '${widget.item?['order_index'] ?? 1}',
  );
  late DateTime? _dateValue = DateTime.tryParse(
    '${widget.item?['itinerary_date'] ?? widget.trip['start_date'] ?? ''}',
  );
  late TimeOfDay? _timeValue = _parseTime(widget.item?['start_time']);
  List<Map<String, dynamic>> _locations = [];
  int? _locationId;
  bool _loadingLocations = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _locationId = _int(widget.item?['location_id']);
    if (_locationId == 0) _locationId = null;
    _loadLocations();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    try {
      final response = await ref
          .read(dioProvider)
          .get('/locations', queryParameters: {'page': 1, 'limit': 100});
      final values = unwrapList(response.data, ['locations']);
      final unique = <int, Map<String, dynamic>>{};
      for (final item in values) {
        final id = _locationItemId(item);
        if (id > 0) unique[id] = item;
      }
      if (mounted) setState(() => _locations = unique.values.toList());
    } catch (_) {
      if (mounted) setState(() => _locations = []);
    } finally {
      if (mounted) setState(() => _loadingLocations = false);
    }
  }

  Future<void> _pickDate() async {
    final start =
        DateTime.tryParse('${widget.trip['start_date']}') ?? DateTime.now();
    final end =
        DateTime.tryParse('${widget.trip['end_date']}') ??
        start.add(const Duration(days: 365));
    final initial = _dateValue == null || _dateValue!.isBefore(start)
        ? start
        : _dateValue!.isAfter(end)
        ? end
        : _dateValue!;
    final value = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: start,
      lastDate: end,
    );
    if (value != null) setState(() => _dateValue = value);
  }

  Future<void> _pickTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: _timeValue ?? TimeOfDay.now(),
    );
    if (value != null) setState(() => _timeValue = value);
  }

  Future<void> _save() async {
    final hasExistingCustomLocation = '${widget.item?['custom_location'] ?? ''}'
        .trim()
        .isNotEmpty;
    if (_title.text.trim().isEmpty ||
        _dateValue == null ||
        (_locationId == null && !hasExistingCustomLocation)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tiêu đề, ngày và địa điểm.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final data = {
        'itinerary_date': DateFormat('yyyy-MM-dd').format(_dateValue!),
        if (_timeValue != null)
          'start_time':
              '${_timeValue!.hour.toString().padLeft(2, '0')}:${_timeValue!.minute.toString().padLeft(2, '0')}',
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        if (_locationId != null)
          'location_id': _locationId
        else ...{
          'custom_location': widget.item?['custom_location'],
          'latitude': widget.item?['latitude'],
          'longitude': widget.item?['longitude'],
        },
        'order_index': int.tryParse(_order.text.trim()) ?? 1,
      };
      final tripId = _int(widget.trip['group_trip_id']);
      if (widget.item == null) {
        await ref
            .read(dioProvider)
            .post('/group-trips/$tripId/itinerary', data: data);
      } else {
        await ref
            .read(dioProvider)
            .patch(
              '/group-trips/$tripId/itinerary/${_itineraryId(widget.item!)}',
              data: data,
            );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        18,
        14,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.item == null ? 'Thêm hoạt động' : 'Chỉnh sửa hoạt động',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: _ItineraryPicker(
                  label: 'Ngày',
                  value: _dateValue == null
                      ? 'Chọn ngày'
                      : DateFormat('dd/MM/yyyy').format(_dateValue!),
                  icon: Icons.calendar_month_outlined,
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ItineraryPicker(
                  label: 'Giờ bắt đầu',
                  value: _timeValue?.format(context) ?? 'Chọn giờ',
                  icon: Icons.schedule_rounded,
                  onTap: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Tên hoạt động *'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _description,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Mô tả'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            initialValue:
                _locations.any((item) => _locationItemId(item) == _locationId)
                ? _locationId
                : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Địa điểm *',
              suffixIcon: _loadingLocations
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            hint: Text(
              '${widget.item?['custom_location'] ?? 'Chọn địa điểm'}',
              style: const TextStyle(fontSize: 10.5),
            ),
            items: _locations
                .map(
                  (item) => DropdownMenuItem(
                    value: _locationItemId(item),
                    child: Text(
                      _locationItemName(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _locationId = value),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _order,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Thứ tự'),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.item == null ? 'Thêm hoạt động' : 'Lưu thay đổi',
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ItineraryPicker extends StatelessWidget {
  const _ItineraryPicker({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });
  final String label, value;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: Icon(icon, size: 17),
      ),
      child: Text(value, style: const TextStyle(fontSize: 10.5)),
    ),
  );
}

class _MembersTab extends ConsumerWidget {
  const _MembersTab({
    required this.members,
    required this.loading,
    required this.trip,
    required this.leader,
    required this.onChanged,
  });
  final List<Map<String, dynamic>> members;
  final bool loading, leader;
  final Map<String, dynamic> trip;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (loading) return const _TabLoading();
    if (members.isEmpty) {
      return const AppEmptyState(
        icon: Icons.person_outline_rounded,
        title: 'Chưa có thành viên',
        subtitle: 'Mời bạn bè cùng tham gia chuyến đi.',
      );
    }
    final current = trip['current_member'] is Map
        ? trip['current_member'] as Map
        : const {};
    final currentId = _int(current['user_id']);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 110),
      itemCount: members.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final member = members[index];
        final userId = _int(member['user_id']);
        final canManage =
            leader && userId != currentId && '${member['role']}' != 'leader';
        return _MemberCard(
          member: member,
          canManage: canManage,
          onRemove: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Xóa thành viên?'),
                content: Text(
                  '${_memberName(member)} sẽ bị xóa khỏi chuyến đi.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Hủy'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Xóa'),
                  ),
                ],
              ),
            );
            if (confirmed != true || !context.mounted) return;
            try {
              await ref
                  .read(dioProvider)
                  .delete(
                    '/group-trips/${_int(trip['group_trip_id'])}/members/$userId',
                  );
              await onChanged();
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(apiError(error))));
              }
            }
          },
        );
      },
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.canManage,
    required this.onRemove,
  });
  final Map<String, dynamic> member;
  final bool canManage;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final name = _memberName(member);
    return Container(
      constraints: const BoxConstraints(minHeight: 66),
      padding: const EdgeInsets.all(10),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          AppAvatar(
            name: name,
            imageUrl: AppConfig.assetUrl('${member['avatar_url'] ?? ''}'),
            radius: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if ('${member['role']}' == 'leader') ...[
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.workspace_premium,
                        size: 13,
                        color: Color(0xFFD97706),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${member['email'] ?? member['phone'] ?? 'Thành viên'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9, color: AppColors.muted),
                ),
              ],
            ),
          ),
          if (canManage)
            IconButton(
              tooltip: 'Xóa thành viên',
              onPressed: onRemove,
              icon: const Icon(
                Icons.person_remove_outlined,
                size: 17,
                color: AppColors.error,
              ),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _InvitesTab extends ConsumerStatefulWidget {
  const _InvitesTab({
    required this.tripId,
    required this.leader,
    required this.invites,
    required this.loading,
    required this.onChanged,
  });
  final int tripId;
  final bool leader, loading;
  final List<Map<String, dynamic>> invites;
  final Future<void> Function() onChanged;

  @override
  ConsumerState<_InvitesTab> createState() => _InvitesTabState();
}

class _InvitesTabState extends ConsumerState<_InvitesTab> {
  final _email = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (email.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(dioProvider)
          .post(
            '/group-trips/${widget.tripId}/invites',
            data: {'email': email},
          );
      _email.clear();
      await widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã gửi lời mời.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(error))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.leader) {
      return const AppEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Chỉ dành cho trưởng nhóm',
        subtitle: 'Trưởng nhóm có thể quản lý lời mời tại đây.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 110),
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 42,
                child: TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 10.5),
                  decoration: const InputDecoration(
                    hintText: 'email@example.com',
                    prefixIcon: Icon(Icons.mail_outline_rounded, size: 17),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 42,
              child: FilledButton(
                onPressed: _sending ? null : _send,
                child: _sending
                    ? const SizedBox.square(
                        dimension: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Mời', style: TextStyle(fontSize: 10.5)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (widget.loading)
          ...List.generate(
            4,
            (index) => const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: AppShimmerBox(
                width: double.infinity,
                height: 66,
                borderRadius: 13,
              ),
            ),
          )
        else if (widget.invites.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 45),
            child: AppEmptyState(
              icon: Icons.mark_email_read_outlined,
              title: 'Chưa có lời mời',
              subtitle: 'Mời thành viên bằng email ở phía trên.',
            ),
          )
        else
          ...widget.invites.map((invite) => _InviteCard(invite: invite)),
      ],
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.invite});
  final Map<String, dynamic> invite;
  @override
  Widget build(BuildContext context) {
    final user = invite['invited_user'] is Map
        ? invite['invited_user'] as Map
        : const {};
    final email =
        '${invite['invited_email'] ?? user['email'] ?? 'Không có email'}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.mail_outline_rounded,
              size: 17,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user['name'] ?? email}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 8.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          _InviteStatus(status: '${invite['status'] ?? 'pending'}'),
        ],
      ),
    );
  }
}

class _InviteStatus extends StatelessWidget {
  const _InviteStatus({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final accepted = status == 'accepted';
    final pending = status == 'pending';
    final color = accepted
        ? const Color(0xFF15803D)
        : pending
        ? const Color(0xFFB45309)
        : AppColors.muted;
    final background = accepted
        ? const Color(0xFFDCFCE7)
        : pending
        ? const Color(0xFFFEF3C7)
        : AppColors.borderLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _EditTripSheet extends ConsumerStatefulWidget {
  const _EditTripSheet({required this.trip, required this.id});
  final Map<String, dynamic> trip;
  final int id;
  @override
  ConsumerState<_EditTripSheet> createState() => _EditTripSheetState();
}

class _EditTripSheetState extends ConsumerState<_EditTripSheet> {
  late final _name = TextEditingController(
    text: '${widget.trip['name'] ?? ''}',
  );
  late final _description = TextEditingController(
    text: '${widget.trip['description'] ?? ''}',
  );
  late final _max = TextEditingController(
    text: '${widget.trip['max_members'] ?? ''}',
  );
  late bool _public = '${widget.trip['visibility']}' == 'public';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(dioProvider)
          .patch(
            '/group-trips/${widget.id}/settings',
            data: {
              'name': _name.text.trim(),
              'description': _description.text.trim(),
              'destination_id': widget.trip['destination_id'],
              'destination_name': widget.trip['destination_name'],
              'start_date': widget.trip['start_date'],
              'end_date': widget.trip['end_date'],
              'max_members': int.tryParse(_max.text.trim()),
              'visibility': _public ? 'public' : 'private',
            },
          );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        18,
        16,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chỉnh sửa chuyến đi',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Tên chuyến đi'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _description,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Mô tả'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _max,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Số thành viên tối đa',
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _public,
            onChanged: (value) => setState(() => _public = value),
            title: const Text(
              'Chuyến đi công khai',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Lưu thay đổi'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: _cardDecoration(),
    child: Column(children: children),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.icon, this.label, this.value, {this.last = false});
  final IconData icon;
  final String label, value;
  final bool last;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 11),
    decoration: BoxDecoration(
      border: last
          ? null
          : const Border(bottom: BorderSide(color: AppColors.borderLight)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 16, color: AppColors.brand),
        const SizedBox(width: 9),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.muted),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _TabLoading extends StatelessWidget {
  const _TabLoading();
  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 110),
    itemCount: 4,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (_, _) => const AppShimmerBox(
      width: double.infinity,
      height: 66,
      borderRadius: 13,
    ),
  );
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: const Column(
      children: [
        AppShimmerBox(width: double.infinity, height: 140, borderRadius: 0),
        SizedBox(height: 12),
        Expanded(child: _TabLoading()),
      ],
    ),
  );
}

BoxDecoration _cardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(13),
  border: Border.all(color: AppColors.borderLight),
);

Map<String, dynamic>? _unwrapTrip(dynamic body) {
  dynamic value = unwrap(body);
  if (value is Map && value['group_trip'] is Map) value = value['group_trip'];
  return value is Map ? Map<String, dynamic>.from(value) : null;
}

int _int(dynamic value) => int.tryParse('${value ?? 0}') ?? 0;
int _itineraryId(Map item) => _int(item['itinerary_item_id'] ?? item['id']);
int _locationItemId(Map item) =>
    _int(item['location_id'] ?? item['travel_location_id'] ?? item['id']);
String _locationItemName(Map item) =>
    '${item['name'] ?? item['title'] ?? 'Địa điểm #${_locationItemId(item)}'}';
String _memberName(Map member) =>
    '${member['name'] ?? 'Thành viên #${_int(member['user_id'])}'}';
String _date(dynamic value) {
  final date = DateTime.tryParse('${value ?? ''}')?.toLocal();
  return date == null ? '' : DateFormat('dd/MM/yyyy').format(date);
}

String _dateRange(dynamic start, dynamic end) {
  final first = _date(start), last = _date(end);
  if (first.isEmpty) return 'Đang cập nhật';
  return last.isEmpty ? first : '$first – $last';
}

String _vietnameseDayLabel(DateTime date) {
  const weekdays = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '${weekdays[date.weekday - 1]}, $day tháng $month';
}

String _dayKey(dynamic value) {
  final text = '${value ?? ''}';
  if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(text)) {
    return text.substring(0, 10);
  }
  final date = DateTime.tryParse(text)?.toLocal();
  return date == null ? text : DateFormat('yyyy-MM-dd').format(date);
}

String _time(dynamic value) {
  final text = '${value ?? ''}'.trim();
  if (text.isEmpty) return '--:--';
  final match = RegExp(r'^(\d{2}):(\d{2})').firstMatch(text);
  if (match != null) return '${match.group(1)}:${match.group(2)}';
  final date = DateTime.tryParse(text)?.toLocal();
  return date == null ? text : DateFormat('HH:mm').format(date);
}

TimeOfDay? _parseTime(dynamic value) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch('${value ?? ''}');
  if (match == null) return null;
  final hour = int.tryParse(match.group(1) ?? '');
  final minute = int.tryParse(match.group(2) ?? '');
  if (hour == null || minute == null || hour > 23 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String _itineraryLocation(Map item) {
  final nested = item['location'];
  final location = nested is Map ? nested : const {};
  return '${item['custom_location'] ?? item['location_name'] ?? location['name'] ?? (_int(item['location_id']) > 0 ? 'Địa điểm #${_int(item['location_id'])}' : 'Chưa có địa điểm')}';
}

int _compareItinerary(Map<String, dynamic> first, Map<String, dynamic> second) {
  final date = _dayKey(
    first['itinerary_date'],
  ).compareTo(_dayKey(second['itinerary_date']));
  if (date != 0) return date;
  final order = _int(
    first['order_index'] ?? 1,
  ).compareTo(_int(second['order_index'] ?? 1));
  if (order != 0) return order;
  return _time(first['start_time']).compareTo(_time(second['start_time']));
}
