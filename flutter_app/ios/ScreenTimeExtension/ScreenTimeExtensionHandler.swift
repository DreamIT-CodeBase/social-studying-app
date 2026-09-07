import Foundation
import DeviceActivity
import ManagedSettings
import FamilyControls

// MARK: - DeviceActivityMonitorExtension
//
// This extension runs in its own process. iOS keeps it alive even after the
// main app is killed, so it can re-apply ManagedSettings shields whenever a
// DeviceActivity time window starts or ends.
//
// IMPORTANT: This file must be in a separate Extension target in Xcode:
//   File → New → Target → Device Activity Monitor Extension
//   Product Name: ScreenTimeExtension
//   Team + Bundle: ai.socialstudying.app.ScreenTimeExtension
//   App Group: group.ai.socialstudying.app.screentime

@available(iOS 16.0, *)
class ScreenTimeExtensionHandler: DeviceActivityMonitorExtension {

  // The named store MUST match the one used in ScreenTimeManager.swift.
  private let store = ManagedSettingsStore(
    named: .init("ai.socialstudying.screentime")
  )

  private let appGroupIdentifier = "group.ai.socialstudying.app.screentime"
  private let selectionStorageKey = "saved_family_activity_selection"
  private let blockingEnabledKey  = "is_screen_time_blocking_enabled"
  private let availableMinutesKey = "cached_available_minutes"

  private var userDefaults: UserDefaults {
    UserDefaults(suiteName: appGroupIdentifier) ?? UserDefaults.standard
  }

  // Called when a DeviceActivity interval STARTS (blocking period begins).
  override func intervalDidStart(for activity: DeviceActivityName) {
    super.intervalDidStart(for: activity)
    applyShields()
  }

  // Called when a DeviceActivity interval ENDS (blocking period ends).
  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)
    // Re-read from shared prefs; the main app may have updated minutes.
    let minutes = userDefaults.integer(forKey: availableMinutesKey)
    let enabled = userDefaults.bool(forKey: blockingEnabledKey)
    if enabled && minutes <= 0 {
      applyShields()
    } else {
      clearShields()
    }
  }

  // Called when screen time for an event exceeds a threshold.
  override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
    super.eventDidReachThreshold(event, activity: activity)
    applyShields()
  }

  // Called when the DeviceActivity warning threshold is reached.
  override func intervalWillStartWarning(for activity: DeviceActivityName) {
    super.intervalWillStartWarning(for: activity)
    // No-op: shields activate at intervalDidStart.
  }

  // MARK: - Shield Management

  private func applyShields() {
    let enabled = userDefaults.bool(forKey: blockingEnabledKey)
    guard enabled else {
      clearShields()
      return
    }

    if let selection = loadSelection(), hasContent(selection) {
      store.shield.applications = selection.applicationTokens.isEmpty
        ? nil : selection.applicationTokens
      store.shield.webDomains = selection.webDomainTokens.isEmpty
        ? nil : selection.webDomainTokens
      if !selection.categoryTokens.isEmpty {
        store.shield.applicationCategories = .specific(selection.categoryTokens)
      } else {
        // Default: shield entire Social Networking category when minutes = 0
        store.shield.applicationCategories = .specific([.socialNetworking])
      }
    } else {
      // No apps explicitly selected — shield social networking category by default
      store.shield.applicationCategories = .specific([.socialNetworking])
    }
  }

  private func clearShields() {
    store.shield.applications = nil
    store.shield.applicationCategories = nil
    store.shield.webDomains = nil
  }

  private func loadSelection() -> FamilyActivitySelection? {
    guard let data = userDefaults.data(forKey: selectionStorageKey) else { return nil }
    return try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
  }

  private func hasContent(_ selection: FamilyActivitySelection) -> Bool {
    !selection.applicationTokens.isEmpty ||
    !selection.categoryTokens.isEmpty    ||
    !selection.webDomainTokens.isEmpty
  }
}
