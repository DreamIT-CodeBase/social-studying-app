import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/core/config/environment.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/shared/services/dio_client.dart';

part 'telemetry_repository.g.dart';

abstract class TelemetryRepository {
  Future<void> sendEvents(List<Map<String, dynamic>> events);
}

class DemoTelemetryRepository implements TelemetryRepository {
  @override
  Future<void> sendEvents(List<Map<String, dynamic>> events) async {
    // offline/demo mode fallback: simply print to console for inspection
    print('[TELEMETRY DEMO] Buffered ${events.length} events:');
    for (final ev in events) {
      print('  - Event: ${ev['event_type']}, Details: ${ev['details']}, Time: ${ev['occurred_at']}');
    }
  }
}

class RealTelemetryRepository implements TelemetryRepository {
  RealTelemetryRepository({required this.dio});
  final Dio dio;

  @override
  Future<void> sendEvents(List<Map<String, dynamic>> events) async {
    try {
      await dio.post(
        '/api/v1/student/device/db-stats',
        data: {'events': events},
      );
    } catch (e) {
      // Swallowed to prevent client-side impact from telemetry network issues
      print('[TELEMETRY ERROR] Failed to send telemetry: $e');
    }
  }
}

@Riverpod(keepAlive: true)
TelemetryRepository telemetryRepository(TelemetryRepositoryRef ref) {
  final auth = ref.watch(authNotifierProvider);
  final isDemo = auth.valueOrNull?.maybeWhen(
        authenticated: (user) => _isDemoUser(user),
        orElse: () => false,
      ) ??
      false;

  if (isDemo) {
    return DemoTelemetryRepository();
  }
  return RealTelemetryRepository(dio: ref.read(dioClientProvider).dio);
}

bool _isDemoUser(User user) =>
    !Environment.useRealBackend &&
    (user.id == 'usr_demo_001' || user.email == 'demo@socialstudyapp.com');
