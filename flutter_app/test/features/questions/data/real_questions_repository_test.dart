import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/features/questions/data/demo_questions_repository.dart';
import 'package:social_study_app/features/questions/data/real_questions_repository.dart';
import 'package:social_study_app/shared/models/question.dart';

/// In-process Dio adapter — same pattern as the documents repository
/// tests. Returns canned ResponseBody objects per (method, path).
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  RequestOptions? lastRequest;
  Uint8List? lastRequestBody;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    if (requestStream != null) {
      final bytes = <int>[];
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
      lastRequestBody = Uint8List.fromList(bytes);
    }
    return handler(options);
  }
}

ResponseBody _json(String body, {int status = 200, Headers? headers}) {
  final hdrs = <String, List<String>>{
    'content-type': ['application/json'],
  };
  if (headers != null) {
    for (final key in headers.map.keys) {
      hdrs[key] = headers.value(key) != null ? [headers.value(key)!] : [];
    }
  }
  return ResponseBody.fromString(body, status, headers: hdrs);
}

Dio _dio(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('RealQuestionsRepository.next', () {
    test('hits POST /api/v1/workspaces/{ws}/questions/next', () async {
      final adapter = _FakeAdapter((opts) {
        return _json(
          jsonEncode({
            'id': 'qst_abc',
            'topic': 'Photosynthesis',
            'question_type': 'mcq',
            'difficulty': 'beginner',
            'body': 'Which organelle?',
            'options': [
              {'key': 'A', 'text': 'Mitochondria'},
              {'key': 'B', 'text': 'Chloroplast'},
            ],
          }),
        );
      });
      final repo = RealQuestionsRepository(dio: _dio(adapter));
      final q = await repo.next(workspaceId: 'wsp_a');

      expect(adapter.lastRequest!.method, 'POST');
      expect(
        adapter.lastRequest!.path,
        '/api/v1/workspaces/wsp_a/questions/next',
      );
      expect(q.id, 'qst_abc');
      expect(q.questionType, QuestionType.mcq);
      expect(q.options, hasLength(2));
    });

    test('409 → NoTopicsAvailableException with detail message', () async {
      final adapter = _FakeAdapter(
        (opts) => _json(
          jsonEncode({'detail': 'No topics — upload material first.'}),
          status: 409,
        ),
      );
      final repo = RealQuestionsRepository(dio: _dio(adapter));
      try {
        await repo.next(workspaceId: 'wsp_a');
        fail('expected NoTopicsAvailableException');
      } on NoTopicsAvailableException catch (e) {
        expect(e.message, contains('upload material'));
      }
    });

    test(
        '503 → QuestionGenerationUnavailableException with Retry-After parsed',
        () async {
      final adapter = _FakeAdapter(
        (opts) => ResponseBody.fromString(
          jsonEncode({'detail': 'try again later'}),
          503,
          headers: {
            'content-type': ['application/json'],
            'retry-after': ['45'],
          },
        ),
      );
      final repo = RealQuestionsRepository(dio: _dio(adapter));
      try {
        await repo.next(workspaceId: 'wsp_a');
        fail('expected QuestionGenerationUnavailableException');
      } on QuestionGenerationUnavailableException catch (e) {
        expect(e.retryAfterSeconds, 45);
        expect(e.message, contains('try again'));
      }
    });

    test(
        '503 with missing Retry-After defaults to 30 seconds',
        () async {
      final adapter = _FakeAdapter(
        (opts) => _json(
          jsonEncode({'detail': 'unavailable'}),
          status: 503,
        ),
      );
      final repo = RealQuestionsRepository(dio: _dio(adapter));
      try {
        await repo.next(workspaceId: 'wsp_a');
        fail('expected QuestionGenerationUnavailableException');
      } on QuestionGenerationUnavailableException catch (e) {
        expect(e.retryAfterSeconds, 30);
      }
    });
  });

  group('RealQuestionsRepository.submitAnswer', () {
    test(
        'hits POST /api/v1/workspaces/{ws}/questions/{q}/answer with body',
        () async {
      final adapter = _FakeAdapter((opts) {
        return _json(jsonEncode({
          'question_id': 'qst_abc',
          'is_correct': true,
          'canonical_answer': 'B',
          'explanation': 'Chloroplasts contain chlorophyll.',
          'xp_earned': 15,
          'new_topic_mastery': 0.5,
          'new_overall_mastery': 0.4,
          'matched_hints': <String>[],
        }));
      });
      final repo = RealQuestionsRepository(dio: _dio(adapter));
      final feedback = await repo.submitAnswer(
        workspaceId: 'wsp_a',
        questionId: 'qst_abc',
        submission: const AnswerSubmission(
          answer: 'B',
          timeSpentSeconds: 12,
        ),
      );

      expect(adapter.lastRequest!.method, 'POST');
      expect(
        adapter.lastRequest!.path,
        '/api/v1/workspaces/wsp_a/questions/qst_abc/answer',
      );
      // Body should have been sent with the AnswerSubmission JSON.
      final sentBody = jsonDecode(
        utf8.decode(adapter.lastRequestBody!),
      ) as Map<String, dynamic>;
      expect(sentBody['answer'], 'B');
      expect(sentBody['time_spent_seconds'], 12);

      expect(feedback.isCorrect, isTrue);
      expect(feedback.xpEarned, 15);
      expect(feedback.canonicalAnswer, 'B');
    });

    test('404 → QuestionNotFoundException', () async {
      final adapter = _FakeAdapter(
        (opts) => _json(
          jsonEncode({'detail': 'gone'}),
          status: 404,
        ),
      );
      final repo = RealQuestionsRepository(dio: _dio(adapter));
      try {
        await repo.submitAnswer(
          workspaceId: 'wsp_a',
          questionId: 'qst_x',
          submission: const AnswerSubmission(answer: 'B'),
        );
        fail('expected QuestionNotFoundException');
      } on QuestionNotFoundException catch (e) {
        expect(e.message, contains('gone'));
      }
    });

    test('409 → QuestionNotAnswerableException', () async {
      final adapter = _FakeAdapter(
        (opts) => _json(
          jsonEncode({'detail': 'status=pending_review'}),
          status: 409,
        ),
      );
      final repo = RealQuestionsRepository(dio: _dio(adapter));
      try {
        await repo.submitAnswer(
          workspaceId: 'wsp_a',
          questionId: 'qst_x',
          submission: const AnswerSubmission(answer: 'B'),
        );
        fail('expected QuestionNotAnswerableException');
      } on QuestionNotAnswerableException catch (e) {
        expect(e.message, contains('pending_review'));
      }
    });
  });
}
