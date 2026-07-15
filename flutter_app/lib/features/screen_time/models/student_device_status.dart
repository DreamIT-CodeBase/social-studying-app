class StudentDeviceStatus {
  const StudentDeviceStatus({
    required this.studentId,
    required this.displayName,
    required this.usageAccessPermission,
    required this.overlayPermission,
    required this.notificationAccess,
    required this.accessibilityService,
    required this.batteryOptimizationExempt,
    required this.lastReportedAt,
  });

  factory StudentDeviceStatus.fromJson(Map<String, dynamic> json) {
    return StudentDeviceStatus(
      studentId: json['student_id'] as String,
      displayName: json['display_name'] as String,
      usageAccessPermission:
          json['usage_access_permission'] as bool? ?? false,
      overlayPermission: json['overlay_permission'] as bool? ?? false,
      notificationAccess: json['notification_access'] as bool? ?? false,
      accessibilityService: json['accessibility_service'] as bool? ?? false,
      batteryOptimizationExempt:
          json['battery_optimization_exempt'] as bool? ?? false,
      lastReportedAt: json['last_reported_at'] == null
          ? null
          : DateTime.tryParse(json['last_reported_at'] as String),
    );
  }

  final String studentId;
  final String displayName;
  final bool usageAccessPermission;
  final bool overlayPermission;
  final bool notificationAccess;
  final bool accessibilityService;
  final bool batteryOptimizationExempt;
  final DateTime? lastReportedAt;

  bool get blockingReady => usageAccessPermission && accessibilityService;
}
