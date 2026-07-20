import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:panorama_viewer/panorama_viewer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../core/network/api_client.dart';

class View360Screen extends ConsumerStatefulWidget {
  const View360Screen({
    super.key,
    this.destinationId,
    this.locationId,
    this.sceneId,
  });
  final int? destinationId, locationId, sceneId;
  @override
  ConsumerState<View360Screen> createState() => _View360ScreenState();
}

class _View360ScreenState extends ConsumerState<View360Screen> {
  final AudioPlayer _audio = AudioPlayer();
  List<_Scene> scenes = [];
  List<_HotspotData> hotspots = [];
  int sceneIndex = 0, imageIndex = 0;
  bool loading = true,
      imageLoading = true,
      rotate = true,
      gyro = false,
      showInfo = true;
  bool audioPlaying = false, muted = false;
  String? error;
  _Scene? get scene => scenes.isEmpty ? null : scenes[sceneIndex];
  _Image? get image =>
      scene == null || scene!.images.isEmpty ? null : scene!.images[imageIndex];
  @override
  void initState() {
    super.initState();
    _audio.playerStateStream.listen((state) {
      if (mounted) setState(() => audioPlaying = state.playing);
    });
    load();
  }

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final responses = await Future.wait([
        dio.get('/view360'),
        dio.get('/view360-images'),
        if (widget.destinationId != null)
          dio.get('/travel-destinations/${widget.destinationId}'),
      ]);
      var rawScenes = unwrapList(responses[0].data, [
        'scenes',
        'view360',
        'rows',
      ]);
      final rawImages = unwrapList(responses[1].data, [
        'images',
        'view360_images',
        'rows',
      ]);
      if (widget.destinationId != null && responses.length > 2) {
        dynamic detail = unwrap(responses[2].data);
        if (detail is Map && detail['destination'] is Map)
          detail = detail['destination'];
        if (detail is Map && detail['travel_destination'] is Map)
          detail = detail['travel_destination'];
        final related = detail is Map ? detail['view360'] : null;
        if (related is List) {
          final ids = related
              .whereType<Map>()
              .map((e) => _num(e['view_id'] ?? e['view360_id'] ?? e['id']))
              .toSet();
          rawScenes = rawScenes
              .where(
                (e) => ids.contains(
                  _num(e['view_id'] ?? e['view360_id'] ?? e['id']),
                ),
              )
              .toList();
        }
      }
      if (widget.locationId != null) {
        rawScenes = rawScenes
            .where((scene) => _num(scene['location_id']) == widget.locationId)
            .toList();
      }
      final mapped =
          rawScenes
              .map((s) {
                final id = _num(s['view_id'] ?? s['view360_id'] ?? s['id']);
                final images =
                    rawImages
                        .where(
                          (i) => _num(i['view_id'] ?? i['view360_id']) == id,
                        )
                        .map(
                          (i) => _Image(
                            _num(i['image_id'] ?? i['id']),
                            AppConfig.assetUrl(
                              '${i['image_url'] ?? i['image_file'] ?? ''}',
                            ),
                            _num(i['order_index']),
                          ),
                        )
                        .where((i) => i.url.isNotEmpty)
                        .toList()
                      ..sort((a, b) => a.order.compareTo(b.order));
                return _Scene(
                  id,
                  _num(s['location_id']),
                  '${s['title'] ?? '360 Scene #$id'}',
                  _clean(
                    '${s['description'] ?? 'Explore this location from every angle.'}',
                  ),
                  '${s['language'] ?? 'Narration'}',
                  AppConfig.assetUrl(
                    '${s['audio_url'] ?? s['audio_file'] ?? ''}',
                  ),
                  _num(s['order_index']),
                  images,
                );
              })
              .where((s) => s.id > 0 && s.images.isNotEmpty)
              .toList()
            ..sort((a, b) => a.order.compareTo(b.order));
      if (mounted)
        setState(() {
          scenes = mapped;
          final requestedIndex = widget.sceneId == null
              ? -1
              : mapped.indexWhere((scene) => scene.id == widget.sceneId);
          sceneIndex = requestedIndex >= 0 ? requestedIndex : 0;
          imageIndex = 0;
          imageLoading = true;
        });
      if (mapped.isNotEmpty) await _prepareScene();
    } catch (e) {
      if (mounted) setState(() => error = apiError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void select(int i) {
    setState(() {
      sceneIndex = i;
      imageIndex = 0;
      imageLoading = true;
      hotspots = [];
    });
    _prepareScene();
  }

  Future<void> _prepareScene() async {
    final current = scene;
    if (current == null) return;
    await _audio.stop();
    if (current.audioUrl.isNotEmpty) {
      try {
        await _audio.setUrl(current.audioUrl);
        await _audio.setVolume(muted ? 0 : 1);
        unawaited(_audio.play());
      } catch (_) {}
    }
    try {
      final response = await ref
          .read(dioProvider)
          .get('/view360/${current.id}/hotspots');
      final mapped = unwrapList(response.data, ['hotspots'])
          .map(
            (h) => _HotspotData(
              id: _num(h['hotspot_id'] ?? h['id']),
              type: '${h['type'] ?? 'info'}',
              title: '${h['title'] ?? 'Point of interest'}',
              description: _clean('${h['description'] ?? ''}'),
              yaw: double.tryParse('${h['yaw'] ?? 0}') ?? 0,
              pitch: double.tryParse('${h['pitch'] ?? 0}') ?? 0,
              targetSceneId: h['target_view360_id'] == null
                  ? null
                  : _num(h['target_view360_id']),
              targetUrl: '${h['target_url'] ?? ''}',
            ),
          )
          .where((h) => h.id > 0)
          .toList();
      if (mounted && scene?.id == current.id) setState(() => hotspots = mapped);
    } catch (_) {
      if (mounted && scene?.id == current.id) setState(() => hotspots = []);
    }
  }

  Future<void> _toggleAudio() async {
    if (scene?.audioUrl.isEmpty ?? true) return;
    try {
      if (_audio.playing) {
        await _audio.pause();
      } else {
        await _audio.play();
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio narration could not be played.')),
        );
    }
  }

  Future<void> _toggleMute() async {
    muted = !muted;
    await _audio.setVolume(muted ? 0 : 1);
    if (mounted) setState(() {});
  }

  void _openHotspot(_HotspotData hotspot) {
    if (hotspot.type == 'navigation' && hotspot.targetSceneId != null) {
      final index = scenes.indexWhere((s) => s.id == hotspot.targetSceneId);
      if (index >= 0) select(index);
      return;
    }
    if (hotspot.type == 'link' && hotspot.targetUrl.isNotEmpty) {
      launchUrl(
        Uri.parse(hotspot.targetUrl),
        mode: LaunchMode.externalApplication,
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _hotspotIcon(hotspot.type),
              color: const Color(0xFF0891B2),
              size: 30,
            ),
            const SizedBox(height: 12),
            Text(
              hotspot.title,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            if (hotspot.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(hotspot.description, style: const TextStyle(height: 1.5)),
            ],
          ],
        ),
      ),
    );
  }

  void move(int d) {
    if (scenes.isNotEmpty)
      select((sceneIndex + d + scenes.length) % scenes.length);
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Scaffold(
        backgroundColor: Color(0xFF020617),
        body: _Loading(),
      );
    if (scene == null || image == null)
      return Scaffold(
        backgroundColor: const Color(0xFF020617),
        body: _Empty(
          error: error,
          retry: load,
          destinationId: widget.destinationId,
        ),
      );
    final s = scene!, img = image!;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          KeyedSubtree(
            key: ValueKey('${s.id}-${img.id}'),
            child: PanoramaViewer(
              animSpeed: rotate ? 0.12 : 0,
              sensorControl: gyro
                  ? SensorControl.orientation
                  : SensorControl.none,
              onImageLoad: () {
                if (mounted) setState(() => imageLoading = false);
              },
              hotspots: hotspots
                  .map(
                    (hotspot) => Hotspot(
                      name: '${hotspot.id}',
                      latitude: hotspot.pitch,
                      longitude: _webYawToFlutterLongitude(hotspot.yaw),
                      width: 54,
                      height: 54,
                      widget: GestureDetector(
                        onTap: () => _openHotspot(hotspot),
                        child: Container(
                          decoration: BoxDecoration(
                            color: hotspot.type == 'navigation'
                                ? const Color(0xFF0891B2)
                                : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black45, blurRadius: 12),
                            ],
                          ),
                          child: Icon(
                            _hotspotIcon(hotspot.type),
                            color: hotspot.type == 'navigation'
                                ? Colors.white
                                : const Color(0xFF0891B2),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
              child: Image.network(
                img.url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Color(0xFF0F172A),
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                      size: 54,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x99000000),
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xDD000000),
                  ],
                  stops: [0, .25, .58, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Align(
                alignment: Alignment.topCenter,
                child: Row(
                  children: [
                    _Button(
                      icon: Icons.arrow_back,
                      onTap: () => context.canPop()
                          ? context.pop()
                          : context.go(
                              widget.destinationId == null
                                  ? '/destinations'
                                  : '/destinations/${widget.destinationId}',
                            ),
                    ),
                    const Spacer(),
                    if (s.audioUrl.isNotEmpty) ...[
                      _Button(
                        icon: audioPlaying
                            ? Icons.pause_circle_outline
                            : Icons.headphones,
                        active: audioPlaying,
                        onTap: _toggleAudio,
                      ),
                      const SizedBox(width: 8),
                      _Button(
                        icon: muted ? Icons.volume_off : Icons.volume_up,
                        active: muted,
                        onTap: _toggleMute,
                      ),
                      const SizedBox(width: 8),
                    ],
                    _Button(
                      icon: gyro
                          ? Icons.screen_rotation
                          : Icons.screen_lock_rotation,
                      active: gyro,
                      onTap: () => setState(() => gyro = !gyro),
                    ),
                    const SizedBox(width: 8),
                    _Button(
                      icon: rotate ? Icons.pause : Icons.play_arrow,
                      active: rotate,
                      onTap: () => setState(() => rotate = !rotate),
                    ),
                    const SizedBox(width: 8),
                    _Button(
                      icon: showInfo
                          ? Icons.layers_clear_outlined
                          : Icons.layers_outlined,
                      onTap: () => setState(() => showInfo = !showInfo),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (imageLoading) const _Entering(),
          if (showInfo)
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 7,
                      children: [
                        _Badge(
                          Icons.threesixty,
                          'Scene ${sceneIndex + 1}/${scenes.length}',
                        ),
                        _Badge(Icons.translate, s.language),
                        if (s.locationId > 0)
                          _Badge(
                            Icons.location_on_outlined,
                            'Location #${s.locationId}',
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        height: 1.08,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (s.description.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        s.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFDCE5ED),
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (s.images.length > 1) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: List.generate(
                          s.images.length,
                          (i) => GestureDetector(
                            onTap: () => setState(() {
                              imageIndex = i;
                              imageLoading = true;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.only(right: 7),
                              width: i == imageIndex ? 34 : 16,
                              height: 4,
                              decoration: BoxDecoration(
                                color: i == imageIndex
                                    ? Colors.white
                                    : Colors.white38,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: () => move(-1),
                          icon: const Icon(Icons.chevron_left),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(48, 48),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: openScenes,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0F172A),
                              minimumSize: const Size.fromHeight(48),
                            ),
                            icon: const Icon(Icons.view_carousel_outlined),
                            label: Text('${scenes.length} scenes'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filledTonal(
                          onPressed: () => move(1),
                          icon: const Icon(Icons.chevron_right),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(48, 48),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: MediaQuery.paddingOf(context).top + 72,
            child: const IgnorePointer(
              child: Center(
                child: Text(
                  'Drag to look around · Pinch to zoom',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void openScenes() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Scene Navigation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .58,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: scenes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 9),
                  itemBuilder: (_, i) {
                    final s = scenes[i];
                    return Material(
                      color: i == sceneIndex
                          ? Colors.white12
                          : Colors.white.withValues(alpha: .05),
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          select(i);
                        },
                        child: Row(
                          children: [
                            SizedBox(
                              width: 100,
                              height: 76,
                              child: CachedNetworkImage(
                                imageUrl: s.images.first.url,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'SCENE ${i + 1}',
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      s.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      s.language,
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (i == sceneIndex)
                              const Padding(
                                padding: EdgeInsets.only(right: 14),
                                child: Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF22D3EE),
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
        ),
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({required this.icon, required this.onTap, this.active = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  @override
  Widget build(BuildContext context) => Material(
    color: active ? const Color(0xFF0891B2) : Colors.black45,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox.square(
        dimension: 46,
        child: Icon(icon, color: Colors.white, size: 21),
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.black45,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: Colors.white24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 14),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _Entering extends StatelessWidget {
  const _Entering();
  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: ColoredBox(
      color: Color(0x88020A16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            SizedBox(height: 18),
            Text(
              'ENTERING SCENE',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.threesixty, color: Colors.white, size: 68),
        SizedBox(height: 18),
        CircularProgressIndicator(color: Colors.white),
        SizedBox(height: 18),
        Text(
          'Preparing your virtual journey',
          style: TextStyle(color: Colors.white70),
        ),
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.error,
    required this.retry,
    required this.destinationId,
  });
  final String? error;
  final VoidCallback retry;
  final int? destinationId;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.threesixty, color: Colors.white, size: 68),
            const SizedBox(height: 18),
            const Text(
              'No 360 experience available',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              error ??
                  'No published panorama is connected to this destination yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, height: 1.5),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: error == null
                  ? () => context.go(
                      destinationId == null
                          ? '/destinations'
                          : '/destinations/$destinationId',
                    )
                  : retry,
              icon: Icon(error == null ? Icons.arrow_back : Icons.refresh),
              label: Text(error == null ? 'Back to destinations' : 'Try again'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Scene {
  const _Scene(
    this.id,
    this.locationId,
    this.title,
    this.description,
    this.language,
    this.audioUrl,
    this.order,
    this.images,
  );
  final int id, locationId, order;
  final String title, description, language, audioUrl;
  final List<_Image> images;
}

class _Image {
  const _Image(this.id, this.url, this.order);
  final int id, order;
  final String url;
}

class _HotspotData {
  const _HotspotData({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.yaw,
    required this.pitch,
    required this.targetSceneId,
    required this.targetUrl,
  });
  final int id;
  final String type, title, description, targetUrl;
  final double yaw, pitch;
  final int? targetSceneId;
}

IconData _hotspotIcon(String type) => switch (type) {
  'navigation' => Icons.arrow_forward,
  'link' => Icons.open_in_new,
  'location' => Icons.location_on,
  _ => Icons.info_outline,
};

double _webYawToFlutterLongitude(double yaw) {
  final shifted = (yaw + 180) % 360;
  return shifted > 180 ? shifted - 360 : shifted;
}

int _num(dynamic v) => int.tryParse('$v') ?? 0;
String _clean(String v) =>
    v.replaceAll(RegExp('<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
