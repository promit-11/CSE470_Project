import 'package:dio/dio.dart';

import 'package:cse470_app/core/utils/api_config.dart';
import 'package:cse470_app/core/utils/app_exceptions.dart';

typedef AccessTokenRefresher = Future<String?> Function();

class ApiClient {
  ApiClient._internal()
    : _dio = Dio(
        BaseOptions(
          baseUrl: '${ApiConfig.baseUrl}/api/v1',
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 12),
          headers: const {'Content-Type': 'application/json'},
        ),
      );

  static final ApiClient instance = ApiClient._internal();

  final Dio _dio;
  String? _accessToken;
  AccessTokenRefresher? _accessTokenRefresher;

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  void setAccessTokenRefresher(AccessTokenRefresher? refresher) {
    _accessTokenRefresher = refresher;
  }

  Map<String, dynamic> _headers() {
    if (_accessToken == null || _accessToken!.isEmpty) {
      return const <String, dynamic>{};
    }
    return <String, dynamic>{'Authorization': 'Bearer $_accessToken'};
  }

  dynamic _unwrap(dynamic data) {
    if (data is Map<String, dynamic> && data.containsKey('success')) {
      if (data['success'] == true) {
        return data['data'];
      }
      throw AppException((data['message'] ?? 'Request failed').toString());
    }
    return data;
  }

  bool _canAttemptRefresh(String path, DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode != 401) {
      return false;
    }
    if (_accessTokenRefresher == null) {
      return false;
    }
    if (path.startsWith('/auth/')) {
      return false;
    }
    return true;
  }

  Future<dynamic> _executeWithAutoRefresh({
    required String path,
    required Future<Response<dynamic>> Function() request,
  }) async {
    try {
      final response = await request();
      return _unwrap(response.data);
    } on DioException catch (error) {
      if (_canAttemptRefresh(path, error)) {
        final freshToken = await _accessTokenRefresher!.call();
        if (freshToken != null && freshToken.isNotEmpty) {
          _accessToken = freshToken;
          try {
            final retried = await request();
            return _unwrap(retried.data);
          } on DioException catch (retryError) {
            throw _mapError(retryError);
          }
        }
      }
      throw _mapError(error);
    }
  }

  Future<dynamic> get(String path) async {
    return _executeWithAutoRefresh(
      path: path,
      request: () =>
          _dio.get<dynamic>(path, options: Options(headers: _headers())),
    );
  }

  Future<dynamic> post(String path, dynamic data) async {
    return _executeWithAutoRefresh(
      path: path,
      request: () => _dio.post<dynamic>(
        path,
        data: data,
        options: Options(headers: _headers()),
      ),
    );
  }

  Future<dynamic> postMultipart(String path, FormData data) async {
    return _executeWithAutoRefresh(
      path: path,
      request: () => _dio.post<dynamic>(
        path,
        data: data,
        options: Options(
          headers: <String, dynamic>{
            ..._headers(),
            'Content-Type': 'multipart/form-data',
          },
        ),
      ),
    );
  }

  Future<dynamic> putMultipart(String path, FormData data) async {
    return _executeWithAutoRefresh(
      path: path,
      request: () => _dio.put<dynamic>(
        path,
        data: data,
        options: Options(
          headers: <String, dynamic>{
            ..._headers(),
            'Content-Type': 'multipart/form-data',
          },
        ),
      ),
    );
  }

  Future<dynamic> put(String path, dynamic data) async {
    return _executeWithAutoRefresh(
      path: path,
      request: () => _dio.put<dynamic>(
        path,
        data: data,
        options: Options(headers: _headers()),
      ),
    );
  }

  Future<dynamic> patch(String path, dynamic data) async {
    return _executeWithAutoRefresh(
      path: path,
      request: () => _dio.patch<dynamic>(
        path,
        data: data,
        options: Options(headers: _headers()),
      ),
    );
  }

  Future<dynamic> delete(String path) async {
    return _executeWithAutoRefresh(
      path: path,
      request: () =>
          _dio.delete<dynamic>(path, options: Options(headers: _headers())),
    );
  }

  AppException _mapError(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['message'] != null) {
      return AppException(data['message'].toString(), statusCode: statusCode);
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return AppException(
        'Connection timed out. Please try again.',
        statusCode: statusCode,
      );
    }
    return AppException(
      'Request failed. Please check backend connectivity.',
      statusCode: statusCode,
    );
  }
}
