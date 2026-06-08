import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/core/config/environment.dart';
import 'package:social_study_app/shared/models/notification_token.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/shared/services/dio_client.dart';

part 'notification_token_repository.g.dart';

/// Source-of-truth for the Sprint 5.7 notification-token endpoints.
///
/// The Flutter ``NotificationService`` calls into this repository on
/// every cold start to register / heartbeat the current FCM token,
/// and on explicit sign-out to delete it. The provider routes
/// between the real Dio impl and a no-op demo impl using the same
/// demo-user heuristic as every other feature.
abstract class NotificationTokenRepository {
  /// Register or heartbeat this device's FCM token. The backend
  /// upserts by ``installation_id``, so calling this on every cold
  /// start converges to one row per (user, install).
  Future<NotificationTokenResponse> register({
    required String installationId,
    required String token,
    required DevicePlatform platform,
  });

  /// Soft-delete on sign-out. Idempotent — a 204 comes back whether
  /// or not the row existed, and the repo surfaces that as
  /// ``Future<void>``.
  Future<void> delete({required String installationId});
}

/// Dio-backed implementation. Hits the Sprint 5.7 endpoints.
class RealNotificationTokenRepository implements NotificationTokenRepository {
  RealNotificationTokenRepository({required this.dio});

  final Dio dio;

  static const _apiPrefix = '/api/v1/users/me/notification-tokens';

  @override
  Future<NotificationTokenResponse> register({
    required String installationId,
    required String token,
    required DevicePlatform platform,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      _apiPrefix,
      data: NotificationTokenRegistration(
        installationId: installationId,
        token: token,
        platform: platform,
      ).toJson(),
    );
    return NotificationTokenResponse.fromJson(response.data!);
  }

  @override
  Future<void> delete({required String installationId}) async {
    await dio.delete<void>('$_apiPrefix/$installationId');
  }
}

/// Demo / dev impl. The demo user has no live backend to register
/// against, but the ``NotificationService`` startup path still tries
/// — so we accept the call and return a believable echo. The
/// ``delete`` path is a true no-op.
class DemoNotificationTokenRepository implements NotificationTokenRepository {
  const DemoNotificationTokenRepository();

  @override
  Future<NotificationTokenResponse> register({
    required String installationId,
    required String token,
    required DevicePlatform platform,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    return NotificationTokenResponse(
      installationId: installationId,
      token: token,
      platform: platform,
      registeredAt: now,
      lastSeenAt: now,
    );
  }

  @override
  Future<void> delete({required String installationId}) async {}
}

/// Routes between real (Dio → backend) and demo (no-op) based on the
/// authenticated user — same heuristic as every other repository.
@Riverpod(keepAlive: true)
NotificationTokenRepository notificationTokenRepository(
  NotificationTokenRepositoryRef ref,
) {
  final auth = ref.watch(authNotifierProvider);
  final isDemo = auth.valueOrNull?.maybeWhen(
        authenticated: (user) => _isDemoUser(user),
        orElse: () => false,
      ) ??
      false;
  if (isDemo) {
    return const DemoNotificationTokenRepository();
  }
  return RealNotificationTokenRepository(
    dio: ref.read(dioClientProvider).dio,
  );
}

// `!useRealBackend` so a `--dart-define=USE_REAL_BACKEND=true` build treats
// nobody as a demo user and routes every call to the Real* impl over Dio.
bool _isDemoUser(User user) =>
    !Environment.useRealBackend &&
    (user.id == 'usr_demo_001' || user.email == 'demo@socialstudyapp.com');
