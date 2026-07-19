import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

class AuthState {
  const AuthState({
    required this.ready,
    this.user,
    this.loading = false,
    this.error,
  });
  final bool ready;
  final Map<String, dynamic>? user;
  final bool loading;
  final String? error;
  bool get authenticated => user != null;
}

final authProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  Dio get _dio => ref.read(dioProvider);
  @override
  AuthState build() {
    Future.microtask(restore);
    return const AuthState(ready: false);
  }

  Future<void> restore() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) {
      state = const AuthState(ready: true);
      return;
    }
    try {
      final response = await _dio.get('/auth/profile');
      final data = unwrap(response.data);
      final raw = data is Map && data['user'] is Map ? data['user'] : data;
      state = AuthState(
        ready: true,
        user: Map<String, dynamic>.from(raw as Map),
      );
    } catch (_) {
      await ref.read(tokenStorageProvider).clear();
      state = const AuthState(ready: true);
    }
  }

  Future<bool> login(String email, String password) async {
    state = AuthState(ready: true, loading: true, user: state.user);
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      final data = unwrap(response.data);
      final map = Map<String, dynamic>.from(data as Map);
      final token =
          '${map['token'] ?? map['access_token'] ?? map['accessToken'] ?? ''}';
      final raw = map['user'] ?? map['customer'];
      if (token.isEmpty)
        throw StateError('Login response does not contain a token.');
      final user = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{'role': 'customer', 'email': email};
      if ('${user['role'] ?? user['user_type'] ?? 'customer'}'.toLowerCase() !=
          'customer')
        throw StateError('This mobile app is only available for customers.');
      await ref.read(tokenStorageProvider).write(token);
      state = AuthState(ready: true, user: user);
      return true;
    } catch (e) {
      state = AuthState(ready: true, error: apiError(e));
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    state = const AuthState(ready: true, loading: true);
    try {
      await _dio.post(
        '/auth/register',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'confirm_password': password,
        },
      );
      state = const AuthState(ready: true);
      return true;
    } catch (e) {
      state = AuthState(ready: true, error: apiError(e));
      return false;
    }
  }

  Future<void> logout() async {
    await ref.read(tokenStorageProvider).clear();
    state = const AuthState(ready: true);
  }
}
