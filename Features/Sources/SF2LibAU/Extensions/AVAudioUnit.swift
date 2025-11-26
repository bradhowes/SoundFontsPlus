// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio

extension AVAudioUnit {
  public var synth: SF2LibAU? { self.auAudioUnit.synth }
}

extension AUAudioUnit {
  public var synth: SF2LibAU? { self as? SF2LibAU }
}
