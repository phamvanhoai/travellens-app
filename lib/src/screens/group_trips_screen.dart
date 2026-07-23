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

class GroupTripsScreen extends ConsumerStatefulWidget {
  const GroupTripsScreen({super.key});

  @override
  ConsumerState<GroupTripsScreen> createState() => _GroupTripsScreenState();
}

class _GroupTripsScreenState extends ConsumerState<GroupTripsScreen> {
  static const _pageSize = 12;
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  bool _publicView = true;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
            _publicView ? '/group-trips/public' : '/group-trips',
            queryParameters: {
              'page': _page,
              'limit': _pageSize,
              if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
            },
          );
      final result = _parseTrips(response.data);
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

  void _submitSearch() {
    setState(() => _page = 1);
    _load();
  }

  void _changeView(bool publicView) {
    if (_publicView == publicView) return;
    setState(() {
      _publicView = publicView;
      _page = 1;
      _items = [];
    });
    _load();
  }

  void _changePage(int page) {
    if (page < 1 || page > _totalPages || page == _page) return;
    setState(() => _page = page);
    _load();
  }

  Future<void> _openCreate() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateGroupTripSheet(),
    );
    if (created == true) {
      _publicView = false;
      _page = 1;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    appBar: AppBar(
      title: const Text('Chuyến đi nhóm'),
      actions: [
        IconButton(
          tooltip: 'Lời mời',
          onPressed: () => context.push('/invitations'),
          icon: const Icon(Icons.mark_email_unread_outlined, size: 20),
        ),
        const SizedBox(width: 6),
      ],
    ),
    floatingActionButton: FloatingActionButton.small(
      onPressed: _openCreate,
      child: const Icon(Icons.add_rounded),
    ),
    body: RefreshIndicator(
      color: AppColors.brand,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PublicTripsHero(
                    search: _search,
                    onChanged: () => setState(() {}),
                    onSearch: _submitSearch,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                    child: _GroupTripViewSwitch(
                      publicView: _publicView,
                      onChanged: _changeView,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 14,
                                    color: AppColors.brand,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'HÀNH TRÌNH CỘNG ĐỒNG',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.1,
                                      color: AppColors.brand,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6),
                              Text(
                                _publicView
                                    ? 'Public Group Trips'
                                    : 'Chuyến đi của tôi',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _publicView
                                    ? 'Khám phá các chuyến đi mở cùng cộng đồng Travel360.'
                                    : 'Quản lý những chuyến đi bạn tạo hoặc đang tham gia.',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _TotalBadge(
                          loading: _loading,
                          total: _total,
                          publicView: _publicView,
                        ),
                      ],
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
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (_, _) => const _GroupTripSkeleton(),
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
                icon: Icons.groups_outlined,
                title: _publicView
                    ? 'Chưa có chuyến đi công khai'
                    : 'Bạn chưa có chuyến đi nhóm',
                subtitle: _search.text.trim().isEmpty
                    ? _publicView
                          ? 'Hiện chưa có hành trình cộng đồng nào để khám phá.'
                          : 'Tạo chuyến đi đầu tiên và mời bạn bè tham gia.'
                    : 'Không tìm thấy chuyến đi phù hợp.',
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              sliver: SliverList.separated(
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) => _GroupTripCard(
                  item: _items[index],
                  publicView: _publicView,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 110),
                child: _GroupTripPagination(
                  page: _page,
                  totalPages: _totalPages,
                  total: _total,
                  onPageChanged: _changePage,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _PublicTripsHero extends StatelessWidget {
  const _PublicTripsHero({
    required this.search,
    required this.onChanged,
    required this.onSearch,
  });

  final TextEditingController search;
  final VoidCallback onChanged;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 270),
    padding: const EdgeInsets.fromLTRB(18, 30, 18, 22),
    decoration: const BoxDecoration(
      image: DecorationImage(
        image: CachedNetworkImageProvider(
          'https://images.unsplash.com/photo-1528702748617-c64d49f918af?auto=format&fit=crop&w=1000&q=80',
        ),
        fit: BoxFit.cover,
        colorFilter: ColorFilter.mode(Color(0xAA071D33), BlendMode.darken),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TRẢI NGHIỆM TỐT HƠN KHI CÓ NHAU',
          style: TextStyle(
            color: Color(0xFF67E8F9),
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Travel Better,\nTogether',
          style: TextStyle(
            color: Colors.white,
            fontSize: 27,
            height: 1.08,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Khám phá hành trình cộng đồng, gặp gỡ bạn đồng hành và cùng tạo nên những kỷ niệm đáng nhớ.',
          style: TextStyle(color: Colors.white70, fontSize: 10.5, height: 1.4),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 16),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.search_rounded,
                  size: 19,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: TextField(
                  controller: search,
                  onChanged: (_) => onChanged(),
                  onSubmitted: (_) => onSearch(),
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Tìm chuyến đi hoặc điểm đến...',
                    hintStyle: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    suffixIcon: search.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              search.clear();
                              onSearch();
                            },
                            icon: const Icon(Icons.close_rounded, size: 17),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              SizedBox(
                height: 40,
                child: FilledButton(
                  onPressed: onSearch,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Text(
                    'Khám phá',
                    style: TextStyle(fontSize: 9.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TotalBadge extends StatelessWidget {
  const _TotalBadge({
    required this.loading,
    required this.total,
    required this.publicView,
  });

  final bool loading;
  final int total;
  final bool publicView;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: AppColors.border),
    ),
    child: Text(
      loading
          ? 'Đang tải...'
          : publicView
          ? '$total công khai'
          : '$total của tôi',
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        color: AppColors.muted,
      ),
    ),
  );
}

class _GroupTripViewSwitch extends StatelessWidget {
  const _GroupTripViewSwitch({
    required this.publicView,
    required this.onChanged,
  });

  final bool publicView;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 46,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AppColors.borderLight,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Expanded(
          child: _GroupTripViewOption(
            label: 'Công khai',
            icon: Icons.public_rounded,
            selected: publicView,
            onTap: () => onChanged(true),
          ),
        ),
        Expanded(
          child: _GroupTripViewOption(
            label: 'Của tôi',
            icon: Icons.person_outline_rounded,
            selected: !publicView,
            onTap: () => onChanged(false),
          ),
        ),
      ],
    ),
  );
}

class _GroupTripViewOption extends StatelessWidget {
  const _GroupTripViewOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? Colors.white : Colors.transparent,
    borderRadius: BorderRadius.circular(11),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: selected ? AppColors.brand : AppColors.muted,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: selected ? AppColors.brand : AppColors.muted,
            ),
          ),
        ],
      ),
    ),
  );
}

