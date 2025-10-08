// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies

extension DependencyValues {

  public var outputVolume: OutputVolume {
    get { self[OutputVolume.self] }
    set { self[OutputVolume.self] = newValue }
  }
}
