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
      // "Study Now" tapped on the blocked app's shield screen
      sendStudyNotification()
      completionHandler(.close)

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
      sendStudyNotification()
      completionHandler(.close)
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
      sendStudyNotification()
      completionHandler(.close)
    } else {
      completionHandler(.close)
    }
  }

  private func sendStudyNotification() {
    let center = UNUserNotificationCenter.current()
    let identifier = "ai.socialstudying.screentime.studynow"

    center.removeDeliveredNotifications(withIdentifiers: [identifier])
    center.removePendingNotificationRequests(withIdentifiers: [identifier])

    let content = UNMutableNotificationContent()
    content.title = "Ready to Unlock?"
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

    let request = UNNotificationRequest(
      identifier: identifier,
      content: content,
      trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
    )

    center.add(request) { error in
      if let error = error {
        NSLog("[ShieldAction] Error posting notification: %@", error.localizedDescription)
      } else {
        NSLog("[ShieldAction] Notification posted successfully")
      }
    }
  }
}