class _GroupTripCard extends StatelessWidget {
  const _GroupTripCard({required this.item, required this.publicView});
  final Map<String, dynamic> item;
  final bool publicView;

  @override
  Widget build(BuildContext context) {
    final id = _tripId(item);
    final name = '${item['name'] ?? 'Chuyến đi cộng đồng'}';
    final destination = '${item['destination_name'] ?? 'Điểm đến linh hoạt'}';
    final description =
        '${item['description'] ?? 'Một chuyến đi cộng đồng đang chờ những người bạn đồng hành và kỷ niệm mới.'}';
    final leaderRaw = item['leader'];
    final leader = leaderRaw is Map
        ? '${leaderRaw['name'] ?? 'Thành viên Travel360'}'
        : '${item['leader_name'] ?? 'Thành viên Travel360'}';
    final avatar = AppConfig.assetUrl(
      '${leaderRaw is Map ? leaderRaw['avatar_url'] ?? '' : item['leader_avatar_url'] ?? ''}',
    );
    final members = _integer(item['member_count']);
    final maximum = _integer(item['max_members']);
    final progress = maximum > 0
        ? (members / maximum).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return InkWell(
      onTap: id > 0 ? () => context.push('/group-trips/$id') : null,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 112),
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1D4ED8),
                    Color(0xFF2563EB),
                    Color(0xFF06B6D4),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _VisibilityBadge(
                        visibility: publicView
                            ? 'public'
                            : '${item['visibility'] ?? 'private'}',
                      ),
                      const Spacer(),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0x26FFFFFF),
                        ),
                        child: const Icon(
                          Icons.arrow_outward_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _TripInfo(
                          icon: Icons.location_on_outlined,
                          label: 'ĐIỂM ĐẾN',
                          value: destination,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TripInfo(
                          icon: Icons.calendar_month_outlined,
                          label: 'THỜI GIAN',
                          value: _dateRange(
                            item['start_date'],
                            item['end_date'],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 17),
                  Row(
                    children: [
                      _LeaderAvatar(name: leader, image: avatar),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: AppColors.muted,
                            ),
                            children: [
                              const TextSpan(text: 'Dẫn đoàn bởi '),
                              TextSpan(
                                text: leader,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.dark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.groups_outlined,
                        size: 14,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        maximum > 0 ? '$members/$maximum' : '$members',
                        style: const TextStyle(
                          color: AppColors.dark,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  if (maximum > 0) ...[
                    const SizedBox(height: 11),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: AppColors.borderLight,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.brand,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripInfo extends StatelessWidget {
  const _TripInfo({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 58),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: AppColors.brand),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 8,
                  letterSpacing: .5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.subtle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _LeaderAvatar extends StatelessWidget {
  const _LeaderAvatar({required this.name, required this.image});

  final String name;
  final String image;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 17,
    backgroundColor: AppColors.accentLight,
    backgroundImage: image.isEmpty ? null : CachedNetworkImageProvider(image),
    child: image.isNotEmpty
        ? null
        : Text(
            _initials(name),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: AppColors.brand,
            ),
          ),
  );
}

class _VisibilityBadge extends StatelessWidget {
  const _VisibilityBadge({required this.visibility});
  final String visibility;

  @override
  Widget build(BuildContext context) {
    final public = visibility.toLowerCase() == 'public';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            public ? Icons.public_rounded : Icons.lock_outline_rounded,
            size: 9,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            public ? 'Công khai' : 'Riêng tư',
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
}

class _CreateGroupTripSheet extends ConsumerStatefulWidget {
  const _CreateGroupTripSheet();

  @override
  ConsumerState<_CreateGroupTripSheet> createState() =>
      _CreateGroupTripSheetState();
}

class _CreateGroupTripSheetState extends ConsumerState<_CreateGroupTripSheet> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _maxMembers = TextEditingController(text: '6');
  List<Map<String, dynamic>> _destinations = [];
  int? _destinationId;
  bool _loadingDestinations = true;
  DateTime? _startDate, _endDate;
  bool _public = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadDestinations();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _maxMembers.dispose();
    super.dispose();
  }

  Future<void> _loadDestinations() async {
    try {
      final response = await ref
          .read(dioProvider)
          .get(
            '/travel-destinations',
            queryParameters: {'page': 1, 'limit': 100},
          );
      final values = unwrapList(response.data, [
        'destinations',
        'travel_destinations',
      ]);
      final unique = <int, Map<String, dynamic>>{};
      for (final item in values) {
        final id = _destinationItemId(item);
        if (id > 0) unique[id] = item;
      }
      if (!mounted) return;
      setState(() => _destinations = unique.values.toList());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tải địa điểm: ${apiError(error)}')),
      );
    } finally {
      if (mounted) setState(() => _loadingDestinations = false);
    }
  }

  Future<void> _pickDate(bool start) async {
    final value = await showDatePicker(
      context: context,
      initialDate: start
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? _startDate ?? DateTime.now()),
      firstDate: start ? DateTime.now() : (_startDate ?? DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (value == null) return;
    setState(() {
      if (start) {
        _startDate = value;
        if (_endDate != null && _endDate!.isBefore(value)) _endDate = value;
      } else {
        _endDate = value;
      }
    });
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty ||
        _destinationId == null ||
        _startDate == null ||
        _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tên, địa điểm và ngày chuyến đi.'),
        ),
      );
      return;
    }
    final destination = _destinations.firstWhere(
      (item) => _destinationItemId(item) == _destinationId,
    );
    setState(() => _saving = true);
    try {
      final formatter = DateFormat('yyyy-MM-dd');
      await ref
          .read(dioProvider)
          .post(
            '/group-trips',
            data: {
              'name': name,
              'description': _description.text.trim(),
              'destination_id': _destinationId,
              'destination_name': _destinationItemName(destination),
              'start_date': formatter.format(_startDate!),
              'end_date': formatter.format(_endDate!),
              'max_members': int.tryParse(_maxMembers.text.trim()) ?? 6,
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
        12,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Tạo chuyến đi nhóm',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Tên chuyến đi *'),
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
            initialValue: _destinationId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Địa điểm *',
              prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
              suffixIcon: _loadingDestinations
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox.square(
                        dimension: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            hint: Text(
              _loadingDestinations ? 'Đang tải địa điểm...' : 'Chọn địa điểm',
              style: const TextStyle(fontSize: 10.5),
            ),
            items: _destinations
                .map(
                  (item) => DropdownMenuItem<int>(
                    value: _destinationItemId(item),
                    child: Text(
                      _destinationItemName(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5),
                    ),
                  ),
                )
                .toList(),
            onChanged: _loadingDestinations
                ? null
                : (value) => setState(() => _destinationId = value),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Ngày bắt đầu',
                  value: _startDate,
                  onTap: () => _pickDate(true),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _DateField(
                  label: 'Ngày kết thúc',
                  value: _endDate,
                  onTap: () => _pickDate(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _maxMembers,
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
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Người khác có thể tìm và xem chuyến đi.',
              style: TextStyle(fontSize: 9.5),
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Tạo chuyến đi'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_month_outlined, size: 17),
      ),
      child: Text(
        value == null ? 'Chọn ngày' : DateFormat('dd/MM/yyyy').format(value!),
        style: const TextStyle(fontSize: 10.5),
      ),
    ),
  );
}

class _GroupTripSkeleton extends StatelessWidget {
  const _GroupTripSkeleton();

  @override
  Widget build(BuildContext context) => const AppShimmerBox(
    width: double.infinity,
    height: 304,
    borderRadius: 18,
  );
}

class _GroupTripPagination extends StatelessWidget {
  const _GroupTripPagination({
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
          '$total chuyến đi · Trang $page/$totalPages',
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

({List<Map<String, dynamic>> items, int totalPages, int total}) _parseTrips(
  dynamic body,
) {
  final items = unwrapList(body, ['group_trips']);
  final root = body is Map ? body : const {};
  final data = root['data'] is Map ? root['data'] as Map : root;
  final pagination = data['pagination'] is Map
      ? data['pagination'] as Map
      : root['pagination'] is Map
      ? root['pagination'] as Map
      : const {};
  final total =
      int.tryParse('${pagination['total'] ?? items.length}') ?? items.length;
  final totalPages =
      int.tryParse(
        '${pagination['totalPages'] ?? pagination['total_pages'] ?? 1}',
      ) ??
      1;
  return (items: items, totalPages: totalPages, total: total);
}

int _tripId(Map item) =>
    int.tryParse('${item['group_trip_id'] ?? item['id'] ?? 0}') ?? 0;
int _integer(dynamic value) => int.tryParse('${value ?? 0}') ?? 0;
int _destinationItemId(Map item) =>
    int.tryParse(
      '${item['travel_destination_id'] ?? item['destination_id'] ?? item['id'] ?? 0}',
    ) ??
    0;
String _destinationItemName(Map item) =>
    '${item['name'] ?? item['title'] ?? 'Địa điểm #${_destinationItemId(item)}'}';

String _initials(String name) {
  final words = name.trim().split(RegExp(r'\s+'));
  return words
      .where((word) => word.isNotEmpty)
      .toList()
      .reversed
      .take(2)
      .toList()
      .reversed
      .map((word) => word[0].toUpperCase())
      .join();
}

String _dateRange(dynamic start, dynamic end) {
  final startDate = DateTime.tryParse('${start ?? ''}')?.toLocal();
  final endDate = DateTime.tryParse('${end ?? ''}')?.toLocal();
  if (startDate == null) return 'Ngày đang cập nhật';
  final formatter = DateFormat('dd/MM/yyyy');
  return endDate == null
      ? formatter.format(startDate)
      : '${formatter.format(startDate)} – ${formatter.format(endDate)}';
}
