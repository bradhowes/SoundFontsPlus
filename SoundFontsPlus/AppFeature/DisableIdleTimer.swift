import UIKit

extension AppFeature {
  public static func disableIdleTimer() {
    DispatchQueue.main.async {
      UIKit.UIApplication.shared.isIdleTimerDisabled = true
    }
  }
}
