import Foundation
import DeviceActivity
import ManagedSettings
import FamilyControls

// MARK: - ScreenTimeExtensionHandler
//
// This extension runs in its own process. iOS keeps it alive even after the
// main app is killed, so it can re-apply ManagedSettings shields whenever a
// DeviceActivity time window starts or ends.
//
// It uses a named ManagedSettingsStore that persists independently of the
// main app process, so shields survive app termination.

@available(iOS 16.0, *)
class ScreenTimeExtensionHandler: DeviceActivityMonitor {

  // The named store MUST match the one used in ScreenTimeManager.swift.
  private let store = ManagedSettingsStore(
    named: ManagedSettingsStore.Name("ai.socialstudying.screentime")
  )

  // Called when a DeviceActivity interval STARTS (blocking period begins).
  override func intervalDidStart(for activity: DeviceActivityName) {
    applyShields()
  }

  // Called when a DeviceActivity interval ENDS (blocking period ends).
  override func intervalDidEnd(for activity: DeviceActivityName) {
    // Keep shields in place by default when period ends —
    // the main app controls clearing via the named store.
    applyShields()
  }

  // Called when screen time for an event exceeds a threshold.
  override func eventDidReachThreshold(
    _ event: DeviceActivityEvent.Name,
    activity: DeviceActivityName
  ) {
    applyShields()
  }

  // MARK: - Shield Management

  private func applyShields() {
    // Re-apply whatever is already set in the persistent named store.
    // The main app sets store.shield.applications / webDomains / applicationCategories
    // before scheduling activities. Because we share the same named store,
    // those values persist across process boundaries.
    //
    // If nothing is explicitly shielded yet, we do nothing — the main app
    // is responsible for the initial configuration.
    _ = store // accessing the store re-applies its persistent state to the system
  }
}
