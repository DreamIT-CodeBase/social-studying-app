import Flutter
import Foundation
import UIKit

#if canImport(FamilyControls)
import FamilyControls
#endif

#if canImport(ManagedSettings)
import ManagedSettings
#endif

#if canImport(SwiftUI)
import SwiftUI
#endif

@objc class ScreenTimeManager: NSObject {
  @objc static let shared = ScreenTimeManager()

  private let appGroupIdentifier = "group.ai.socialstudying.app.screentime"
  private let selectionStorageKey = "saved_family_activity_selection"
  private let blockingEnabledKey = "is_screen_time_blocking_enabled"

  private var userDefaults: UserDefaults {
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

  func requestAuthorization(completion: @escaping (Bool, String?) -> Void) {
    if #available(iOS 16.0, *) {
      #if canImport(FamilyControls)
      Task { @MainActor in
        do {
          try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
          let approved = AuthorizationCenter.shared.authorizationStatus == .approved
          completion(approved, nil)
        } catch {
          completion(false, error.localizedDescription)
        }
      }
      #else
      completion(false, "FamilyControls framework is not available")
      #endif
    } else {
      completion(false, "Screen Time API requires iOS 16.0 or later")
    }
  }

  // MARK: - Selection & App Picker

  func hasSelectedApps() -> Bool {
    if #available(iOS 16.0, *) {
      #if canImport(FamilyControls)
      if let selection = loadSelection() {
        return !selection.applicationTokens.isEmpty ||
               !selection.categoryTokens.isEmpty ||
               !selection.webDomainTokens.isEmpty
      }
      #endif
    }
    return false
  }

  #if canImport(FamilyControls)
  @available(iOS 16.0, *)
  private func loadSelection() -> FamilyActivitySelection? {
    guard let data = userDefaults.data(forKey: selectionStorageKey) else { return nil }
    let decoder = PropertyListDecoder()
    return try? decoder.decode(FamilyActivitySelection.self, from: data)
  }

  @available(iOS 16.0, *)
  private func saveSelection(_ selection: FamilyActivitySelection) {
    let encoder = PropertyListEncoder()
    if let data = try? encoder.encode(selection) {
      userDefaults.set(data, forKey: selectionStorageKey)
    }
  }
  #endif

  func presentAppPicker(completion: @escaping (Bool, String?) -> Void) {
    if #available(iOS 16.0, *) {
      #if canImport(FamilyControls) && canImport(SwiftUI)
      guard isAuthorized() else {
        completion(false, "Screen Time authorization must be granted before selecting apps")
        return
      }

      DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        guard let rootVC = self.findTopViewController() else {
          completion(false, "Could not find top view controller to present picker")
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
      completion(false, "FamilyActivityPicker is not available")
      #endif
    } else {
      completion(false, "FamilyActivityPicker requires iOS 16.0 or later")
    }
  }

  // MARK: - Shield Enforcement

  func syncScreenTimeBalance(availableMinutes: Int, enableBlocking: Bool) {
    userDefaults.set(enableBlocking, forKey: blockingEnabledKey)
    userDefaults.set(availableMinutes, forKey: "cached_available_minutes")

    if #available(iOS 16.0, *) {
      #if canImport(ManagedSettings) && canImport(FamilyControls)
      let store = ManagedSettingsStore()
      guard enableBlocking else {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        return
      }

      if availableMinutes <= 0 {
        if let selection = loadSelection() {
          store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
          store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
          if !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
          } else {
            store.shield.applicationCategories = nil
          }
        }
      } else {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
      }
      #endif
    }
  }

  private func reapplyShields() {
    let minutes = userDefaults.integer(forKey: "cached_available_minutes")
    let enabled = userDefaults.bool(forKey: blockingEnabledKey)
    syncScreenTimeBalance(availableMinutes: minutes, enableBlocking: enabled)
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
