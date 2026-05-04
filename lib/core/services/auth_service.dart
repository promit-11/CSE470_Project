import 'package:cse470_app/models/auth_models.dart';
import 'package:cse470_app/core/services/api_client.dart';

class AuthService {
  AuthService(this._client);

  final ApiClient _client;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final data = await _client.post('/auth/login', {
      'email': email,
      'password': password,
    });

    final map = data as Map<String, dynamic>;
    return AuthSession(
      accessToken: (map['accessToken'] ?? '').toString(),
      refreshToken: (map['refreshToken'] ?? '').toString(),
      user: AppUser.fromJson(map['user'] as Map<String, dynamic>),
    );
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? instituteName,
  }) async {
    await _client.post('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
      'role': userRoleToApi(role),
      if (instituteName != null && instituteName.trim().isNotEmpty)
        'instituteName': instituteName.trim(),
    });
  }

  Future<AuthSession> refresh(String refreshToken) async {
    final data = await _client.post('/auth/refresh', {
      'refreshToken': refreshToken,
    });
    final map = data as Map<String, dynamic>;
    return AuthSession(
      accessToken: (map['accessToken'] ?? '').toString(),
      refreshToken: refreshToken,
      user: AppUser.fromJson(map['user'] as Map<String, dynamic>),
    );
  }

  Future<void> logout(String refreshToken) async {
    await _client.post('/auth/logout', {'refreshToken': refreshToken});
  }

  Future<AppUser> me() async {
    final data = await _client.get('/auth/me');
    final map = data as Map<String, dynamic>;
    return AppUser.fromJson(map['user'] as Map<String, dynamic>);
  }
}
