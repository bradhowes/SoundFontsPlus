// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio.AVAudioUnit
import BaseSupport

public final class MockAudioUnit: AVAudioUnitSampler, @unchecked Sendable {
  public var events: [(MIDICoreEvent, UInt8, UInt8, UInt8)] = []

  public override func startNote(_ note: UInt8, withVelocity velocity: UInt8, onChannel channel: UInt8) {
    events.append((.noteOn, note, velocity, channel))
  }

  public override func stopNote(_ note: UInt8, onChannel channel: UInt8) {
    events.append((.noteOff, note, 0, channel))
  }

  public override func sendPressure(forKey note: UInt8, withValue pressure: UInt8, onChannel channel: UInt8) {
    events.append((.keyPressure, note, pressure, channel))
  }

  public override func sendController(_ controller: UInt8, withValue value: UInt8, onChannel channel: UInt8) {
    events.append((.controlChange, controller, value, channel))
  }

  public override func sendProgramChange(_ program: UInt8, onChannel channel: UInt8) {
    events.append((.programChange, program, 0, channel))
  }

  public override func sendPressure(_ pressure: UInt8, onChannel channel: UInt8) {
    events.append((.channelPressure, pressure, 0, channel))
  }

  public override func sendPitchBend(_ value: UInt16, onChannel channel: UInt8) {
    events.append((.pitchBend, UInt8(value & 0x7F), UInt8(value >> 7), channel))
  }

  public override func reset() {
    events.append((.reset, 0, 0, 0))
  }
}
