// Copyright © 2025 Brad Howes. All rights reserved.

import AVFoundation

/**
 Protocol for any entity that acts as a MIDI synth.
 */
public protocol MIDISynth {
  var avAudioUnit: AVAudioUnitMIDIInstrument { get }

  var synthGain: Float { get set }
  var synthStereoPan: Float { get set }
  var synthGlobalTuning: Float { get set }

  func noteOff(note: UInt8, velocity: UInt8)
  func noteOn(note: UInt8, velocity: UInt8)
  func polyphonicKeyPressure(note: UInt8, pressure: UInt8)
  func controlChange(controller: UInt8, value: UInt8)
  func programChange(program: UInt8)
  func channelPressure(pressure: UInt8)
  func pitchBendChange(value: UInt16)

  func stopAllNotes()
  func setPitchBendRange(value: UInt8)
}

public extension MIDISynth {

  func noteOff(note: UInt8, velocity: UInt8 = 0) {
    avAudioUnit.stopNote(note, onChannel: 0)
  }

  func noteOn(note: UInt8, velocity: UInt8 = 0) {
    avAudioUnit.startNote(note, withVelocity: velocity, onChannel: 0)
  }

  func polyphonicKeyPressure(note: UInt8, pressure: UInt8) {
    avAudioUnit.sendPressure(forKey: note, withValue: pressure, onChannel: 0)
  }

  func controlChange(controller: UInt8, value: UInt8) {
    avAudioUnit.sendController(controller, withValue: value, onChannel: 0)
  }

  func programChange(program: UInt8) {
    avAudioUnit.sendProgramChange(program, onChannel: 0)
  }

  func channelPressure(pressure: UInt8) {
    avAudioUnit.sendPressure(pressure, onChannel: 0)
  }

  func pitchBendChange(value: UInt16) {
    avAudioUnit.sendPitchBend(value, onChannel: 0)
  }

  func stopAllNotes() {
    avAudioUnit.sendMIDIEvent(0xB0, data1: 0x7B, data2: 0)
  }

  func setPitchBendRange(value: UInt8) {
    guard value < 25 else { return }
    avAudioUnit.sendMIDIEvent(0xB0, data1: 101, data2: 0)
    avAudioUnit.sendMIDIEvent(0xB0, data1: 100, data2: 0)
    avAudioUnit.sendMIDIEvent(0xB0, data1: 6, data2: value)
    avAudioUnit.sendMIDIEvent(0xB0, data1: 38, data2: 0)
  }
}
