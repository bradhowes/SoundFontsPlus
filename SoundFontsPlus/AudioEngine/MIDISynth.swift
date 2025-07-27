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
