import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../design/app_colors.dart';
import '../../design/app_text_styles.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _request = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _history = [];
  bool _loading = false;
  bool _showResults = false;
  String? _error;

  static const _suggestions = <(String, String)>[
    (
      'Biển cho gia đình',
      'Tôi muốn đi du lịch biển cùng gia đình 4 người, ngân sách khoảng 5 triệu đồng mỗi người.',
    ),
    (
      'Khám phá cùng bạn bè',
      'Nhóm bạn 6 người muốn khám phá thiên nhiên và trải nghiệm ngoài trời, ngân sách khoảng 4 triệu đồng mỗi người.',
    ),
    (
      'Văn hóa cho cặp đôi',
      'Cặp đôi 2 người muốn khám phá văn hóa, ẩm thực và các địa điểm lãng mạn, ngân sách khoảng 7 triệu đồng mỗi người.',
    ),
    (
      'Tiết kiệm cho sinh viên',
      'Nhóm sinh viên 5 người muốn du lịch nghỉ dưỡng kết hợp tham quan, ngân sách tối đa 3 triệu đồng mỗi người.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _request.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final response = await ref.read(dioProvider).get('/ai/history');
      final items = unwrapList(response.data, const ['history', 'rows']);
      if (mounted) setState(() => _history = items);
    } catch (_) {}
  }

  Future<void> _search() async {
    final value = _request.text.trim();
    if (value.isEmpty || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref
          .read(dioProvider)
          .post(
            '/ai/search',
            data: {'travel_request': value},
            options: Options(
              sendTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(minutes: 2),
            ),
          );
      final body = response.data;
      final success = body is! Map || body['success'] != false;
      if (!success) {
        final missing = body['missing_fields'] is List
            ? (body['missing_fields'] as List).map(_fieldName).join(', ')
            : '';
        throw StateError(
          'Hãy mô tả chi tiết hơn${missing.isEmpty ? '' : '. AI chưa nhận diện được: $missing'}.',
        );
      }
      final results = unwrapList(body, const ['recommendations', 'results']);
      if (!mounted) return;
      setState(() {
        _results = results;
        _showResults = true;
      });
      await _loadHistory();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          490,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeOutCubic,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is StateError ? e.message.toString() : apiError(e);
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _reset() {
    _request.clear();
    setState(() {
      _results = [];
      _showResults = false;
      _error = null;
    });
  }

  Future<void> _openHistory() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .72,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Lịch sử gần đây', style: AppTextStyles.h4),
                          Text(
                            'Chọn để xem lại kết quả',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: _history.isEmpty
                    ? const Center(
                        child: Text(
                          'Chưa có lịch sử tìm kiếm.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                        itemCount: _history.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (_, index) {
                          final item = _history[index];
                          final recommendations = item['recommendations'];
                          final count = recommendations is List
                              ? recommendations.length
                              : 0;
                          return ListTile(
                            minVerticalPadding: 12,
                            title: Text(
                              '“${item['travel_request'] ?? ''}”',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '${_date(item['created_at'])} · $count kết quả',
                                style: AppTextStyles.caption,
                              ),
                            ),
                            trailing: IconButton(
                              onPressed: () => _deleteHistory(
                                sheetContext,
                                _integer(item['id']),
                              ),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: AppColors.subtle,
                                size: 20,
                              ),
                            ),
                            onTap: () {
                              _request.text = '${item['travel_request'] ?? ''}';
                              setState(() {
                                _results = recommendations is List
                                    ? recommendations
                                          .whereType<Map>()
                                          .map(
                                            (e) => Map<String, dynamic>.from(e),
                                          )
                                          .toList()
                                    : [];
                                _showResults = true;
                                _error = null;
                              });
                              Navigator.pop(sheetContext);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteHistory(BuildContext sheetContext, int id) async {
    if (id <= 0) return;
    try {
      await ref.read(dioProvider).delete('/ai/history/$id');
      if (!mounted) return;
      setState(
        () => _history.removeWhere((item) => _integer(item['id']) == id),
      );
      if (sheetContext.mounted) Navigator.pop(sheetContext);
      await _openHistory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8FAFC),
    appBar: AppBar(
      title: const Text('Trợ lý du lịch AI'),
      actions: [
        IconButton(
          tooltip: 'Lịch sử',
          onPressed: _openHistory,
          icon: Badge(
            isLabelVisible: _history.isNotEmpty,
            label: Text('${_history.length}'),
            child: const Icon(Icons.history_rounded),
          ),
        ),
        const SizedBox(width: 6),
      ],
    ),
    body: CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverToBoxAdapter(child: _buildHero()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          sliver: SliverToBoxAdapter(child: _buildHeading()),
        ),
        if (_error != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            sliver: SliverToBoxAdapter(child: _ErrorBanner(_error!)),
          ),
        if (!_showResults)
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 28),
            sliver: SliverToBoxAdapter(child: _DiscoveryEmpty()),
          )
        else if (_results.isEmpty)
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 28),
            sliver: SliverToBoxAdapter(
              child: _DiscoveryEmpty(emptyResults: true),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            sliver: SliverList.separated(
              itemCount: _results.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (_, index) => _RecommendationCard(
                item: _results[index],
                index: index,
                onTap: () => _openResult(_results[index]),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _buildHero() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF172554), Color(0xFF1D4ED8), Color(0xFF0EA5E9)],
      ),
    ),
    padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFFBFDBFE),
              size: 18,
            ),
            SizedBox(width: 7),
            Text(
              'TRỢ LÝ DU LỊCH THÔNG MINH',
              style: TextStyle(
                color: Color(0xFFDBEAFE),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Mô tả chuyến đi\ntrong mơ của bạn',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            height: 1.12,
            fontWeight: FontWeight.w900,
            letterSpacing: -.7,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'AI sẽ tìm những điểm đến phù hợp nhất với sở thích và ngân sách của bạn.',
          style: TextStyle(color: Color(0xFFDBEAFE), fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              TextField(
                controller: _request,
                minLines: 3,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.fromLTRB(8, 6, 8, 8),
                  hintText:
                      'Ví dụ: Tôi muốn đi biển cùng gia đình 4 người, ngân sách khoảng 5 triệu mỗi người...',
                  hintStyle: TextStyle(fontSize: 13, height: 1.45),
                ),
              ),
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 7),
                  itemBuilder: (_, index) => ActionChip(
                    avatar: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 13,
                      color: AppColors.brand,
                    ),
                    label: Text(_suggestions[index].$1),
                    labelStyle: const TextStyle(
                      color: AppColors.brandDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    backgroundColor: AppColors.accentLight,
                    side: const BorderSide(color: Color(0xFFDBEAFE)),
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    onPressed: () {
                      _request.text = _suggestions[index].$2;
                      setState(() => _error = null);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _loading || _request.text.trim().isEmpty
                      ? null
                      : _search,
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: Text(_loading ? 'AI đang phân tích...' : 'Tạo gợi ý'),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildHeading() => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'KHÁM PHÁ DÀNH RIÊNG CHO BẠN',
              style: TextStyle(
                color: AppColors.brand,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.35,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _showResults
                  ? 'Điểm đến dành cho bạn'
                  : 'Bắt đầu hành trình của bạn',
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: 3),
            Text(
              _showResults
                  ? '${_results.length} gợi ý dựa trên yêu cầu của bạn.'
                  : 'Càng mô tả chi tiết, kết quả càng phù hợp.',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
      if (_showResults)
        OutlinedButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Làm mới'),
        ),
    ],
  );

  void _openResult(Map<String, dynamic> item) {
    final id = _integer(item['destination_id'] ?? item['id']);
    if (id > 0) context.push('/destinations/$id');
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.item,
    required this.index,
    required this.onTap,
  });

  final Map<String, dynamic> item;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = AppConfig.assetUrl(
      '${item['thumbnail'] ?? item['thumbnail_url'] ?? item['image_url'] ?? ''}',
    );
    final score = ((double.tryParse('${item['score'] ?? 0}') ?? 0) * 100)
        .round();
    final price =
        double.tryParse(
          '${item['starting_price'] ?? item['price_from'] ?? 0}',
        ) ??
        0;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 390,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D0F172A),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 190,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (image.isEmpty)
                      const ColoredBox(
                        color: AppColors.borderLight,
                        child: Icon(
                          Icons.landscape_outlined,
                          size: 44,
                          color: AppColors.subtle,
                        ),
                      )
                    else
                      _AiResultImage(
                        url: image,
                        cacheId:
                            '${item['destination_id'] ?? item['id'] ?? index}',
                      ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xD9000000)],
                          stops: [.42, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: _CardBadge(label: '${index + 1}', square: true),
                    ),
                    if (score > 0)
                      Positioned(
                        right: 12,
                        top: 12,
                        child: _CardBadge(
                          label: '$score% phù hợp',
                          color: AppColors.success,
                        ),
                      ),
                    Positioned(
                      left: 15,
                      right: 15,
                      bottom: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item['name'] ?? 'Điểm đến'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 7),
                          _CardBadge(
                            label:
                                '${item['suggested_tour_type'] ?? 'Khám phá'}',
                            translucent: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _plainText(
                          '${item['description'] ?? 'Điểm đến tuyệt vời để bạn trải nghiệm và khám phá.'}',
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall,
                      ),
                      const Spacer(),
                      const Divider(),
                      const SizedBox(height: 11),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'GIÁ THAM KHẢO',
                                  style: TextStyle(
                                    color: AppColors.subtle,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .8,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  price > 0
                                      ? '${_money(price)} đ'
                                      : 'Đang cập nhật',
                                  style: AppTextStyles.label.copyWith(
                                    color: AppColors.brandDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            decoration: BoxDecoration(
                              color: AppColors.accentLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: const Row(
                              children: [
                                Text(
                                  'Chi tiết',
                                  style: TextStyle(
                                    color: AppColors.brandDark,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 5),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: AppColors.brandDark,
                                  size: 16,
                                ),
                              ],
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
        ),
      ),
    );
  }
}

