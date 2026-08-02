// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport
import Sharing
import SwiftUI

extension AppRoot {

  @MainActor
  public static func disableIdleTimer() {
#if os(iOS)
    @Shared(.disableIdleTimer) var disableIdleTimer
    let value = disableIdleTimer
    print("disableIdleTimer: ", disableIdleTimer, value)
    UIKit.UIApplication.shared.isIdleTimerDisabled = value
    print("UIKit.UIApplication.shared.isIdleTimerDisabled: ", UIKit.UIApplication.shared.isIdleTimerDisabled)
#endif // os(iOS)
  }
}
