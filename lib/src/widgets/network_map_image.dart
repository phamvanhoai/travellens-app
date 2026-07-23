import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/network/api_client.dart';
import '../design/app_colors.dart';

class NetworkMapImage extends ConsumerStatefulWidget {
  const NetworkMapImage({
    super.key,
    required this.url,
    this.fit = BoxFit.contain,
  });

  final String url;
  final BoxFit fit;

  @override
  ConsumerState<NetworkMapImage> createState() => _NetworkMapImageState();
}

class _NetworkMapImageState extends ConsumerState<NetworkMapImage> {
  late Future<_MapAsset> asset;

  @override
  void initState() {
    super.initState();
    asset = _load();
  }

  @override
  void didUpdateWidget(covariant NetworkMapImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) asset = _load();
  }

  Future<_MapAsset> _load() async {
    final response = await ref
        .read(dioProvider)
        .get<List<int>>(
          widget.url,
          options: Options(responseType: ResponseType.bytes),
        );
    final bytes = Uint8List.fromList(response.data ?? const []);
    if (bytes.isEmpty) throw StateError('Empty map image');
    final type = response.headers.value(Headers.contentTypeHeader) ?? '';
    final sample = utf8
        .decode(bytes.take(300).toList(), allowMalformed: true)
        .trimLeft()
        .toLowerCase();
    return _MapAsset(
      bytes,
      type.contains('svg') ||
          sample.startsWith('<svg') ||
          sample.startsWith('<?xml'),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_MapAsset>(
    future: asset,
    builder: (_, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const ColoredBox(
          color: AppColors.borderLight,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      }
      if (!snapshot.hasData) return const _MapImageFallback();
      final value = snapshot.data!;
      if (value.svg) {
        return SvgPicture.memory(
          value.bytes,
          fit: widget.fit,
          errorBuilder: (_, _, _) => const _MapImageFallback(),
        );
      }
      return Image.memory(
        value.bytes,
        fit: widget.fit,
        errorBuilder: (_, _, _) => const _MapImageFallback(),
      );
    },
  );
}

class _MapAsset {
  const _MapAsset(this.bytes, this.svg);
  final Uint8List bytes;
  final bool svg;
}

class _MapImageFallback extends StatelessWidget {
  const _MapImageFallback();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppColors.borderLight,
    child: Center(
      child: Icon(Icons.map_outlined, color: AppColors.subtle, size: 38),
    ),
  );
}
