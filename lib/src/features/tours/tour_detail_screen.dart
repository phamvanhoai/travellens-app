import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../design/app_colors.dart';
import '../../design/app_widgets.dart';
import '../auth/auth_controller.dart';

class TourDetailScreen extends ConsumerStatefulWidget {
  const TourDetailScreen({super.key, required this.id});
  final int id;

  @override
  ConsumerState<TourDetailScreen> createState() => _TourDetailScreenState();
}

class _TourDetailScreenState extends ConsumerState<TourDetailScreen>
    with SingleTickerProviderStateMixin {
  static const _labels = [
    'Tổng quan',
    'Nổi bật',
    'Lịch trình',
    'Bao gồm',
    'Chính sách',
    'Hình ảnh',
    'Đánh giá',
  ];
  late final TabController _tabs;
  Map<String, dynamic>? _tour;
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true, _saved = false, _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _labels.length, vsync: this)
      ..addListener(() => setState(() {}));
    _load();
  }

  @override
  void didUpdateWidget(covariant TourDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _tabs.index = 0;
      _load();
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(dioProvider).get('/tours/${widget.id}');
      dynamic data = unwrap(response.data);
      if (data is Map && data['tour'] is Map) data = data['tour'];
      final tour = Map<String, dynamic>.from(data as Map);
      List<Map<String, dynamic>> reviews = [];
      try {
        final r = await ref
            .read(dioProvider)
            .get(
              '/tours/${widget.id}/reviews',
              queryParameters: {'page': 1, 'limit': 100},
            );
        reviews = unwrapList(r.data, ['reviews']);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _tour = tour;
        _reviews = reviews;
      });
      _loadSaved();
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSaved() async {
    if (!ref.read(authProvider).authenticated) return;
    try {
      final r = await ref.read(dioProvider).get('/saved/ids');
      final ids = _findIds(unwrap(r.data));
      if (mounted) setState(() => _saved = ids.contains(widget.id));
    } catch (_) {}
  }

  Future<void> _toggleSaved() async {
    if (!ref.read(authProvider).authenticated) {
      context.push('/login');
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(dioProvider).post('/saved/tours/${widget.id}/toggle');
      if (mounted) setState(() => _saved = !_saved);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null || _tour == null)
      return Scaffold(
        appBar: AppBar(),
        body: AppErrorState(
          error: _error ?? 'Không tìm thấy tour.',
          onRetry: _load,
        ),
      );
    final t = _tour!;
    final name = _text(t, ['name', 'title'], 'Tour du lịch');
    final image = AppConfig.assetUrl(
      _text(t, ['thumbnail', 'thumbnail_url', 'image_url', 'image'], ''),
    );
    final price = _number(t['price']);
    final rating = _number(t['average_rating'] ?? t['rating']);
    final count = _int(t['review_count'] ?? t['reviews_count']);
    final places = _records(
      t['destinations'] ?? t['travel_destinations'] ?? t['tour_destinations'],
    );

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: _CircleButton(
            icon: Icons.arrow_back_rounded,
            onTap: () =>
                context.canPop() ? context.pop() : context.go('/tours'),
          ),
        ),
        actions: [
          _CircleButton(
            icon: Icons.share_outlined,
            onTap: () async {
              await Clipboard.setData(
                ClipboardData(
                  text:
                      'https://travellens-gamma.vercel.app/tours/${widget.id}',
                ),
              );
              if (context.mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép liên kết tour.')),
                );
            },
          ),
          const SizedBox(width: 8),
          _CircleButton(
            icon: _saved
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: _saved ? Colors.red : null,
            onTap: _toggleSaved,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 272,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (image.isEmpty)
                    Container(
                      color: const Color(0xffe8eef5),
                      child: const Icon(
                        Icons.landscape_rounded,
                        size: 54,
                        color: Colors.white,
                      ),
                    )
                  else
                    CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xffe8eef5),
                        child: const Icon(Icons.landscape_rounded, size: 54),
                      ),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x55000000),
                          Colors.transparent,
                          Color(0x44000000),
                        ],
                      ),
                    ),
                  ),
                  if (_text(t, ['video_url'], '').isNotEmpty)
                    const Center(
                      child: CircleAvatar(
                        radius: 27,
                        backgroundColor: Color(0xddffffff),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 34,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                  Positioned(
                    right: 14,
                    bottom: 14,
                    child: _Badge(
                      icon: Icons.photo_library_outlined,
                      text: '${_gallery(t).length.clamp(1, 99)}',
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 23,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      color: Color(0xff17202a),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: AppColors.brand,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          places.isEmpty
                              ? _text(t, ['meeting_point'], 'Việt Nam')
                              : places
                                    .map((e) => _text(e, ['name', 'title'], ''))
                                    .where((e) => e.isNotEmpty)
                                    .join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xff64748b)),
                        ),
                      ),
                      if (rating > 0) ...[
                        const Icon(
                          Icons.star_rounded,
                          size: 18,
                          color: Color(0xffffb020),
                        ),
                        Text(
                          ' ${rating.toStringAsFixed(1)} ($count)',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xfff6f8fb),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        _Fact(
                          icon: Icons.schedule_rounded,
                          title: _duration(t),
                          subtitle: 'Thời lượng',
                        ),
                        _Fact(
                          icon: Icons.calendar_month_outlined,
                          title: _text(t, ['schedule'], 'Hằng ngày'),
                          subtitle: 'Khởi hành',
                        ),
                        _Fact(
                          icon: Icons.groups_outlined,
                          title:
                              '${_int(t['available_slots'] ?? t['capacity'])} chỗ',
                          subtitle: 'Còn trống',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Giá từ',
                    style: TextStyle(fontSize: 12, color: Color(0xff64748b)),
                  ),
                  Text(
                    '${NumberFormat('#,###', 'vi_VN').format(price)}đ / người',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brand,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(pinned: true, delegate: _TabsDelegate(_tabs)),
          SliverToBoxAdapter(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Padding(
                key: ValueKey(_tabs.index),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
                child: _tabBody(t, places),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xffe9edf2))),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: OutlinedButton(
                  onPressed: _toggleSaved,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Icon(
                    _saved
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: _saved ? Colors.red : AppColors.brand,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: () =>
                        context.push('/booking?tourId=${widget.id}'),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Đặt ngay',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
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

  Widget _tabBody(Map<String, dynamic> t, List<Map<String, dynamic>> places) {
    switch (_tabs.index) {
      case 1:
        return _Sections([
          ('Điểm nổi bật', _lines(t['highlights'])),
          ('Yêu cầu', _lines(t['requirements'])),
        ]);
      case 2:
        return places.isEmpty
            ? const _Empty('Lịch trình đang được cập nhật.')
            : Column(
                children: [
                  for (var i = 0; i < places.length; i++)
                    _Place(index: i + 1, data: places[i]),
                ],
              );
      case 3:
        return _Sections([
          ('Bao gồm', _lines(t['inclusions'] ?? t['included'])),
          ('Không bao gồm', _lines(t['exclusions'] ?? t['excluded'])),
        ]);
      case 4:
        return _Sections([
          ('Chính sách hủy', _lines(t['cancellation_policy'])),
          ('Chính sách đặt tour', _lines(t['booking_policy'])),
          ('Thông tin thêm', _lines(t['additional_information'])),
        ]);
      case 5:
        final images = _gallery(t);
        return images.isEmpty
            ? const _Empty('Hình ảnh đang được cập nhật.')
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: images.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 9,
                  mainAxisSpacing: 9,
                  childAspectRatio: 1.25,
                ),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: AppConfig.assetUrl(images[i]),
                    fit: BoxFit.cover,
                  ),
                ),
              );
      case 6:
        return _reviews.isEmpty
            ? const _Empty('Chưa có đánh giá nào.')
            : Column(children: _reviews.map((r) => _Review(data: r)).toList());
      default:
        return _Sections([
          (
            'Giới thiệu tour',
            _lines(t['description'] ?? t['short_description']),
          ),
          ('Điểm đón', _lines(t['meeting_point'] ?? t['pickup_description'])),
          ('Ngôn ngữ', _lines(t['languages'])),
        ]);
    }
  }
}

