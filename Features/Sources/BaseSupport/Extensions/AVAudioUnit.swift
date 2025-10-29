// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio.AVAudioUnitMIDIInstrument

extension AVAudioUnit {
  public var midiInstrument: AVAudioUnitMIDIInstrument? { self as? AVAudioUnitMIDIInstrument }
}

extension AVAudioUnit: @unchecked @retroactive Sendable {}