class _AiResultImage extends StatelessWidget {
  const _AiResultImage({required this.url, required this.cacheId});

  final String url;
  final String cacheId;

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final targetWidth = (MediaQuery.sizeOf(context).width * pixelRatio)
        .round()
        .clamp(480, 1200);
    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: 'ai-result-v2-$cacheId-${url.hashCode}',
      fit: BoxFit.cover,
      memCacheWidth: targetWidth,
      maxWidthDiskCache: 1200,
      fadeInDuration: const Duration(milliseconds: 220),
      placeholder: (_, _) => const ColoredBox(
        color: AppColors.borderLight,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (_, _, _) => const ColoredBox(
        color: AppColors.borderLight,
        child: Center(
          child: Icon(
            Icons.landscape_outlined,
            size: 42,
            color: AppColors.subtle,
          ),
        ),
      ),
    );
  }
}

class _CardBadge extends StatelessWidget {
  const _CardBadge({
    required this.label,
    this.color = Colors.white,
    this.square = false,
    this.translucent = false,
  });

  final String label;
  final Color color;
  final bool square;
  final bool translucent;

  @override
  Widget build(BuildContext context) => Container(
    width: square ? 36 : null,
    height: square ? 36 : null,
    padding: square
        ? EdgeInsets.zero
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: translucent ? Colors.white.withValues(alpha: .16) : color,
      borderRadius: BorderRadius.circular(square ? 11 : 20),
      border: translucent ? Border.all(color: Colors.white38) : null,
    ),
    child: Text(
      label,
      maxLines: 1,
      style: TextStyle(
        color: translucent
            ? Colors.white
            : color == Colors.white
            ? AppColors.brandDark
            : Colors.white,
        fontSize: square ? 13 : 10,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.errorSoft,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFFECACA)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: AppColors.error,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: AppTextStyles.bodySmall.copyWith(
              color: const Color(0xFFB91C1C),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DiscoveryEmpty extends StatelessWidget {
  const _DiscoveryEmpty({this.emptyResults = false});
  final bool emptyResults;

  @override
  Widget build(BuildContext context) => Container(
    height: 210,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            emptyResults
                ? Icons.search_off_rounded
                : Icons.travel_explore_rounded,
            color: AppColors.brand,
            size: 27,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          emptyResults
              ? 'Không tìm thấy kết quả phù hợp'
              : 'Sẵn sàng khám phá?',
          style: AppTextStyles.label,
        ),
        const SizedBox(height: 5),
        Text(
          emptyResults
              ? 'Hãy thử thay đổi yêu cầu hoặc ngân sách của bạn.'
              : 'Nhập loại hình, số người và ngân sách để nhận gợi ý chính xác hơn.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall,
        ),
      ],
    ),
  );
}

String _fieldName(Object? value) => switch ('$value') {
  'cust_segment' => 'đối tượng chuyến đi',
  'tour_type' => 'loại hình du lịch',
  'pax' => 'số lượng người',
  'budget_per_person_vnd' => 'ngân sách mỗi người',
  final value => value,
};

String _plainText(String value) => value
    .replaceAll(RegExp(r'<[^>]*>'), ' ')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

int _integer(Object? value) => int.tryParse('$value') ?? 0;

String _money(double value) {
  final digits = value.round().toString();
  return digits.replaceAllMapped(
    RegExp(r'(?<=\d)(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
}

String _date(Object? value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  if (date == null) return '';
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
