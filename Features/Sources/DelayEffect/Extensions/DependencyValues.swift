// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies

extension DependencyValues {

  public var delayDevice: DelayDevice {
    get { self[DelayDevice.self] }
    set { self[DelayDevice.self] = newValue }
  }
}
