// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio.AVAudioUnitMIDIInstrument
import Engine

extension AVAudioUnitMIDIInstrument {

  public func sendLoadFileUsePreset(path: String, preset: Int, gain: Double, pan: Double) -> Bool {
    sendMIDI(bytes: Array(SF2Engine.createLoadFileUsePresetPayload(std.string(path), preset)))
  }

  public func sendUsePreset(preset: Int, gain: Double, pan: Double) -> Bool {
    sendMIDI(bytes: Array(SF2Engine.createLoadFileUsePresetPayload("", preset)))
  }

  public func sendMIDI(bytes: [UInt8], when: AUEventSampleTime = 0, cable: UInt8 = 0) -> Bool {
    guard let block = unsafe auAudioUnit.scheduleMIDIEventBlock else {
      return false
    }
    unsafe block(when, cable, bytes.count, bytes)
    return true
  }
}
