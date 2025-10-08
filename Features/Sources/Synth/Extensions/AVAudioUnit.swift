// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio

extension AVAudioUnit {
  public var synth: SF2LibAU? { self.auAudioUnit as? SF2LibAU }
}