class _TabsDelegate extends SliverPersistentHeaderDelegate {
  _TabsDelegate(this.controller);
  final TabController controller;
  @override
  double get minExtent => 58;
  @override
  double get maxExtent => 58;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    child: TabBar(
      controller: controller,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      dividerColor: Colors.transparent,
      labelColor: Colors.white,
      unselectedLabelColor: const Color(0xff64748b),
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(20),
      ),
      tabs: _TourDetailScreenState._labels
          .map((e) => Tab(height: 38, text: e))
          .toList(),
    ),
  );
  @override
  bool shouldRebuild(covariant _TabsDelegate oldDelegate) => false;
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap, this.color});
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 38,
    height: 38,
    child: Material(
      color: const Color(0xeef7f9fc),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Icon(icon, size: 21, color: color ?? const Color(0xff17202a)),
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xbb000000),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    ),
  );
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Icon(icon, size: 21, color: AppColors.brand),
        const SizedBox(height: 5),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 10, color: Color(0xff8492a6)),
        ),
      ],
    ),
  );
}

class _Sections extends StatelessWidget {
  const _Sections(this.sections);
  final List<(String, List<String>)> sections;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final s in sections)
        if (s.$2.isNotEmpty) ...[
          Text(
            s.$1,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ...s.$2.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: AppColors.brand,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e,
                      style: const TextStyle(
                        height: 1.5,
                        color: Color(0xff475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
    ],
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 30),
    child: Center(
      child: Text(text, style: const TextStyle(color: Color(0xff64748b))),
    ),
  );
}

