import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/features/flashcards/data/demo_flashcards_repository.dart';
import 'package:social_study_app/features/flashcards/data/real_flashcards_repository.dart';
import 'package:social_study_app/shared/models/flashcard.dart';

/// In-process Dio adapter — same pattern as the questions + documents
/// repository tests. Returns canned ResponseBody objects per request.
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

ResponseBody _json(String body, {int status = 200}) {
  return ResponseBody.fromString(
    body,
    status,
    headers: {
      'content-type': ['application/json'],
    },
  );
}

Dio _dio(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('RealFlashcardsRepository.next', () {
    test('hits POST /api/v1/workspaces/{ws}/flashcards/next', () async {
      final adapter = _FakeAdapter(
        (opts) => _json(
          jsonEncode({
            'id': 'fc_abc',
            'topic': 'Photosynthesis',
            'front': 'What pigment captures light?',
            'back': 'Chlorophyll.',
            'explanation': 'It absorbs red and blue light.',
          }),
        ),
      );
      final repo = RealFlashcardsRepository(dio: _dio(adapter));
      final card = await repo.next(workspaceId: 'wsp_a');

      expect(adapter.lastRequest!.method, 'POST');
      expect(
        adapter.lastRequest!.path,
        '/api/v1/workspaces/wsp_a/flashcards/next',
      );
      expect(card.id, 'fc_abc');
      expect(card.front, 'What pigment captures light?');
      expect(card.back, 'Chlorophyll.');
      expect(card.explanation, 'It absorbs red and blue light.');
    });

    test('parses a card with no explanation (defaults to empty)', () async {
      final adapter = _FakeAdapter(
        (opts) => _json(
          jsonEncode({
            'id': 'fc_abc',
            'topic': 'Genetics',
            'front': 'Define genotype.',
            'back': 'The inherited genetic code.',
            'explanation': '',
          }),
        ),
      );
      final repo = RealFlashcardsRepository(dio: _dio(adapter));
      final card = await repo.next(workspaceId: 'wsp_a');
      expect(card.explanation, isEmpty);
    });

    test('409 → NoFlashcardTopicsException with detail message', () async {
      final adapter = _FakeAdapter(
        (opts) => _json(
          jsonEncode({'detail': 'No topics — upload material first.'}),
          status: 409,
        ),
      );
      final repo = RealFlashcardsRepository(dio: _dio(adapter));
      try {
        await repo.next(workspaceId: 'wsp_a');
        fail('expected NoFlashcardTopicsException');
      } on NoFlashcardTopicsException catch (e) {
        expect(e.message, contains('upload material'));
      }
    });

    test('503 → FlashcardGenerationUnavailableException, Retry-After parsed',
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
      final repo = RealFlashcardsRepository(dio: _dio(adapter));
      try {
        await repo.next(workspaceId: 'wsp_a');
        fail('expected FlashcardGenerationUnavailableException');
      } on FlashcardGenerationUnavailableException catch (e) {
        expect(e.retryAfterSeconds, 45);
        expect(e.message, contains('try again'));
      }
    });

    test('503 with missing Retry-After defaults to 30 seconds', () async {
      final adapter = _FakeAdapter(
        (opts) => _json(
          jsonEncode({'detail': 'unavailable'}),
          status: 503,
        ),
      );
      final repo = RealFlashcardsRepository(dio: _dio(adapter));
      try {
        await repo.next(workspaceId: 'wsp_a');
        fail('expected FlashcardGenerationUnavailableException');
      } on FlashcardGenerationUnavailableException catch (e) {
        expect(e.retryAfterSeconds, 30);
      }
    });
  });

  group('RealFlashcardsRepository.rate', () {
    test('hits POST /api/v1/workspaces/{ws}/flashcards/{fc}/rate with body',
        () async {
      final adapter = _FakeAdapter(
        (opts) => _json(jsonEncode({
          'flashcard_id': 'fc_abc',
          'rating': 'medium',
          'rated_at': '2026-05-22T10:00:00+00:00',
        })),
      );
      final repo = RealFlashcardsRepository(dio: _dio(adapter));
      final response = await repo.rate(
        workspaceId: 'wsp_a',
        flashcardId: 'fc_abc',
        submission: const FlashcardRatingSubmission(
          rating: FlashcardRating.medium,
        ),
      );

      expect(adapter.lastRequest!.method, 'POST');
      expect(
        adapter.lastRequest!.path,
        '/api/v1/workspaces/wsp_a/flashcards/fc_abc/rate',
      );
      // The rating enum must serialize to its snake_case wire value.
      final sentBody = jsonDecode(
        utf8.decode(adapter.lastRequestBody!),
      ) as Map<String, dynamic>;
      expect(sentBody['rating'], 'medium');

      expect(response.flashcardId, 'fc_abc');
      expect(response.rating, FlashcardRating.medium);
      expect(response.ratedAt, '2026-05-22T10:00:00+00:00');
    });

    test('404 → FlashcardNotFoundException', () async {
      final adapter = _FakeAdapter(
        (opts) => _json(
          jsonEncode({'detail': 'gone'}),
          status: 404,
        ),
      );
      final repo = RealFlashcardsRepository(dio: _dio(adapter));
      try {
        await repo.rate(
          workspaceId: 'wsp_a',
          flashcardId: 'fc_x',
          submission: const FlashcardRatingSubmission(
            rating: FlashcardRating.easy,
          ),
        );
        fail('expected FlashcardNotFoundException');
      } on FlashcardNotFoundException catch (e) {
        expect(e.message, contains('gone'));
      }
    });

    test('409 → FlashcardNotRatableException', () async {
      final adapter = _FakeAdapter(
        (opts) => _json(
          jsonEncode({'detail': 'status=pending_review'}),
          status: 409,
        ),
      );
      final repo = RealFlashcardsRepository(dio: _dio(adapter));
      try {
        await repo.rate(
          workspaceId: 'wsp_a',
          flashcardId: 'fc_x',
          submission: const FlashcardRatingSubmission(
            rating: FlashcardRating.hard,
          ),
        );
        fail('expected FlashcardNotRatableException');
      } on FlashcardNotRatableException catch (e) {
        expect(e.message, contains('pending_review'));
      }
    });
  });
}
