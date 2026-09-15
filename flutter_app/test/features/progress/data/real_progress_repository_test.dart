import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/features/progress/data/real_progress_repository.dart';
import 'package:social_study_app/shared/models/progress.dart';

/// In-process Dio adapter — same pattern as the other repository tests.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  RequestOptions? lastRequest;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return handler(options);
  }
}

ResponseBody _json(String body, {int status = 200}) => ResponseBody.fromString(
      body,
      status,
      headers: {
        'content-type': ['application/json'],
      },
    );

Dio _dio(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('RealProgressRepository.fetch', () {
    test('hits GET /api/v1/workspaces/{ws}/users/{uid}/progress', () async {
      final adapter = _FakeAdapter(
        (opts) => _json(jsonEncode({
          'level': 4,
          'total_xp': 720,
          'xp_into_level': 120,
          'xp_for_next_level': 300,
          'overall_mastery': 0.61,
          'topics': [
            {
              'topic_id': 'top_a',
              'topic_name': 'Photosynthesis',
              'mastery': 0.8,
              'attempts': 10,
              'success_rate': 0.7,
            },
          ],
          'recent_activity': [
            {
              'kind': 'question',
              'topic': 'Photosynthesis',
              'is_correct': true,
              'xp_earned': 25,
              'occurred_at': '2026-05-22T09:00:00Z',
            },
          ],
        })),
      );
      final repo = RealProgressRepository(dio: _dio(adapter));
      final progress = await repo.fetch(
        workspaceId: 'wsp_a',
        userId: 'usr_1',
      );

      expect(adapter.lastRequest!.method, 'GET');
      expect(
        adapter.lastRequest!.path,
        '/api/v1/workspaces/wsp_a/users/usr_1/progress',
      );
      expect(progress.level, 4);
      expect(progress.topics.single.topicName, 'Photosynthesis');
      expect(progress.recentActivity.single.kind, ActivityKind.question);
      expect(progress.recentActivity.single.isCorrect, isTrue);
    });

    test('404 → StudentProgress.empty (new student, not an error)', () async {
      final adapter = _FakeAdapter(
        (opts) => _json(jsonEncode({'detail': 'no progress yet'}), status: 404),
      );
      final repo = RealProgressRepository(dio: _dio(adapter));
      final progress = await repo.fetch(
        workspaceId: 'wsp_a',
        userId: 'usr_new',
      );
      expect(progress, StudentProgress.empty);
    });

    test('non-404 errors propagate', () async {
      final adapter = _FakeAdapter(
        (opts) => _json(jsonEncode({'detail': 'boom'}), status: 500),
      );
      final repo = RealProgressRepository(dio: _dio(adapter));
      expect(
        () => repo.fetch(workspaceId: 'wsp_a', userId: 'usr_1'),
        throwsA(isA<DioException>()),
      );
    });
  });
}
