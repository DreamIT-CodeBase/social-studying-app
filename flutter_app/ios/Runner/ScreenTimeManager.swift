import Flutter
import Foundation
import UIKit

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

// MARK: - ScreenTimeManager

@objc class ScreenTimeManager: NSObject {
  @objc static let shared = ScreenTimeManager()

  // Shared with the DeviceActivityMonitor extension via App Group.
  let appGroupIdentifier = "group.ai.socialstudying.app.screentime"
  let selectionStorageKey = "saved_family_activity_selection"
  let blockingEnabledKey  = "is_screen_time_blocking_enabled"
  let availableMinutesKey = "cached_available_minutes"

  // Named store — MUST match the name used in the DeviceActivityMonitor extension.
  // Using a named store makes shields persist until explicitly cleared, even
  // across app restarts, unlike the anonymous ManagedSettingsStore().
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
          // iOS 17.4+ may reject .individual on non-managed devices.
          // Instruct the user to enable Screen Time in Settings manually.
          let msg = "Unable to authorize automatically. Please go to Settings → Screen Time and enable it, then return to this app.\n\nOriginal error: \(error.localizedDescription)"
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
               !selection.categoryTokens.isEmpty   ||
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
    let enabled = userDefaults.bool(forKey: blockingEnabledKey)
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
      // Blocking turned off — remove all shields
      store.shield.applications = nil
      store.shield.applicationCategories = nil
      store.shield.webDomains = nil
      return
    }

    if availableMinutes <= 0 {
      // Time exhausted — apply all configured shields
      guard let selection = loadSelection(), hasSelectedApps() else {
        // No apps selected yet — remove shields
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        return
      }
      store.shield.applications        = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
      store.shield.webDomains          = selection.webDomainTokens.isEmpty   ? nil : selection.webDomainTokens
      store.shield.applicationCategories = selection.categoryTokens.isEmpty   ? nil : .specific(selection.categoryTokens)
    } else {
      // Time available — remove shields
      store.shield.applications = nil
      store.shield.applicationCategories = nil
      store.shield.webDomains = nil
    }
    #endif
  }

  // MARK: - Open Settings

  @objc func openScreenTimeSettings() {
    DispatchQueue.main.async {
      // Deep-link into Screen Time in Settings
      if let url = URL(string: "App-prefs:SCREEN_TIME") {
        if UIApplication.shared.canOpenURL(url) {
          UIApplication.shared.open(url)
          return
        }
      }
      // Fallback for older iOS
      if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
      }
    }
  }

  // MARK: - Helpers

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
      FamilyActivityPicker(selection: $selection)
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
