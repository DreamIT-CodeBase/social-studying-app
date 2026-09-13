import Flutter
import Foundation
import UIKit
import UserNotifications

#if canImport(FamilyControls)
import FamilyControls
#endif

#if canImport(ManagedSettings)
import ManagedSettings
#endif

#if canImport(DeviceActivity)
import DeviceActivity
#endif

#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(DeviceActivity)
@available(iOS 16.0, *)
extension DeviceActivityName {
  static let dailyMonitoring = DeviceActivityName("ai.socialstudying.screentime.daily")
}

@available(iOS 16.0, *)
extension DeviceActivityEvent.Name {
  static let socialTimeExhausted = DeviceActivityEvent.Name("ai.socialstudying.screentime.exhausted")
}
#endif

// MARK: - ScreenTimeManager

@objc class ScreenTimeManager: NSObject {
  @objc static let shared = ScreenTimeManager()

  // Shared with the DeviceActivityMonitor extension via App Group.
  let appGroupIdentifier = "group.ai.socialstudying.app.screentime"
  let selectionStorageKey = "saved_family_activity_selection"
  let blockingEnabledKey  = "is_screen_time_blocking_enabled"
  let availableMinutesKey = "cached_available_minutes"
  let consumedTodayKey    = "ios_consumed_today_minutes"
  let shieldsActiveKey    = "shields_are_active"
  let lastShieldApplyKey  = "last_shield_apply_timestamp"
  let trackingStartKey    = "foreground_tracking_start_time"
  let lastDeductionKey    = "last_deduction_timestamp"

  // Named store — MUST match the name used in the DeviceActivityMonitor
  // extension. It keeps the policy active when the Flutter process exits.
  @available(iOS 16.0, *)
  private var managedStore: ManagedSettingsStore {
    #if canImport(ManagedSettings)
    return ManagedSettingsStore(named: .init("ai.socialstudying.screentime"))
    #else
    fatalError("ManagedSettings not available")
    #endif
  }

  var userDefaults: UserDefaults {
    UserDefaults(suiteName: appGroupIdentifier) ?? UserDefaults.standard
  }

  // Foreground usage tracking timer — decrements available minutes
  // while the app is in the foreground and a blocked app was recently used.
  private var usageTrackingTimer: Timer?
  private var isTrackingUsage = false

  private override init() {
    super.init()
  }

  // MARK: - Authorization

