import Foundation
import DeviceActivity
import ManagedSettings
import FamilyControls

@available(iOS 16.0, *)
extension DeviceActivityName {
  static let dailyMonitoring = DeviceActivityName("ai.socialstudying.screentime.daily")
}

@available(iOS 16.0, *)
extension DeviceActivityEvent.Name {
  static let socialTimeExhausted = DeviceActivityEvent.Name("ai.socialstudying.screentime.exhausted")
}

// MARK: - ScreenTimeExtensionHandler
//
// This extension runs in its own process. iOS keeps it alive even after the
// main app is killed, so it can enforce ManagedSettings shields whenever a
// DeviceActivity time threshold is reached or schedule interval starts.
//
// It uses a named ManagedSettingsStore that persists independently of the
// main app process, so shields survive app termination.

@available(iOS 16.0, *)
class ScreenTimeExtensionHandler: DeviceActivityMonitor {

  // The named store MUST match the one used in ScreenTimeManager.swift.
  private let store = ManagedSettingsStore(
    named: ManagedSettingsStore.Name("ai.socialstudying.screentime")
  )

  let appGroupIdentifier = "group.ai.socialstudying.app.screentime"
  let selectionStorageKey = "saved_family_activity_selection"
  let blockingEnabledKey  = "is_screen_time_blocking_enabled"
  let availableMinutesKey = "cached_available_minutes"

  var userDefaults: UserDefaults {
    UserDefaults(suiteName: appGroupIdentifier) ?? UserDefaults.standard
  }

  // Called when a DeviceActivity interval STARTS.
  override func intervalDidStart(for activity: DeviceActivityName) {
    let minutes = userDefaults.integer(forKey: availableMinutesKey)
    if minutes <= 0 {
      applyShields()
    }
  }

  // Called when a DeviceActivity interval ENDS.
  override func intervalDidEnd(for activity: DeviceActivityName) {
    let minutes = userDefaults.integer(forKey: availableMinutesKey)
    if minutes <= 0 {
      applyShields()
    }
  }

  // Called when screen time for an event exceeds a threshold.
  override func eventDidReachThreshold(
    _ event: DeviceActivityEvent.Name,
    activity: DeviceActivityName
  ) {
    // 1. Mark remaining minutes as 0 in shared App Group
    userDefaults.set(0, forKey: availableMinutesKey)
    userDefaults.synchronize()

    // 2. Lock apps immediately
    applyShields()
  }

  // MARK: - Shield Management

  private func applyShields() {
    let enabled = (userDefaults.object(forKey: blockingEnabledKey) as? Bool) ?? true
    guard enabled else {
      store.shield.applications = nil
      store.shield.applicationCategories = nil
      store.shield.webDomains = nil
      return
    }

    guard let data = userDefaults.data(forKey: selectionStorageKey),
          let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) else {
      return
    }

    store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
    store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
    store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
  }
}
