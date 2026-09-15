import ManagedSettingsUI
import ManagedSettings
import UIKit

@available(iOS 16.0, *)
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
  
  override func configuration(shielding application: Application) -> ShieldConfiguration {
    return ShieldConfiguration(
      backgroundBlurStyle: .systemMaterialDark,
      backgroundColor: UIColor(red: 15/255.0, green: 23/255.0, blue: 42/255.0, alpha: 1.0),
      icon: UIImage(named: "AppIcon") ?? UIImage(systemName: "book.fill"),
      title: ShieldConfiguration.Label(
        text: "Study Session Needed",
        color: .white
      ),
      subtitle: ShieldConfiguration.Label(
        text: "To gain access to your app, let’s create a study session.",
        color: UIColor(red: 148/255.0, green: 163/255.0, blue: 184/255.0, alpha: 1.0)
      ),
      primaryButtonLabel: ShieldConfiguration.Label(
        text: "Close",
        color: .white
      ),
      primaryButtonBackgroundColor: UIColor(red: 37/255.0, green: 99/255.0, blue: 235/255.0, alpha: 1.0),
      secondaryButtonLabel: nil
    )
  }

  override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
    return configuration(shielding: application)
  }

  override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
    return ShieldConfiguration(
      backgroundBlurStyle: .systemMaterialDark,
      backgroundColor: UIColor(red: 15/255.0, green: 23/255.0, blue: 42/255.0, alpha: 1.0),
      icon: UIImage(systemName: "globe"),
      title: ShieldConfiguration.Label(
        text: "Study Session Needed",
        color: .white
      ),
      subtitle: ShieldConfiguration.Label(
        text: "To gain access to your website, let’s create a study session.",
        color: UIColor(red: 148/255.0, green: 163/255.0, blue: 184/255.0, alpha: 1.0)
      ),
      primaryButtonLabel: ShieldConfiguration.Label(
        text: "Close",
        color: .white
      ),
      primaryButtonBackgroundColor: UIColor(red: 37/255.0, green: 99/255.0, blue: 235/255.0, alpha: 1.0),
      secondaryButtonLabel: nil
    )
  }

  override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
    return configuration(shielding: webDomain)
  }
}
