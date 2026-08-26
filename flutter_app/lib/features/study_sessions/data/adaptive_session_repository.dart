import 'package:dio/dio.dart';
import 'package:social_study_app/features/study_sessions/domain/adaptive_session_models.dart';

class AdaptiveSessionRepository {
  const AdaptiveSessionRepository(this._dio);

  final Dio _dio;

  Future<AdaptiveSessionPlan> prepare({
    required String workspaceId,
    required AdaptiveSessionMode mode,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/workspaces/$workspaceId/adaptive-sessions/prepare',
        data: {'mode': mode.wire},
      );
      return AdaptiveSessionPlan.fromJson(response.data!);
    } on DioException catch (error) {
      throw AdaptiveSessionException(
        _message(error),
        retryable: _isRetryablePreparationError(error),
      );
    }
  }

  Future<AdaptiveSessionSummary> complete({
    required String workspaceId,
    required String sessionId,
    required String completionReason,
    required int elapsedSeconds,
    required List<SessionQuestionAttempt> questionAttempts,
    required List<SessionFlashcardAttempt> flashcardAttempts,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/workspaces/$workspaceId/adaptive-sessions/$sessionId/complete',
        data: {
          'completion_reason': completionReason,
          'elapsed_seconds': elapsedSeconds,
          'question_attempts':
              questionAttempts.map((attempt) => attempt.toJson()).toList(),
          'flashcard_attempts':
              flashcardAttempts.map((attempt) => attempt.toJson()).toList(),
        },
      );
      return AdaptiveSessionSummary.fromJson(response.data!);
    } on DioException catch (error) {
      throw AdaptiveSessionException(_message(error));
    }
  }

  Future<AdaptiveAnswerEvaluation> evaluateAnswer({
    required String workspaceId,
    required String sessionId,
    required String questionId,
    required String answer,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/workspaces/$workspaceId/adaptive-sessions/$sessionId/evaluate',
        data: {
          'question_id': questionId,
          'answer': answer,
        },
      );
      return AdaptiveAnswerEvaluation.fromJson(response.data!);
    } on DioException catch (error) {
      throw AdaptiveSessionException(_message(error));
    }
  }

  String _message(DioException error) {
    final body = error.response?.data;
    if (body is Map<String, dynamic> && body['detail'] is String) {
      final detail = body['detail'] as String;
      if (detail.toLowerCase().contains('internal server error')) {
        return 'Optimizing study session...';
      }
      return detail;
    }
    return error.message ?? 'Optimizing study session...';
  }

  bool _isRetryablePreparationError(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode != null && (statusCode >= 500 || statusCode == 429 || statusCode == 408 || statusCode == 409)) {
      return true;
    }
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout;
  }
}

class AdaptiveSessionException implements Exception {
  const AdaptiveSessionException(this.message, {this.retryable = false});

  final String message;
  final bool retryable;

  @override
  String toString() => message;
}
