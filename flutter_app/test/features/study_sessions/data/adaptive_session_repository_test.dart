import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/features/study_sessions/data/adaptive_session_repository.dart';
import 'package:social_study_app/features/study_sessions/domain/adaptive_session_models.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.response);

  final ResponseBody response;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      response;
}

Dio _dio(int status, String detail) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.httpClientAdapter = _FakeAdapter(
    ResponseBody.fromString(
      jsonEncode({'detail': detail}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    ),
  );
  return dio;
}

void main() {
  group('AdaptiveSessionRepository.prepare', () {
    test('marks material-processing conflicts as retryable', () async {
      final repository = AdaptiveSessionRepository(
        _dio(409, 'Wait for the latest source to finish processing.'),
      );

      expect(
        () => repository.prepare(
          workspaceId: 'wsp_self_1',
          mode: AdaptiveSessionMode.study,
        ),
        throwsA(
          isA<AdaptiveSessionException>()
              .having((error) => error.retryable, 'retryable', isTrue),
        ),
      );
    });

    test('does not retry conflicts requiring user action', () async {
      final repository = AdaptiveSessionRepository(
        _dio(409, 'Complete a study question first, then try again.'),
      );

      expect(
        () => repository.prepare(
          workspaceId: 'wsp_self_1',
          mode: AdaptiveSessionMode.flashcard,
        ),
        throwsA(
          isA<AdaptiveSessionException>()
              .having((error) => error.retryable, 'retryable', isFalse),
        ),
      );
    });

    test('marks temporary service failures as retryable', () async {
      final repository = AdaptiveSessionRepository(
        _dio(503, 'Study service is warming up.'),
      );

      expect(
        () => repository.prepare(
          workspaceId: 'wsp_self_1',
          mode: AdaptiveSessionMode.study,
        ),
        throwsA(
          isA<AdaptiveSessionException>()
              .having((error) => error.retryable, 'retryable', isTrue),
        ),
      );
    });
  });
}
