import 'package:dio/dio.dart';
import 'package:social_study_app/features/questions/data/demo_questions_repository.dart'
    show
        NoTopicsAvailableException,
        QuestionGenerationUnavailableException,
        QuestionNotAnswerableException,
        QuestionNotFoundException;
import 'package:social_study_app/features/questions/data/questions_repository.dart';
import 'package:social_study_app/shared/models/question.dart';

/// Dio-backed implementation hitting Sprint 3.9 / 3.10's FastAPI routes.
///
/// Error translation maps HTTP statuses to the typed exceptions defined
/// alongside the demo implementation. The Dio error interceptor (see
/// [DioClient]) already produces friendly text for transport-level
/// failures; we add type information so the UI can branch on specific
/// terminal states (e.g. "show admin-needed banner" on 409, "back off
/// and retry" on 503).
class RealQuestionsRepository implements QuestionsRepository {
  RealQuestionsRepository({required this.dio});

  final Dio dio;

  static const _apiPrefix = '/api/v1';

  @override
  Future<Question> next({required String workspaceId}) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '$_apiPrefix/workspaces/$workspaceId/questions/next',
      );
      return Question.fromJson(response.data!);
    } on DioException catch (e) {
      throw _translateNext(e);
    }
  }

  @override
  Future<AnswerFeedback> submitAnswer({
    required String workspaceId,
    required String questionId,
    required AnswerSubmission submission,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '$_apiPrefix/workspaces/$workspaceId/questions/$questionId/answer',
        data: submission.toJson(),
      );
      return AnswerFeedback.fromJson(response.data!);
    } on DioException catch (e) {
      throw _translateAnswer(e);
    }
  }

  // ── Error translation ───────────────────────────────────────────────────

  Exception _translateNext(DioException e) {
    final status = e.response?.statusCode;
    if (status == 409) {
      return NoTopicsAvailableException(
        _detailMessage(e.response?.data) ?? 'No topics available',
      );
    }
    if (status == 503) {
      final retryAfter = _retryAfterSeconds(e.response?.headers);
      return QuestionGenerationUnavailableException(
        message: _detailMessage(e.response?.data) ??
            'Couldn\'t generate a question right now',
        retryAfterSeconds: retryAfter,
      );
    }
    return e;
  }

  Exception _translateAnswer(DioException e) {
    final status = e.response?.statusCode;
    if (status == 404) {
      return QuestionNotFoundException(
        _detailMessage(e.response?.data) ?? 'Question not found',
      );
    }
    if (status == 409) {
      return QuestionNotAnswerableException(
        _detailMessage(e.response?.data) ??
            'Question is not in an answerable state',
      );
    }
    return e;
  }

  String? _detailMessage(Object? body) {
    if (body is Map<String, dynamic>) {
      final detail = body['detail'];
      if (detail is String) return detail;
    }
    return null;
  }

  int _retryAfterSeconds(Headers? headers) {
    if (headers == null) return 30;
    final value = headers.value('retry-after');
    if (value == null) return 30;
    return int.tryParse(value) ?? 30;
  }
}
