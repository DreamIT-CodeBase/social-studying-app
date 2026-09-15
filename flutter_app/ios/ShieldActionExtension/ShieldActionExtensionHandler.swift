import ManagedSettings
import UserNotifications
import Foundation

@available(iOS 16.0, *)
class ShieldActionExtensionHandler: ShieldActionDelegate {

  override func handle(
    action: ShieldAction,
    for application: ApplicationToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    switch action {
    case .primaryButtonPressed:
      // "Study Now" tapped on the blocked app's shield screen:
      // Post notification, wait for registration, and defer so shield stays up
      // and the alert banner drops down at the top for the student to tap.
      sendStudyNotification {
        completionHandler(.defer)
      }

    case .secondaryButtonPressed:
      completionHandler(.close)

    @unknown default:
      completionHandler(.close)
    }
  }

  override func handle(
    action: ShieldAction,
    for webDomain: WebDomainToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    if action == .primaryButtonPressed {
      sendStudyNotification {
        completionHandler(.defer)
      }
    } else {
      completionHandler(.close)
    }
  }

  override func handle(
    action: ShieldAction,
    for category: ActivityCategoryToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    if action == .primaryButtonPressed {
      sendStudyNotification {
        completionHandler(.defer)
      }
    } else {
      completionHandler(.close)
    }
  }

  private func sendStudyNotification(completion: @escaping () -> Void) {
    let center = UNUserNotificationCenter.current()
    let identifier = "ai.socialstudying.screentime.studynow.\(Int(Date().timeIntervalSince1970 * 1000))"

    let content = UNMutableNotificationContent()
    content.title = "📚 Study Session Ready"
    content.body = "Tap here to start your study session and unlock your apps!"
    content.sound = .default
    content.categoryIdentifier = "STUDY_SESSION_NEEDED_CATEGORY"
    content.userInfo = [
      "action": "unlock_question",
      "type": "unlock_question",
      "source": "shield_button"
    ]
    if #available(iOS 15.0, *) {
      content.interruptionLevel = .timeSensitive
      content.relevanceScore = 1.0
    }

    // trigger: nil delivers immediately without timer delay
    let request = UNNotificationRequest(
      identifier: identifier,
      content: content,
      trigger: nil
    )

    center.add(request) { error in
      if let error = error {
        NSLog("[ShieldAction] Error posting notification: %@", error.localizedDescription)
      } else {
        NSLog("[ShieldAction] Notification posted successfully with ID %@", identifier)
      }
      completion()
    }
  }
}
