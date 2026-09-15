import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/screen_time/data/demo_screen_time_repository.dart';
import 'package:social_study_app/features/screen_time/data/real_screen_time_repository.dart';
import 'package:social_study_app/core/config/environment.dart';
import 'package:social_study_app/features/screen_time/models/screen_time_settings.dart';
import 'package:social_study_app/features/screen_time/models/screen_time_wallet.dart';
import 'package:social_study_app/features/screen_time/models/student_device_status.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/shared/services/dio_client.dart';

part 'screen_time_repository.g.dart';

abstract class ScreenTimeRepository {
  Future<ScreenTimeSettings> fetchSettings({required String workspaceId});

  Future<ScreenTimeSettings> updateSettings({
    required String workspaceId,
    bool? enableBlocking,
    List<String>? blockedPackages,
    int? xpToMinuteRatio,
  });

  Future<ScreenTimeWallet> fetchWallet({required String workspaceId});

  Future<ScreenTimeWallet> consumeMinutes({
    required String workspaceId,
    required int minutes,
  });

  Future<ScreenTimeWallet> syncXp({required String workspaceId});

  Future<List<StudentDeviceStatus>> fetchDeviceStatuses({
    required String workspaceId,
  });

  Future<void> reportPermissionStatus({
    required bool overlayPermission,
    required bool usageAccessPermission,
    required bool notificationAccess,
    required bool accessibilityService,
    required bool batteryOptimizationExempt,
    required bool deviceAdministrator,
  });
}

@Riverpod(keepAlive: true)
ScreenTimeRepository screenTimeRepository(ScreenTimeRepositoryRef ref) {
  final auth = ref.watch(authNotifierProvider);
  final isDemo = auth.valueOrNull?.maybeWhen(
        authenticated: (user) => _isDemoUser(user),
        orElse: () => false,
      ) ??
      false;

  if (isDemo) {
    return DemoScreenTimeRepository();
  }
  return RealScreenTimeRepository(dio: ref.read(dioClientProvider).dio);
}

bool _isDemoUser(User user) =>
    !Environment.useRealBackend &&
    (user.id == 'usr_demo_001' || user.email == 'demo@socialstudyapp.com');
