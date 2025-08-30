import Sharing
import SwiftUI

extension AppFeature {
  public static func disableIdleTimer() {
    @Shared(.disableIdleTimer) var disableIdleTimer
    DispatchQueue.main.async {
      UIKit.UIApplication.shared.isIdleTimerDisabled = disableIdleTimer
    }
  }
}
