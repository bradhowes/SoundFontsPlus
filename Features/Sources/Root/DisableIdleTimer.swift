import Sharing
import SwiftUI

extension Root {

  @MainActor
  public static func disableIdleTimer() {
    @Shared(.disableIdleTimer) var disableIdleTimer
    UIKit.UIApplication.shared.isIdleTimerDisabled = disableIdleTimer
  }
}
