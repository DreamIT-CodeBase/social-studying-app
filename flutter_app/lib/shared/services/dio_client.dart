import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/core/config/environment.dart';

part 'dio_client.g.dart';

@Riverpod(keepAlive: true)
DioClient dioClient(DioClientRef ref) =>
    DioClient(baseUrl: Environment.apiBaseUrl);

class DioClient {
  DioClient({required String baseUrl}) : _dio = Dio() {
    debugPrint('===================================');
    debugPrint('API BASE URL: $baseUrl');
    debugPrint('===================================');

    _dio.options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120), // GPT-4o can take 20-60s
      headers: const {
        'Content-Type': 'application/json',
      },
    );

    _setupInterceptors();
  }

  final Dio _dio;

  Dio get dio => _dio;

  void _setupInterceptors() {
    _dio.interceptors.add(_AuthInterceptor());
    _dio.interceptors.add(_ErrorInterceptor());

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          request: true,
          requestHeader: true,
          requestBody: true,
          responseHeader: true,
          responseBody: true,
          error: true,
        ),
      );
    }
  }
}

class _AuthInterceptor extends Interceptor {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: _tokenKey);

    debugPrint('REQUEST: ${options.method} ${options.uri}');

    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
      debugPrint('Auth token attached');
    } else {
      debugPrint('No auth token found');
    }

    handler.next(options);
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    debugPrint('❌ API ERROR');
    debugPrint('URL: ${err.requestOptions.uri}');
    debugPrint('Status Code: ${err.response?.statusCode}');
    debugPrint('Message: ${err.message}');

    final message = switch (err.response?.statusCode) {
      401 => 'Session expired. Please sign in again.',
      403 => 'You do not have permission to perform this action.',
      404 => 'The requested resource was not found.',
      422 => 'Invalid request data.',
      500 => 'Server error. Please try again later.',
      503 => 'Service temporarily unavailable. Please try again later.',
      _ => err.message ?? 'An unexpected error occurred.',
    };

    handler.next(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: message,
        message: message,
      ),
    );
  }
}