import 'package:dio/dio.dart';
import 'package:social_study_app/features/screen_time/data/screen_time_repository.dart';
import 'package:social_study_app/features/screen_time/models/screen_time_settings.dart';
import 'package:social_study_app/features/screen_time/models/screen_time_wallet.dart';

class RealScreenTimeRepository implements ScreenTimeRepository {
  RealScreenTimeRepository({required this.dio});

  final Dio dio;

  static const _apiPrefix = '/api/v1';

  @override
  Future<ScreenTimeSettings> fetchSettings({required String workspaceId}) async {
    final response = await dio.get<Map<String, dynamic>>(
      '$_apiPrefix/workspaces/$workspaceId/screen-time/settings',
    );
    return ScreenTimeSettings.fromJson(response.data!);
  }

  @override
  Future<ScreenTimeSettings> updateSettings({
    required String workspaceId,
    bool? enableBlocking,
    List<String>? blockedPackages,
    int? xpToMinuteRatio,
  }) async {
    final data = <String, dynamic>{};
    if (enableBlocking != null) data['enable_blocking'] = enableBlocking;
    if (blockedPackages != null) data['blocked_packages'] = blockedPackages;
    if (xpToMinuteRatio != null) data['xp_to_minute_ratio'] = xpToMinuteRatio;

    final response = await dio.put<Map<String, dynamic>>(
      '$_apiPrefix/workspaces/$workspaceId/screen-time/settings',
      data: data,
    );
    return ScreenTimeSettings.fromJson(response.data!);
  }

  @override
  Future<ScreenTimeWallet> fetchWallet({required String workspaceId}) async {
    final response = await dio.get<Map<String, dynamic>>(
      '$_apiPrefix/workspaces/$workspaceId/screen-time/wallet',
    );
    return ScreenTimeWallet.fromJson(response.data!);
  }

  @override
  Future<ScreenTimeWallet> consumeMinutes({
    required String workspaceId,
    required int minutes,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      '$_apiPrefix/workspaces/$workspaceId/screen-time/wallet/consume',
      data: {'minutes': minutes},
    );
    return ScreenTimeWallet.fromJson(response.data!);
  }

  @override
  Future<ScreenTimeWallet> syncXp({required String workspaceId}) async {
    final response = await dio.post<Map<String, dynamic>>(
      '$_apiPrefix/workspaces/$workspaceId/screen-time/wallet/sync-xp',
    );
    return ScreenTimeWallet.fromJson(response.data!);
  }

  @override
  Future<void> reportPermissionStatus({
    required bool overlayPermission,
    required bool usageAccessPermission,
    required bool notificationAccess,
    required bool accessibilityService,
    required bool batteryOptimizationExempt,
    required bool deviceAdministrator,
  }) async {
    await dio.post<void>(
      '$_apiPrefix/student/device/permission-status',
      data: {
        'overlay_permission': overlayPermission,
        'usage_access_permission': usageAccessPermission,
        'notification_access': notificationAccess,
        'accessibility_service': accessibilityService,
        'battery_optimization_exempt': batteryOptimizationExempt,
        'device_administrator': deviceAdministrator,
      },
    );
  }
}
