// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio

extension AVAudioUnit {
  public var sf2LibAU: SF2LibAU? { self.auAudioUnit.sf2LibAU }
}

extension AUAudioUnit {
  public var sf2LibAU: SF2LibAU? { self as? SF2LibAU }
}
