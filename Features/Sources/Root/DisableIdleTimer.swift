// Copyright © 2025 Brad Howes. All rights reserved.

import Sharing
import SwiftUI

extension Root {

  @MainActor
  public static func disableIdleTimer() {
    @Shared(.disableIdleTimer) var disableIdleTimer
    let value = disableIdleTimer
    print("disableIdleTimer: ", disableIdleTimer, value)
    UIKit.UIApplication.shared.isIdleTimerDisabled = value
    print("UIKit.UIApplication.shared.isIdleTimerDisabled: ", UIKit.UIApplication.shared.isIdleTimerDisabled)
  }
}