  func isAuthorized() -> Bool {
    if #available(iOS 16.0, *) {
      #if canImport(FamilyControls)
      return AuthorizationCenter.shared.authorizationStatus == .approved
      #else
      return false
      #endif
    }
    return false
  }

  /// Returns a string representation of the current authorization status for
  /// the Flutter layer to display appropriate UI.
  @objc func authorizationStatusString() -> String {
    if #available(iOS 16.0, *) {
      #if canImport(FamilyControls)
      switch AuthorizationCenter.shared.authorizationStatus {
      case .approved:       return "approved"
      case .denied:         return "denied"
      case .notDetermined:  return "notDetermined"
      @unknown default:     return "notDetermined"
      }
      #else
      return "unavailable"
      #endif
    }
    return "unavailable"
  }

  func requestAuthorization(completion: @escaping (Bool, String?) -> Void) {
    if #available(iOS 16.0, *) {
      #if canImport(FamilyControls)
      Task { @MainActor in
        do {
          try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
          let approved = AuthorizationCenter.shared.authorizationStatus == .approved
          completion(approved, nil)
        } catch {
          let msg = "Screen Time authorization was not approved. Please try again and authenticate with Face ID or Touch ID.\n\nOriginal error: \(error.localizedDescription)"
          completion(false, msg)
        }
      }
      #else
      completion(false, "FamilyControls framework is not available on this build.")
      #endif
    } else {
      completion(false, "Apple Screen Time API requires iOS 16.0 or later.")
    }
  }

  // MARK: - Selection & App Picker

  func hasSelectedApps() -> Bool {
    if #available(iOS 16.0, *) {
      #if canImport(FamilyControls)
      if let selection = loadSelection() {
        return !selection.applicationTokens.isEmpty ||
               !selection.webDomainTokens.isEmpty
      }
      #endif
    }
    return false
  }

  #if canImport(FamilyControls)
  @available(iOS 16.0, *)
  func loadSelection() -> FamilyActivitySelection? {
    guard let data = userDefaults.data(forKey: selectionStorageKey) else { return nil }
    return try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
  }

  @available(iOS 16.0, *)
  func saveSelection(_ selection: FamilyActivitySelection) {
    if let data = try? PropertyListEncoder().encode(selection) {
      userDefaults.set(data, forKey: selectionStorageKey)
      userDefaults.synchronize()
    }
  }
  #endif

  func presentAppPicker(completion: @escaping (Bool, String?) -> Void) {
    if #available(iOS 16.0, *) {
      #if canImport(FamilyControls) && canImport(SwiftUI)
      guard isAuthorized() else {
        completion(false, "Screen Time authorization must be granted before selecting apps.")
        return
      }

      DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        guard let rootVC = self.findTopViewController() else {
          completion(false, "Could not find top view controller to present picker.")
          return
        }

        let initialSelection = self.loadSelection() ?? FamilyActivitySelection()
        let pickerView = FamilyPickerContainerView(
          initialSelection: initialSelection,
          onDismiss: { updatedSelection in
            self.saveSelection(updatedSelection)
            self.reapplyShields()
            completion(true, nil)
          }
        )

        let hostingController = UIHostingController(rootView: pickerView)
        hostingController.modalPresentationStyle = .pageSheet
        rootVC.present(hostingController, animated: true)
      }
      #else
      completion(false, "FamilyActivityPicker is not available on this build.")
      #endif
    } else {
      completion(false, "FamilyActivityPicker requires iOS 16.0 or later.")
    }
  }

  // MARK: - Shield Enforcement

  /// Called from Flutter (syncScreenTimeBalance) AND from AppDelegate.applicationDidBecomeActive.
  /// Stores state in the shared App Group so the DeviceActivityMonitor extension
  /// can also call reapplyShields() in the background.
  func syncScreenTimeBalance(availableMinutes: Int, enableBlocking: Bool) {
    userDefaults.set(enableBlocking,    forKey: blockingEnabledKey)
    userDefaults.set(availableMinutes,  forKey: availableMinutesKey)
    userDefaults.synchronize()

    NSLog("[ScreenTimeManager] syncScreenTimeBalance — available=%d, blocking=%@",
          availableMinutes, enableBlocking ? "YES" : "NO")

    if #available(iOS 16.0, *) {
      #if canImport(ManagedSettings) && canImport(FamilyControls)
      applyShieldsInternal(availableMinutes: availableMinutes, enableBlocking: enableBlocking)
      #endif
    }
  }

  /// Re-reads persisted state from UserDefaults and re-applies shields.
  /// Safe to call from AppDelegate, scene delegate, and the extension.
  @objc func reapplyShields() {
    let minutes = userDefaults.integer(forKey: availableMinutesKey)
    let enabled = (userDefaults.object(forKey: blockingEnabledKey) as? Bool) ?? true

    NSLog("[ScreenTimeManager] reapplyShields — available=%d, blocking=%@",
          minutes, enabled ? "YES" : "NO")

    if #available(iOS 16.0, *) {
      #if canImport(ManagedSettings) && canImport(FamilyControls)
      applyShieldsInternal(availableMinutes: minutes, enableBlocking: enabled)
      #endif
    }
  }

  @available(iOS 16.0, *)
  private func applyShieldsInternal(availableMinutes: Int, enableBlocking: Bool) {
    #if canImport(ManagedSettings) && canImport(FamilyControls)
    let store = managedStore

    guard enableBlocking else {
      clearShieldsAndStopMonitoring(from: store)
      userDefaults.set(false, forKey: shieldsActiveKey)
      userDefaults.synchronize()
      return
    }

    let selection = loadSelection()
    let hasCustomSelection = selection != nil && hasSelectedApps()

    // Safety guard: only enforce restrictions if user or admin has explicitly selected apps/categories.
    // Never apply blanket system-wide shields to an unconfigured device.
    guard let selection = selection, hasCustomSelection else {
      clearShieldsAndStopMonitoring(from: store)
      userDefaults.set(false, forKey: shieldsActiveKey)
      userDefaults.synchronize()
      return
    }

    if availableMinutes <= 0 {
      // Time exhausted — stop monitoring and apply shields immediately to selected apps only
      NSLog("[ScreenTimeManager] TIME EXHAUSTED — applying shields to selected apps NOW")
      #if canImport(DeviceActivity)
      DeviceActivityCenter().stopMonitoring([.dailyMonitoring])
      #endif

      applyShields(selection, to: store)

      let wasActive = userDefaults.bool(forKey: shieldsActiveKey)
      userDefaults.set(true, forKey: shieldsActiveKey)
      userDefaults.set(Date().timeIntervalSince1970, forKey: lastShieldApplyKey)
      userDefaults.synchronize()

      let lastNotif = userDefaults.double(forKey: "last_exhausted_notification_timestamp")
      let now = Date().timeIntervalSince1970
      if !wasActive || (now - lastNotif > 60) {
        userDefaults.set(now, forKey: "last_exhausted_notification_timestamp")
        sendExhaustedNotification()
      }
    } else {
      // Time available — remove shields and schedule threshold monitoring
      clearShields(from: store)
      userDefaults.set(false, forKey: shieldsActiveKey)
      userDefaults.synchronize()

      #if canImport(DeviceActivity)
      let schedule = DeviceActivitySchedule(
        intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
        intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
        repeats: true,
        warningTime: DateComponents(minute: 5)
      )
      let event = DeviceActivityEvent(
        applications: selection.applicationTokens,
        categories: selection.categoryTokens,
        webDomains: selection.webDomainTokens,
        threshold: DateComponents(minute: max(1, availableMinutes))
      )
      do {
        let center = DeviceActivityCenter()
        // A monitor cannot be overwritten in-place. Stop the previous monitor
        // before starting a new one so newly earned minutes update its threshold.
        center.stopMonitoring([.dailyMonitoring])
        try center.startMonitoring(
          .dailyMonitoring,
          during: schedule,
          events: [.socialTimeExhausted: event]
        )
        NSLog("[ScreenTimeManager] DeviceActivity monitoring started — threshold=%d min", availableMinutes)
      } catch {
        NSLog("[ScreenTimeManager] Failed to start DeviceActivity monitoring: %@", error.localizedDescription)
        // Fallback: if monitoring fails and minutes are low, apply shields defensively
        if availableMinutes <= 1 {
          applyShields(selection, to: store)
          userDefaults.set(true, forKey: shieldsActiveKey)
          userDefaults.synchronize()
        }
      }
      #endif
    }
    #endif
  }

  @available(iOS 16.0, *)
  private func applyShields(
    _ selection: FamilyActivitySelection,
    to store: ManagedSettingsStore
  ) {
    store.shield.applications =
      selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
    store.shield.webDomains =
      selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    // CRITICAL: We explicitly set applicationCategories to nil. Category-wide shielding
    // caused home security (Ring, ADT, Nest), alarm clocks, and utilities to be blocked.
    // By shielding only specific applicationTokens and webDomainTokens, alarms and
    // security systems remain 100% untouched and safe.
    store.shield.applicationCategories = nil
    store.shield.webDomainCategories = nil
  }

  @available(iOS 16.0, *)
  private func clearShields(from store: ManagedSettingsStore) {
    store.shield.applications = nil
    store.shield.applicationCategories = nil
    store.shield.webDomains = nil
    store.shield.webDomainCategories = nil
  }

  @available(iOS 16.0, *)
  private func clearShieldsAndStopMonitoring(from store: ManagedSettingsStore) {
    clearShields(from: store)
    #if canImport(DeviceActivity)
    DeviceActivityCenter().stopMonitoring([.dailyMonitoring])
    #endif
  }

  // MARK: - Foreground Usage Tracking
  //
  // iOS does not allow apps to monitor foreground usage of other apps the
  // way Android's Accessibility Service does. The DeviceActivityMonitor
  // extension handles background enforcement.
  //
  // This timer runs ONLY while the Social Study app itself is foregrounded.
  // Every 60 seconds it checks whether shields should be re-applied and
  // decrements available minutes based on the extension's tracking.
  // The primary purpose is to keep the Flutter UI meter updated.

  @objc func startForegroundTracking() {
    guard usageTrackingTimer == nil else { return }
    NSLog("[ScreenTimeManager] startForegroundTracking")

    // Immediately sync state
    reapplyShields()
    syncConsumedFromActivity()

    // Start a timer that ticks every 30 seconds
    usageTrackingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
      guard let self = self else { return }
      self.syncConsumedFromActivity()
      self.reapplyShields()
    }
  }

  @objc func stopForegroundTracking() {
    NSLog("[ScreenTimeManager] stopForegroundTracking")
    usageTrackingTimer?.invalidate()
    usageTrackingTimer = nil
  }

  /// Reads the current available minutes from shared UserDefaults (which the
  /// DeviceActivity extension may have set to 0) and computes consumed minutes
  /// for the Flutter UI to display.
  private func syncConsumedFromActivity() {
    let originalAvailable = userDefaults.integer(forKey: availableMinutesKey)
    let shieldsActive = userDefaults.bool(forKey: shieldsActiveKey)

    // If the extension has set available to 0 and shields are active,
    // the user's time is fully consumed.
    if shieldsActive && originalAvailable <= 0 {
      NSLog("[ScreenTimeManager] syncConsumedFromActivity — shields active, time fully consumed")
    }
  }

  // MARK: - Consumed Minutes API (for Flutter)

  /// Returns the current consumed-today value from App Group UserDefaults.
  @objc func getConsumedToday() -> Int {
    return userDefaults.integer(forKey: consumedTodayKey)
  }

  /// Sets consumed-today in the App Group UserDefaults (called from Flutter
  /// after it computes consumption from its own wallet delta tracking).
  @objc func setConsumedToday(_ minutes: Int) {
    userDefaults.set(minutes, forKey: consumedTodayKey)
    userDefaults.synchronize()
  }

  /// Returns whether shields are currently active (blocking apps).
  @objc func areShieldsActive() -> Bool {
    return userDefaults.bool(forKey: shieldsActiveKey)
  }

  // MARK: - Helpers

  @objc func sendExhaustedNotification() {
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
        NSLog("[ScreenTimeManager] Failed to schedule notification: %@", error.localizedDescription)
      } else {
        NSLog("[ScreenTimeManager] Exhausted notification scheduled successfully")
      }
    }
  }

  private func findTopViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    for scene in scenes {
      if let window = scene.windows.first(where: { $0.isKeyWindow }) {
        var topController = window.rootViewController
        while let presented = topController?.presentedViewController {
          topController = presented
        }
        return topController
      }
    }
    return UIApplication.shared.delegate?.window??.rootViewController
  }
}

