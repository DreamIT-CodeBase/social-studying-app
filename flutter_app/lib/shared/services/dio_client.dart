import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/core/config/environment.dart';
import 'package:social_study_app/shared/services/auth_session_service.dart';
import 'package:social_study_app/shared/services/network_status_service.dart';

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
    _dio.interceptors.add(_AuthInterceptor(_dio));
    _dio.interceptors.add(_LatencyInterceptor());
    _dio.interceptors.add(_ErrorInterceptor());

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          request: true,
          // Never print bearer tokens, answers, profile data, or device tokens.
          requestHeader: false,
          requestBody: false,
          responseHeader: false,
          responseBody: false,
          error: true,
        ),
      );
    }
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._dio);

  static const _retriedKey = 'auth_refresh_retried';
  final Dio _dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await AuthSessionService.instance.getValidToken();

    debugPrint('REQUEST: ${options.method} ${options.uri}');

    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
      debugPrint('Auth token attached');
    } else {
      debugPrint('No auth token found');
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        options.extra[_retriedKey] == true ||
        options.headers['Authorization'] == null) {
      handler.next(err);
      return;
    }

    final previousHeader = options.headers['Authorization'];
    final refreshedToken = await AuthSessionService.instance.getValidToken(
      forceRefresh: true,
    );
    final refreshedHeader =
        refreshedToken == null ? null : 'Bearer $refreshedToken';

    if (refreshedHeader == null || refreshedHeader == previousHeader) {
      handler.next(err);
      return;
    }

    try {
      options.extra[_retriedKey] = true;
      options.headers['Authorization'] = refreshedHeader;
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
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
      401 =>
        'Your secure session could not be refreshed. Please reconnect and try again.',
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

class _LatencyInterceptor extends Interceptor {
  int _counter = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final requestId = '${DateTime.now().microsecondsSinceEpoch}_${++_counter}';
    options.extra['request_id'] = requestId;
    NetworkStatusService.instance.reportRequestStarted(
      requestId,
      url: options.path,
    );
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final requestId = response.requestOptions.extra['request_id'] as String?;
    if (requestId != null) {
      NetworkStatusService.instance.reportRequestFinished(requestId);
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final requestId = err.requestOptions.extra['request_id'] as String?;
    if (requestId != null) {
      NetworkStatusService.instance.reportRequestFinished(requestId);
    }

    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout) {
      NetworkStatusService.instance.reportSlowConnection(
        message:
            'Connection is taking longer than expected. We\'re keeping your study progress safe.',
      );
    } else if (err.type == DioExceptionType.connectionError) {
      NetworkStatusService.instance.reportOffline(
        message:
            'No internet connection detected. Please check your Wi-Fi or mobile data.',
      );
    }
    handler.next(err);
  }
}
