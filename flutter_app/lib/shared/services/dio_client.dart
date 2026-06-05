import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/core/config/environment.dart';
import 'package:social_study_app/features/auth/data/auth_repository.dart';

part 'dio_client.g.dart';

@Riverpod(keepAlive: true)
DioClient dioClient(DioClientRef ref) => DioClient(ref: ref, baseUrl: Environment.apiBaseUrl);

class DioClient {
  DioClient({required DioClientRef ref, required String baseUrl}) : _dio = Dio() {
    _dio.options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {'Content-Type': 'application/json'},
    );
    _setupInterceptors(ref);
  }

  final Dio _dio;

  Dio get dio => _dio;

  void _setupInterceptors(DioClientRef ref) {
    _dio.interceptors.add(_AuthInterceptor(ref));
    _dio.interceptors.add(_ErrorInterceptor());
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this.ref);
  final DioClientRef ref;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Get valid access token (refreshes if necessary)
    final token = await ref.read(authRepositoryProvider).getValidAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    // If we get a 401, try to refresh once and retry
    if (err.response?.statusCode == 401) {
      try {
        final token = await ref.read(authRepositoryProvider).getValidAccessToken();
        if (token != null) {
          // Retry the request with the new token
          final options = err.requestOptions;
          options.headers['Authorization'] = 'Bearer $token';

          final response = await Dio().fetch(options);
          return handler.resolve(response);
        }
      } catch (_) {
        // Refresh failed, proceed with error
      }
    }
    handler.next(err);
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Don't intercept if it was already handled by _AuthInterceptor (resolved)
    if (err.type == DioExceptionType.cancel) return;

    final message = switch (err.response?.statusCode) {
      401 => 'Session expired. Please sign in again.',
      403 => 'You do not have permission to perform this action.',
      404 => 'The requested resource was not found.',
      422 => 'Invalid request data.',
      500 => 'Server error. Please try again later.',
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
