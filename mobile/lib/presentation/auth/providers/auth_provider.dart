import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/local/secure_storage.dart';
import '../../../data/datasources/remote/auth_api.dart';
import '../../../domain/entities/user.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';

// Dio provider
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));
  return dio;
});

// Storage provider
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

// Auth API provider
final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.read(dioProvider));
});

// Auth state
enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, User? user, String? error}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

// Auth notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthApi _authApi;
  final SecureStorageService _storage;
  final Dio _dio;

  AuthNotifier(this._authApi, this._storage, this._dio)
      : super(const AuthState());

  Future<void> checkAuth() async {
    try {
      final hasTokens = await _storage.hasTokens();
      if (hasTokens) {
        final token = await _storage.getAccessToken();
        _dio.options.headers['Authorization'] = 'Bearer $token';
        try {
          final response = await _authApi.getProfile();
          final userData = response['data'] as Map<String, dynamic>;
          final user = User.fromJson(userData);
          state = AuthState(status: AuthStatus.authenticated, user: user);
        } catch (e) {
          await _storage.clearTokens();
          state = const AuthState(status: AuthStatus.unauthenticated);
        }
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      // Storage or any other error — treat as unauthenticated.
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final response = await _authApi.login(email: email, password: password);
      final data = response['data'] as Map<String, dynamic>;
      await _storage.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      _dio.options.headers['Authorization'] = 'Bearer ${data['accessToken']}';

      final profileResponse = await _authApi.getProfile();
      final userData = profileResponse['data'] as Map<String, dynamic>;
      final user = User.fromJson(userData);
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Login failed';
      state = AuthState(status: AuthStatus.unauthenticated, error: message);
    }
  }

  Future<void> register(String email, String password, String nickname) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final response = await _authApi.register(
        email: email,
        password: password,
        nickname: nickname,
      );
      final data = response['data'] as Map<String, dynamic>;
      await _storage.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      _dio.options.headers['Authorization'] = 'Bearer ${data['accessToken']}';

      final profileResponse = await _authApi.getProfile();
      final userData = profileResponse['data'] as Map<String, dynamic>;
      final user = User.fromJson(userData);
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Registration failed';
      state = AuthState(status: AuthStatus.unauthenticated, error: message);
    }
  }

  Future<void> logout() async {
    await _storage.clearTokens();
    _dio.options.headers.remove('Authorization');
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

// Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.read(authApiProvider),
    ref.read(secureStorageProvider),
    ref.read(dioProvider),
  );
});
