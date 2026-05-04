import 'package:cse470_app/models/auth_models.dart';
import 'package:cse470_app/core/services/api_client.dart';
import 'package:cse470_app/core/services/auth_service.dart';
import 'package:cse470_app/core/utils/app_exceptions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthState {
  const AuthState({
    this.isLoading = false,
    this.isInitialized = false,
    this.errorMessage,
    this.currentUser,
    this.accessToken,
    this.refreshToken,
  });

  final bool isLoading;
  final bool isInitialized;
  final String? errorMessage;
  final AppUser? currentUser;
  final String? accessToken;
  final String? refreshToken;

  bool get isAuthenticated =>
      currentUser != null && accessToken != null && accessToken!.isNotEmpty;

  AuthState copyWith({
    bool? isLoading,
    bool? isInitialized,
    String? errorMessage,
    bool clearErrorMessage = false,
    AppUser? currentUser,
    bool clearCurrentUser = false,
    String? accessToken,
    bool clearAccessToken = false,
    String? refreshToken,
    bool clearRefreshToken = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      currentUser: clearCurrentUser ? null : (currentUser ?? this.currentUser),
      accessToken: clearAccessToken ? null : (accessToken ?? this.accessToken),
      refreshToken: clearRefreshToken
          ? null
          : (refreshToken ?? this.refreshToken),
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._authService, this._apiClient)
    : _storage = const FlutterSecureStorage(),
      super(const AuthState()) {
    _apiClient.setAccessTokenRefresher(_refreshAccessToken);
    initialize();
  }

  final AuthService _authService;
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  Future<void> initialize() async {
    if (state.isInitialized) {
      return;
    }
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final access = await _storage.read(key: _accessTokenKey);
      final refresh = await _storage.read(key: _refreshTokenKey);
      if (access == null || refresh == null) {
        state = state.copyWith(
          isLoading: false,
          isInitialized: true,
          clearCurrentUser: true,
          clearAccessToken: true,
          clearRefreshToken: true,
        );
        return;
      }

      _apiClient.setAccessToken(access);
      try {
        final user = await _authService.me();
        state = state.copyWith(
          isLoading: false,
          isInitialized: true,
          currentUser: user,
          accessToken: access,
          refreshToken: refresh,
        );
        return;
      } on AppException {
        final refreshed = await _authService.refresh(refresh);
        await _persistTokens(
          accessToken: refreshed.accessToken,
          refreshToken: refreshed.refreshToken,
        );
        _apiClient.setAccessToken(refreshed.accessToken);
        state = state.copyWith(
          isLoading: false,
          isInitialized: true,
          currentUser: refreshed.user,
          accessToken: refreshed.accessToken,
          refreshToken: refreshed.refreshToken,
        );
      }
    } catch (_) {
      await _clearPersistedTokens();
      _apiClient.setAccessToken(null);
      state = state.copyWith(
        isLoading: false,
        isInitialized: true,
        errorMessage: 'Session restore failed. Please sign in again.',
        clearCurrentUser: true,
        clearAccessToken: true,
        clearRefreshToken: true,
      );
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final session = await _authService.login(
        email: email,
        password: password,
      );
      await _persistTokens(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      );
      _apiClient.setAccessToken(session.accessToken);
      state = state.copyWith(
        isLoading: false,
        isInitialized: true,
        currentUser: session.user,
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      );
      return true;
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Login failed. Please try again.',
      );
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? instituteName,
  }) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      await _authService.register(
        name: name,
        email: email,
        password: password,
        role: role,
        instituteName: instituteName,
      );

      if (role == UserRole.teacher) {
        state = state.copyWith(
          isLoading: false,
          isInitialized: true,
          clearCurrentUser: true,
          clearAccessToken: true,
          clearRefreshToken: true,
          clearErrorMessage: true,
        );
        return true;
      }

      state = state.copyWith(isLoading: false);
      return await login(email: email, password: password);
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Registration failed. Please try again.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    final refresh = state.refreshToken;
    if (refresh != null && refresh.isNotEmpty) {
      try {
        await _authService.logout(refresh);
      } catch (_) {}
    }
    await _clearPersistedTokens();
    _apiClient.setAccessToken(null);
    state = state.copyWith(
      isLoading: false,
      isInitialized: true,
      clearCurrentUser: true,
      clearAccessToken: true,
      clearRefreshToken: true,
      clearErrorMessage: true,
    );
  }

  Future<void> _persistTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> _clearPersistedTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<String?> _refreshAccessToken() async {
    final refresh = await _storage.read(key: _refreshTokenKey);
    if (refresh == null || refresh.isEmpty) {
      return null;
    }

    try {
      final refreshed = await _authService.refresh(refresh);
      await _persistTokens(
        accessToken: refreshed.accessToken,
        refreshToken: refreshed.refreshToken,
      );
      _apiClient.setAccessToken(refreshed.accessToken);
      state = state.copyWith(
        isInitialized: true,
        currentUser: refreshed.user,
        accessToken: refreshed.accessToken,
        refreshToken: refreshed.refreshToken,
        clearErrorMessage: true,
      );
      return refreshed.accessToken;
    } catch (_) {
      await _clearPersistedTokens();
      _apiClient.setAccessToken(null);
      state = state.copyWith(
        isInitialized: true,
        clearCurrentUser: true,
        clearAccessToken: true,
        clearRefreshToken: true,
        errorMessage: 'Session expired. Please sign in again.',
      );
      return null;
    }
  }
}
