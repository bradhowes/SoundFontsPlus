// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio.AVAudioUnitReverb
import Models

extension AVAudioUnitReverb {

  public func setConfig(_ config: ReverbConfig.Draft) {
    self.loadFactoryPreset(config.roomPreset)
    self.wetDryMix = Float(config.wetDryMix)
    self.bypass = !config.enabled
  }
}
