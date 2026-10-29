import os

pbx_path = "ios/Runner.xcodeproj/project.pbxproj"
if not os.path.exists(pbx_path) and os.path.exists("Runner.xcodeproj/project.pbxproj"):
    pbx_path = "Runner.xcodeproj/project.pbxproj"

if os.path.exists(pbx_path):
    with open(pbx_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # Remove the Embed App Extensions build phase from Runner target
    target1 = "\t\t\t\tSTX50000000000000000001 /* Embed App Extensions */,\n"
    # Remove the ScreenTimeExtension, ShieldConfigurationExtension, and ShieldActionExtension target dependencies
    dep_targets = [
        "\t\t\t\tSTXD0000000000000000001 /* PBXTargetDependency */,\n",
        "\t\t\t\tSCXD0000000000000000001 /* PBXTargetDependency */,\n",
        "\t\t\t\tSAXD0000000000000000001 /* PBXTargetDependency */,\n",
    ]
    
    # Also handle CRLF if on Windows
    content = content.replace(target1, "").replace(target1.replace("\n", "\r\n"), "")
    for dep in dep_targets:
        content = content.replace(dep, "").replace(dep.replace("\n", "\r\n"), "")
    
    with open(pbx_path, "w", encoding="utf-8") as f:
        f.write(content)
    print("Cleanly removed ScreenTime, ShieldConfiguration, and ShieldAction extensions from Runner target for admin build.")
else:
    print(f"File not found: {pbx_path}")

# Replace ScreenTimeManager.swift with a no-op stub for admin flavor to avoid linking Screen Time frameworks
stm_paths = ["ios/Runner/ScreenTimeManager.swift", "Runner/ScreenTimeManager.swift", "flutter_app/ios/Runner/ScreenTimeManager.swift"]
stm_path = next((p for p in stm_paths if os.path.exists(p)), None)

if stm_path:
    dummy_code = '''import Flutter
import Foundation
import UIKit
import UserNotifications

// Stub ScreenTimeManager for admin build - does not import or link Screen Time frameworks
@objc class ScreenTimeManager: NSObject {
  @objc static let shared = ScreenTimeManager()

  let appGroupIdentifier = "group.ai.socialstudying.app.screentime"
  let selectionStorageKey = "saved_family_activity_selection"
  let blockingEnabledKey  = "is_screen_time_blocking_enabled"
  let availableMinutesKey = "cached_available_minutes"
  let consumedTodayKey    = "ios_consumed_today_minutes"
  let shieldsActiveKey    = "shields_are_active"
  let lastShieldApplyKey  = "last_shield_apply_timestamp"
  let trackingStartKey    = "foreground_tracking_start_time"
  let lastDeductionKey    = "last_deduction_timestamp"

  var userDefaults: UserDefaults {
    return UserDefaults.standard
  }

  func isAuthorized() -> Bool {
    return false
  }

  func authorizationStatusString() -> String {
    return "notDetermined"
  }

  func requestAuthorization(completion: @escaping (Bool, String?) -> Void) {
    completion(false, nil)
  }

  func presentAppPicker(completion: @escaping (Bool, String?) -> Void) {
    completion(false, nil)
  }

  func hasSelectedApps() -> Bool {
    return false
  }

  func reapplyShields() {}

  func startForegroundTracking() {}

  func stopForegroundTracking() {}

  func syncScreenTimeBalance(availableMinutes: Int, enableBlocking: Bool) {}

  func getConsumedToday() -> Int {
    return 0
  }

  func setConsumedToday(_ minutes: Int) {}

  func areShieldsActive() -> Bool {
    return false
  }

  func sendExhaustedNotification() {}
}
'''
    with open(stm_path, "w", encoding="utf-8") as f:
        f.write(dummy_code)
    print(f"Replaced {stm_path} with stub ScreenTimeManager for admin build.")
