// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies

extension DependencyValues {

  public var reverbDevice: ReverbDevice {
    get { self[ReverbDevice.self] }
    set { self[ReverbDevice.self] = newValue }
  }
}
