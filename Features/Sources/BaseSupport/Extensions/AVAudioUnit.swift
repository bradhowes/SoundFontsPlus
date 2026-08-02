// Copyright © 2025 Brad Howes. All rights reserved.

public import AVFAudio.AVAudioUnitMIDIInstrument

extension AVAudioUnit {
  public var midiInstrument: AVAudioUnitMIDIInstrument? { self as? AVAudioUnitMIDIInstrument }
  public var parameterTree: AUParameterTree? { auAudioUnit.parameterTree }
}

extension AVAudioUnit: @unchecked @retroactive Sendable {}