// MARK: - SwiftUI Picker Container

#if canImport(FamilyControls) && canImport(SwiftUI)
@available(iOS 16.0, *)
private struct FamilyPickerContainerView: View {
  @State private var selection: FamilyActivitySelection
  @Environment(\.dismiss) private var dismiss
  private let onDismiss: (FamilyActivitySelection) -> Void

  init(initialSelection: FamilyActivitySelection, onDismiss: @escaping (FamilyActivitySelection) -> Void) {
    _selection = State(initialValue: initialSelection)
    self.onDismiss = onDismiss
  }

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Prominent Safety Guidance Header
        VStack(alignment: .leading, spacing: 6) {
          HStack(spacing: 8) {
            Image(systemName: "shield.lefthalf.filled")
              .foregroundColor(.blue)
              .font(.system(size: 16, weight: .semibold))
            Text("Select Specific Apps Only")
              .font(.system(size: 14, weight: .bold))
              .foregroundColor(.primary)
          }
          Text("Expand categories to choose individual distraction apps (e.g. Instagram, TikTok). Do NOT select entire categories or system tools, so alarms, home security, and emergency apps stay active.")
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.top, 8)

        FamilyActivityPicker(selection: $selection)
      }
      .navigationTitle("Select Apps to Shield")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            onDismiss(selection)
            dismiss()
          }
          .fontWeight(.bold)
        }
      }
    }
  }
}
#endif
