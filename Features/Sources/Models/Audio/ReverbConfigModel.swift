// Copyright © 2024 Brad Howes. All rights reserved.

import AVFoundation
import Foundation
import SwiftData


@Model
public final class ReverbConfigModel {
  public var preset: Int = 0
  public var wetDryMix: AUValue = 0.5
  public var enabled = true

  init(preset: Int, wetDryMix: AUValue) {
    self.preset = preset
    self.wetDryMix = wetDryMix
  }
}

