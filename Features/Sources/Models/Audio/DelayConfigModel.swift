// Copyright © 2024 Brad Howes. All rights reserved.

import AVFoundation
import Foundation
import SwiftData


@Model
public final class DelayConfigModel {
  public var time: AUValue = 0.0
  public var feedback: AUValue = 0.0
  public var cutoff: AUValue = 0.0
  public var wetDryMix: AUValue = 0.5
  public var enabled = true

  public init(time: AUValue, feedback: AUValue, cutoff: AUValue, wetDryMix: AUValue) {
    self.time = time
    self.feedback = feedback
    self.cutoff = cutoff
    self.wetDryMix = wetDryMix
  }
}
