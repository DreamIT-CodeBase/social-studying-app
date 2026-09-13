import Foundation
import DeviceActivity
import ManagedSettings
import FamilyControls
import UserNotifications

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
  let consumedTodayKey    = "ios_consumed_today_minutes"
  let shieldsActiveKey    = "shields_are_active"
  let lastShieldApplyKey  = "last_shield_apply_timestamp"

  var userDefaults: UserDefaults {
    UserDefaults(suiteName: appGroupIdentifier) ?? UserDefaults.standard
  }

  // MARK: - Interval Lifecycle

  // Called when a DeviceActivity interval STARTS.
  override func intervalDidStart(for activity: DeviceActivityName) {
    super.intervalDidStart(for: activity)
    guard activity == .dailyMonitoring else { return }
    NSLog("[ScreenTimeExt] intervalDidStart — checking shield state")
    enforceShieldsIfNeeded()
  }

  // Called when a DeviceActivity interval ENDS.
  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)
    guard activity == .dailyMonitoring else { return }
    NSLog("[ScreenTimeExt] intervalDidEnd — re-applying shields")
    // When a daily interval ends, re-apply shields so they persist
    // into the next day until fresh study minutes are recorded.
    enforceShieldsIfNeeded()
  }

  // Called ~5 minutes before the interval starts (iOS 16+).
  override func intervalWillStartWarning(for activity: DeviceActivityName) {
    super.intervalWillStartWarning(for: activity)
    guard activity == .dailyMonitoring else { return }
    NSLog("[ScreenTimeExt] intervalWillStartWarning — pre-applying shields")
    enforceShieldsIfNeeded()
  }

  // Called ~5 minutes before the interval ends.
  override func intervalWillEndWarning(for activity: DeviceActivityName) {
    super.intervalWillEndWarning(for: activity)
    guard activity == .dailyMonitoring else { return }
    NSLog("[ScreenTimeExt] intervalWillEndWarning — ensuring shields persist")
    enforceShieldsIfNeeded()
  }

  // MARK: - Event Threshold

  // Called when screen time for an event exceeds a threshold.
  // This is the PRIMARY enforcement trigger — fires when cumulative
  // usage of selected apps reaches the `availableMinutes` threshold.
  override func eventDidReachThreshold(
    _ event: DeviceActivityEvent.Name,
    activity: DeviceActivityName
  ) {
    super.eventDidReachThreshold(event, activity: activity)
    guard activity == .dailyMonitoring, event == .socialTimeExhausted else {
      return
    }
    NSLog("[ScreenTimeExt] eventDidReachThreshold — TIME EXHAUSTED, locking apps")

    // 1. Mark remaining minutes as 0 in shared App Group
    userDefaults.set(0, forKey: availableMinutesKey)

    // 2. Record that shields are active (for Flutter UI feedback)
    userDefaults.set(true, forKey: shieldsActiveKey)
    userDefaults.set(Date().timeIntervalSince1970, forKey: lastShieldApplyKey)
    userDefaults.synchronize()

    // 3. Lock apps immediately
    applyShields()

    // 4. Send notification alerting the student
    sendExhaustedNotification()
  }

  // Called ~5 minutes before threshold is reached.
  override func eventWillReachThresholdWarning(
    _ event: DeviceActivityEvent.Name,
    activity: DeviceActivityName
  ) {
    super.eventWillReachThresholdWarning(event, activity: activity)
    guard activity == .dailyMonitoring, event == .socialTimeExhausted else {
      return
    }
    NSLog("[ScreenTimeExt] eventWillReachThresholdWarning — time almost up")
    // We don't block yet, but ensure everything is ready for immediate
    // enforcement when the threshold fires.
  }

  // MARK: - Shield Management

  /// Check available minutes and apply/clear shields accordingly.
  private func enforceShieldsIfNeeded() {
    let minutes = userDefaults.integer(forKey: availableMinutesKey)
    let enabled = (userDefaults.object(forKey: blockingEnabledKey) as? Bool) ?? true

    if !enabled {
      clearShields()
      userDefaults.set(false, forKey: shieldsActiveKey)
      userDefaults.synchronize()
      return
    }

    if minutes <= 0 {
      NSLog("[ScreenTimeExt] enforceShieldsIfNeeded — minutes=%d, applying shields", minutes)
      let wasActive = userDefaults.bool(forKey: shieldsActiveKey)
      applyShields()
      userDefaults.set(true, forKey: shieldsActiveKey)
      userDefaults.set(Date().timeIntervalSince1970, forKey: lastShieldApplyKey)
      userDefaults.synchronize()
      if !wasActive {
        sendExhaustedNotification()
      }
    }
  }

  private func sendExhaustedNotification() {
    let content = UNMutableNotificationContent()
    content.title = "Time's Up!"
    content.body = "You have consumed your all time for social media."
    content.sound = .default

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    let request = UNNotificationRequest(
      identifier: "ai.socialstudying.screentime.exhausted",
      content: content,
      trigger: trigger
    )
    UNUserNotificationCenter.current().add(request) { error in
      if let error = error {
        NSLog("[ScreenTimeExt] Failed to schedule exhausted notification: %@", error.localizedDescription)
      } else {
        NSLog("[ScreenTimeExt] Exhausted notification scheduled successfully")
      }
    }
  }

  private func applyShields() {
    let enabled = (userDefaults.object(forKey: blockingEnabledKey) as? Bool) ?? true
    guard enabled else {
      clearShields()
      return
    }

    guard let data = userDefaults.data(forKey: selectionStorageKey),
          let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) else {
      NSLog("[ScreenTimeExt] applyShields — no saved selection, ensuring shields are cleared")
      clearShields()
      userDefaults.set(false, forKey: shieldsActiveKey)
      userDefaults.synchronize()
      return
    }

    let hasApps = !selection.applicationTokens.isEmpty
    let hasWebs = !selection.webDomainTokens.isEmpty

    guard hasApps || hasWebs else {
      NSLog("[ScreenTimeExt] applyShields — selection has no apps or webs, ensuring shields are cleared")
      clearShields()
      userDefaults.set(false, forKey: shieldsActiveKey)
      userDefaults.synchronize()
      return
    }

    store.shield.applications =
      hasApps ? selection.applicationTokens : nil
    // Exclusively shield specific apps and domains. Do not apply blanket categories
    // so alarms, home security, and system utilities remain safe.
    store.shield.applicationCategories = nil
    store.shield.webDomains =
      hasWebs ? selection.webDomainTokens : nil
    store.shield.webDomainCategories = nil

    NSLog("[ScreenTimeExt] applyShields — shields APPLIED (apps=%d, webs=%d)",
          selection.applicationTokens.count,
          selection.webDomainTokens.count)
  }

  private func clearShields() {
    store.shield.applications = nil
    store.shield.applicationCategories = nil
    store.shield.webDomains = nil
    store.shield.webDomainCategories = nil
    NSLog("[ScreenTimeExt] clearShields — all shields removed")
  }
}
