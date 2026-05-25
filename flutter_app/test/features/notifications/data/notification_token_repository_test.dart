import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/features/notifications/data/notification_token_repository.dart';
import 'package:social_study_app/shared/models/notification_token.dart';

class _MockDio extends Mock implements Dio {}

class _FakeRequestOptions extends Fake implements RequestOptions {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRequestOptions());
  });

  group('RealNotificationTokenRepository', () {
    late _MockDio dio;
    late RealNotificationTokenRepository repo;

    setUp(() {
      dio = _MockDio();
      repo = RealNotificationTokenRepository(dio: dio);
    });

    test('register POSTs the correct shape and parses the echo', () async {
      final stubbedResponse = Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: ''),
        statusCode: 201,
        data: {
          'installation_id': 'inst_a',
          'token': 'tok_a',
          'platform': 'android',
          'registered_at': '2026-05-23T10:00:00+00:00',
          'last_seen_at': '2026-05-24T10:00:00+00:00',
        },
      );
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => stubbedResponse);

      final result = await repo.register(
        installationId: 'inst_a',
        token: 'tok_a',
        platform: DevicePlatform.android,
      );

      // Echo decoded correctly.
      expect(result.installationId, 'inst_a');
      expect(result.token, 'tok_a');
      expect(result.platform, DevicePlatform.android);
      expect(result.registeredAt, '2026-05-23T10:00:00+00:00');
      expect(result.lastSeenAt, '2026-05-24T10:00:00+00:00');

      // POST shape: correct URL + JSON body.
      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured[0], '/api/v1/users/me/notification-tokens');
      expect(captured[1], {
        'installation_id': 'inst_a',
        'token': 'tok_a',
        'platform': 'android',
      });
    });

    test('register propagates DioException on failure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 500,
          ),
        ),
      );

      expect(
        () => repo.register(
          installationId: 'inst_a',
          token: 'tok_a',
          platform: DevicePlatform.android,
        ),
        throwsA(isA<DioException>()),
      );
    });

    test('delete DELETEs the right URL', () async {
      when(() => dio.delete<void>(any())).thenAnswer(
        (_) async => Response<void>(
          requestOptions: RequestOptions(path: ''),
          statusCode: 204,
        ),
      );

      await repo.delete(installationId: 'inst_a');

      verify(
        () => dio.delete<void>(
          '/api/v1/users/me/notification-tokens/inst_a',
        ),
      ).called(1);
    });
  });

  group('DemoNotificationTokenRepository', () {
    test('register echoes the input with a fresh timestamp', () async {
      const repo = DemoNotificationTokenRepository();
      final result = await repo.register(
        installationId: 'inst_a',
        token: 'tok_a',
        platform: DevicePlatform.android,
      );
      expect(result.installationId, 'inst_a');
      expect(result.token, 'tok_a');
      expect(result.platform, DevicePlatform.android);
      expect(result.registeredAt, isNotEmpty);
      expect(result.lastSeenAt, isNotEmpty);
    });

    test('delete is a no-op (completes without throwing)', () async {
      const repo = DemoNotificationTokenRepository();
      await expectLater(
        repo.delete(installationId: 'inst_a'),
        completes,
      );
    });
  });
}
