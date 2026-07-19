import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../config/app_config.dart';
import '../storage/token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>(
  (_) => const TokenStorage(FlutterSecureStorage()),
);
final dioProvider = Provider<Dio>((ref) {
  final storage = ref.read(tokenStorageProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.read();
        if (token != null && token.isNotEmpty)
          options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
    ),
  );
  return dio;
});
dynamic unwrap(dynamic body) =>
    body is Map<String, dynamic> && body.containsKey('data')
    ? body['data']
    : body;
List<Map<String, dynamic>> unwrapList(
  dynamic body, [
  List<String> keys = const [],
]) {
  final value = unwrap(body);
  if (value is List)
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  if (value is Map)
    for (final key in [...keys, 'items', 'data', 'results']) {
      final nested = value[key];
      if (nested is List)
        return nested
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
    }
  return [];
}

String apiError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map)
      return '${data['message'] ?? data['error'] ?? 'Request failed'}';
    return error.message ?? 'Unable to connect to the server.';
  }
  return error.toString().replaceFirst('Bad state: ', '');
}
