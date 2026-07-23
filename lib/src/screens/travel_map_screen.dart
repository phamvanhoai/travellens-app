import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';
import '../core/network/api_client.dart';
import '../design/app_colors.dart';

class TravelMapScreen extends ConsumerStatefulWidget {
  const TravelMapScreen({super.key});

  @override
  ConsumerState<TravelMapScreen> createState() => _TravelMapScreenState();
}

class _TravelMapScreenState extends ConsumerState<TravelMapScreen> {
  final _map = MapController();
  final _search = TextEditingController();
  List<_MapMarker> _markers = [];
  List<Map<String, dynamic>> _categories = [];
  _MapMarker? _selected;
  bool _loading = true;
  bool _locating = false;
  bool? _has360;
  double? _minRating;
  bool _popular = false;
  String? _categoryId;
  double _radius = 5;
  LatLng? _userPosition;
  bool _satellite = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _load();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await ref
          .read(dioProvider)
          .get('/destination-categories');
      dynamic data = response.data;
      if (data is Map && data['data'] != null) data = data['data'];
      if (data is Map) {
        data = data['destination_categories'] ?? data['categories'] ?? data;
      }
      if (!mounted || data is! List) return;
      setState(() {
        _categories = data
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      });
    } catch (_) {
      // Category metadata is optional; the map still works without it.
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _map.dispose();
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
            '/maps/filter',
            queryParameters: {
              if (_search.text.trim().isNotEmpty)
                'keyword': _search.text.trim(),
              if (_categoryId != null) 'destination_category_id': _categoryId,
              if (_has360 != null) 'has_view360': _has360,
              if (_minRating != null) 'min_rating': _minRating,
              if (_popular) 'popular_only': true,
            },
          );
      final markers = _parseMarkers(response.data);
      if (!mounted) return;
      setState(() {
        _markers = markers;
        _selected = markers.isEmpty ? null : markers.first;
      });
      _focusMarkers(markers);
    } catch (error) {
      if (mounted) setState(() => _error = apiError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _nearby() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Vui lòng bật dịch vụ vị trí.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Ứng dụng chưa được cấp quyền vị trí.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      final response = await ref
          .read(dioProvider)
          .get(
            '/maps/nearby',
            queryParameters: {
              'lat': position.latitude,
              'lng': position.longitude,
              'radius': _radius,
            },
          );
      final markers = _parseMarkers(response.data);
      if (!mounted) return;
      setState(() {
        _markers = markers;
        _selected = markers.isEmpty ? null : markers.first;
        _error = null;
        _userPosition = LatLng(position.latitude, position.longitude);
      });
      _map.move(LatLng(position.latitude, position.longitude), 13);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _showFilters() async {
    var categoryId = _categoryId;
    var radius = _radius;
    var has360 = _has360;
    var minRating = _minRating;
    var popular = _popular;
    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bộ lọc bản đồ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  initialValue: categoryId,
                  decoration: const InputDecoration(labelText: 'Danh mục'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Tất cả danh mục'),
                    ),
                    ..._categories.map((item) {
                      final id =
                          '${item['destination_category_id'] ?? item['id'] ?? ''}';
                      return DropdownMenuItem(
                        value: id,
                        child: Text('${item['name'] ?? 'Danh mục'}'),
                      );
                    }),
                  ],
                  onChanged: (value) => setSheetState(() => categoryId = value),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<double>(
                  initialValue: radius,
                  decoration: const InputDecoration(
                    labelText: 'Bán kính tìm quanh đây',
                  ),
                  items: const [2.0, 5.0, 10.0, 25.0, 50.0]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('${value.toInt()} km'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setSheetState(() => radius = value ?? 5),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<double?>(
                  initialValue: minRating,
                  decoration: const InputDecoration(
                    labelText: 'Đánh giá tối thiểu',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: null,
                      child: Text('Mọi mức đánh giá'),
                    ),
                    DropdownMenuItem(value: 3, child: Text('3 sao trở lên')),
                    DropdownMenuItem(value: 4, child: Text('4 sao trở lên')),
                    DropdownMenuItem(
                      value: 4.5,
                      child: Text('4.5 sao trở lên'),
                    ),
                    DropdownMenuItem(value: 5, child: Text('5 sao')),
                  ],
                  onChanged: (value) => setSheetState(() => minRating = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Chỉ địa điểm có View360'),
                  value: has360 == true,
                  onChanged: (value) =>
                      setSheetState(() => has360 = value ? true : null),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Chỉ địa điểm phổ biến'),
                  value: popular,
                  onChanged: (value) => setSheetState(() => popular = value),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Áp dụng bộ lọc'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (apply != true || !mounted) return;
    setState(() {
      _categoryId = categoryId;
      _radius = radius;
      _has360 = has360;
      _minRating = minRating;
      _popular = popular;
    });
    await _load();
  }

  void _focusMarkers(List<_MapMarker> markers) {
    if (markers.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted)
        _map.move(markers.first.position, markers.length == 1 ? 14 : 10);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Bản đồ du lịch'),
      actions: [
        IconButton(
          tooltip: 'Vị trí gần tôi',
          onPressed: _locating ? null : _nearby,
          icon: _locating
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location_rounded, size: 20),
        ),
        IconButton(
          tooltip: 'Làm mới',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded, size: 20),
        ),
        const SizedBox(width: 4),
      ],
    ),
    body: Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _map,
            options: const MapOptions(
              initialCenter: LatLng(10.7769, 106.7009),
              initialZoom: 11,
              minZoom: 3,
              maxZoom: 19,
            ),
            children: [
              TileLayer(
                urlTemplate: _satellite
                    ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.travellens.app',
              ),
              if (_userPosition != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _userPosition!,
                      radius: _radius * 1000,
                      useRadiusInMeter: true,
                      color: const Color(0x332563EB),
                      borderColor: const Color(0xFF2563EB),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: _markers
                    .map(
                      (marker) => Marker(
                        point: marker.position,
                        width: 42,
                        height: 48,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onTap: () => setState(() => _selected = marker),
                          child: Icon(
                            Icons.location_on_rounded,
                            size: _selected?.key == marker.key ? 42 : 36,
                            color: marker.has360
                                ? const Color(0xFF7C3AED)
                                : marker.type == 'location'
                                ? const Color(0xFF10B981)
                                : AppColors.brand,
                            shadows: const [
                              Shadow(color: Colors.white, blurRadius: 3),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              RichAttributionWidget(
                attributions: const [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          top: 12,
          child: Column(
            children: [
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _load(),
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Tìm điểm đến hoặc địa điểm...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 19),
                    suffixIcon: IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _locating ? null : _nearby,
                      icon: _locating
                          ? const SizedBox.square(
                              dimension: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.near_me_rounded, size: 16),
                      label: Text(
                        _locating
                            ? 'Đang định vị...'
                            : 'Đề xuất quanh đây (${_radius.toInt()} km)',
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        textStyle: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  IconButton.filledTonal(
                    tooltip: 'Bộ lọc',
                    onPressed: _showFilters,
                    icon: const Icon(Icons.tune_rounded, size: 18),
                  ),
                  const SizedBox(width: 3),
                  IconButton.filledTonal(
                    tooltip: _satellite ? 'Bản đồ đường phố' : 'Bản đồ vệ tinh',
                    onPressed: () => setState(() => _satellite = !_satellite),
                    icon: Icon(
                      _satellite
                          ? Icons.map_outlined
                          : Icons.satellite_alt_outlined,
                      size: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChip(
                      label: 'Tất cả',
                      selected:
                          _has360 == null && _minRating == null && !_popular,
                      onTap: () {
                        setState(() {
                          _has360 = null;
                          _minRating = null;
                          _popular = false;
                        });
                        _load();
                      },
                    ),
                    _FilterChip(
                      label: 'View360',
                      selected: _has360 == true,
                      onTap: () {
                        setState(() => _has360 = _has360 == true ? null : true);
                        _load();
                      },
                    ),
                    _FilterChip(
                      label: '4★ trở lên',
                      selected: _minRating == 4,
                      onTap: () {
                        setState(() => _minRating = _minRating == 4 ? null : 4);
                        _load();
                      },
                    ),
                    _FilterChip(
                      label: 'Phổ biến',
                      selected: _popular,
                      onTap: () {
                        setState(() => _popular = !_popular);
                        _load();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_loading)
          const Positioned.fill(
            child: IgnorePointer(
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        if (_error != null)
          Positioned(
            left: 14,
            right: 14,
            top: 148,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.errorSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        if (!_loading && _error == null)
          Positioned(
            left: 14,
            top: 148,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(color: Color(0x18000000), blurRadius: 8),
                ],
              ),
              child: Text(
                '${_markers.length} địa điểm',
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        if (_selected != null)
          Positioned(
            left: 14,
            right: 14,
            bottom: 16,
            child: _MarkerCard(marker: _selected!),
          ),
      ],
    ),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 7),
    child: Material(
      color: selected ? AppColors.brandDark : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.brandDark : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.muted,
            ),
          ),
        ),
      ),
    ),
  );
}

class _MarkerCard extends StatelessWidget {
  const _MarkerCard({required this.marker});
  final _MapMarker marker;
  @override
  Widget build(BuildContext context) {
    final image = AppConfig.assetUrl(marker.image);
    return Container(
      height: 86,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x28000000),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: SizedBox(
              width: 72,
              height: 70,
              child: image.isEmpty
                  ? const ColoredBox(
                      color: AppColors.borderLight,
                      child: Icon(Icons.landscape_outlined),
                    )
                  : CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  marker.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  marker.category.isEmpty ? marker.type : marker.category,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 9, color: AppColors.muted),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    if (marker.rating > 0) ...[
                      const Icon(
                        Icons.star_rounded,
                        size: 12,
                        color: AppColors.gold,
                      ),
                      Text(
                        ' ${marker.rating.toStringAsFixed(1)}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (marker.has360) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.threesixty_rounded,
                        size: 14,
                        color: Color(0xFF7C3AED),
                      ),
                    ],
                    if (marker.distance != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${marker.distance!.toStringAsFixed(1)} km',
                        style: const TextStyle(
                          fontSize: 8.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push(
              marker.type == 'location'
                  ? '/locations/${marker.sourceId}'
                  : '/destinations/${marker.sourceId}',
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              minimumSize: const Size(0, 34),
            ),
            child: const Text('Chi tiết', style: TextStyle(fontSize: 9.5)),
          ),
        ],
      ),
    );
  }
}

class _MapMarker {
  const _MapMarker({
    required this.key,
    required this.sourceId,
    required this.type,
    required this.name,
    required this.category,
    required this.image,
    required this.position,
    required this.rating,
    required this.has360,
    this.distance,
  });
  final String key, sourceId, type, name, category, image;
  final LatLng position;
  final double rating;
  final bool has360;
  final double? distance;
}

List<_MapMarker> _parseMarkers(dynamic body) {
  dynamic data = body;
  if (data is Map && data['data'] != null) data = data['data'];
  final records = <Map>[];
  void collect(dynamic value) {
    if (value is List) {
      records.addAll(value.whereType<Map>());
    } else if (value is Map) {
      for (final key in const [
        'markers',
        'locations',
        'destinations',
        'travel_destinations',
        'items',
        'results',
      ]) {
        if (value[key] is List) collect(value[key]);
      }
      if (records.isEmpty) records.add(value);
    }
  }

  collect(data);
  final output = <_MapMarker>[];
  for (var index = 0; index < records.length; index++) {
    final item = records[index];
    final lat = _number(item['latitude'] ?? item['lat']);
    final lng = _number(item['longitude'] ?? item['lng'] ?? item['lon']);
    if (lat == null || lng == null) continue;
    final rawType =
        '${item['type'] ?? item['marker_type'] ?? item['entity_type'] ?? ''}'
            .toLowerCase();
    final type = rawType.contains('location') || item['location_id'] != null
        ? 'location'
        : 'destination';
    final sourceId =
        '${type == 'location' ? item['location_id'] ?? item['id'] : item['travel_destination_id'] ?? item['destination_id'] ?? item['id'] ?? ''}';
    final has360 = _boolean(
      item['has_view360'] ??
          item['hasView360'] ??
          item['view360_available'] ??
          item['view360_count'],
    );
    output.add(
      _MapMarker(
        key: '$type-$sourceId-$index',
        sourceId: sourceId,
        type: type,
        name:
            '${item['name'] ?? item['title'] ?? item['location_name'] ?? item['destination_name'] ?? 'Địa điểm'}',
        category:
            '${item['category'] ?? item['category_name'] ?? item['destination_category_name'] ?? ''}',
        image:
            '${item['thumbnail_url'] ?? item['thumbnail'] ?? item['image_url'] ?? item['image'] ?? ''}',
        position: LatLng(lat, lng),
        rating:
            _number(
              item['rating'] ?? item['average_rating'] ?? item['avg_rating'],
            ) ??
            0,
        has360: has360,
        distance: _number(
          item['distance_km'] ?? item['distanceKm'] ?? item['distance'],
        ),
      ),
    );
  }
  return output;
}

double? _number(dynamic value) => double.tryParse('${value ?? ''}');
bool _boolean(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value > 0;
  return const {'true', '1', 'yes'}.contains('$value'.toLowerCase());
}