class _Place extends StatelessWidget {
  const _Place({required this.index, required this.data});
  final int index;
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xffe6ebf1)),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: AppColors.brand,
          child: Text(
            '$index',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _text(data, ['name', 'title'], 'Điểm tham quan'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (_text(data, ['description'], '').isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  _text(data, ['description'], ''),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Color(0xff64748b),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _Review extends StatelessWidget {
  const _Review({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final user = data['user'] is Map
        ? Map<String, dynamic>.from(data['user'])
        : data;
    final rating = _int(data['rating']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xfff7f9fc),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 17,
                child: Icon(Icons.person, size: 18),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _text(user, ['full_name', 'name'], 'Du khách'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ...List.generate(
                5,
                (i) => Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: i < rating
                      ? const Color(0xffffb020)
                      : const Color(0xffd9dee5),
                ),
              ),
            ],
          ),
          if (_text(data, ['comment', 'content'], '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Text(
                _text(data, ['comment', 'content'], ''),
                style: const TextStyle(height: 1.45, color: Color(0xff475569)),
              ),
            ),
        ],
      ),
    );
  }
}

String _text(Map data, List<String> keys, String fallback) {
  for (final key in keys) {
    final v = data[key];
    if (v != null && '$v'.trim().isNotEmpty && v is! Map && v is! List)
      return '$v'.trim();
  }
  return fallback;
}

double _number(dynamic v) => double.tryParse('${v ?? 0}') ?? 0;
int _int(dynamic v) => int.tryParse('${v ?? 0}') ?? _number(v).round();
List<Map<String, dynamic>> _records(dynamic v) {
  if (v is Map && v['data'] != null) v = v['data'];
  if (v is! List) return [];
  return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

List<String> _lines(dynamic v) {
  if (v == null) return [];
  if (v is List)
    return v
        .map(
          (e) =>
              e is Map ? _text(e, ['name', 'title', 'description'], '') : '$e',
        )
        .where((e) => e.trim().isNotEmpty)
        .toList();
  return '$v'
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .split(RegExp(r'\r?\n|•|;'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

List<String> _gallery(Map<String, dynamic> t) {
  final values = <dynamic>[t['thumbnail'], t['thumbnail_url'], t['image_url']];
  final raw = t['gallery'] ?? t['images'];
  if (raw is List) values.addAll(raw);
  return values
      .map(
        (e) => e is Map
            ? _text(e, ['url', 'image_url', 'path'], '')
            : '${e ?? ''}',
      )
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();
}

String _duration(Map<String, dynamic> t) {
  final d = _int(t['duration_days']), n = _int(t['duration_nights']);
  if (d > 0) return n > 0 ? '$d ngày $n đêm' : '$d ngày';
  return _text(t, ['duration'], 'Trong ngày');
}

Set<int> _findIds(dynamic data) {
  final result = <int>{};
  void walk(dynamic v) {
    if (v is List) {
      for (final x in v) {
        if (x is num || x is String) {
          final id = int.tryParse('$x');
          if (id != null) result.add(id);
        } else {
          walk(x);
        }
      }
    } else if (v is Map) {
      for (final key in ['tour_ids', 'tours', 'saved_tours']) {
        if (v[key] != null) walk(v[key]);
      }
      final id = int.tryParse('${v['tour_id'] ?? v['id'] ?? ''}');
      if (id != null) result.add(id);
    }
  }

  walk(data);
  return result;
}
