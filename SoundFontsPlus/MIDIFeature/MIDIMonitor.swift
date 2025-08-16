// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import Combine
import MorkAndMIDI
import os
import Sharing
import SharingGRDB

private let log = Logger(category: "MIDIMonitor")

public struct MIDITraffic: Equatable {
  public let id: MIDIUniqueID
  public let channel: UInt8
  public let accepted: Bool
}

public final class MIDIMonitor {
  @Shared(.midiChannel) var midiChannel
  @Shared(.avAudioUnit) var avAudioUnit
  var synth: AVAudioUnitMIDIInstrument? { avAudioUnit?.midiInstrument }

  // We want all traffic to appear in the `traffic` tap, regardless of channel.
  public var channel: Int { -1 }
  public var group: Int { -1 }

  @Published public var traffic: MIDITraffic?
}

extension MIDIMonitor: Receiver {

  private func accepts(source: MIDIUniqueID, channel: UInt8) -> Bool {
    let accepted = midiChannel == -1 || midiChannel == Int(channel)
    traffic = .init(id: source, channel: channel, accepted: accepted)
    return accepted
  }

  public func perNotePitchBendChange(source: MIDIUniqueID, note: UInt8, value: UInt32) {}
  public func timeCodeQuarterFrame(source: MIDIUniqueID, value: UInt8) {}
  public func songPositionPointer(source: MIDIUniqueID, value: UInt16) {}
  public func songSelect(source: MIDIUniqueID, value: UInt8) {}
  public func tuneRequest(source: MIDIUniqueID) {}
  public func timingClock(source: MIDIUniqueID) {}
  public func startCurrentSequence(source: MIDIUniqueID) {}
  public func continueCurrentSequence(source: MIDIUniqueID) {}
  public func stopCurrentSequence(source: MIDIUniqueID) {}
  public func activeSensing(source: MIDIUniqueID) {}
  public func registeredPerNoteControllerChange(source: MIDIUniqueID, note: UInt8, controller: UInt8, value: UInt32) {}
  public func assignablePerNoteControllerChange(source: MIDIUniqueID, note: UInt8, controller: UInt8, value: UInt32) {}
  public func registeredControllerChange(source: MIDIUniqueID, controller: UInt16, value: UInt32) {}
  public func assignableControllerChange(source: MIDIUniqueID, controller: UInt16, value: UInt32) {}
  public func relativeRegisteredControllerChange(source: MIDIUniqueID, controller: UInt16, value: Int32) {}
  public func relativeAssignableControllerChange(source: MIDIUniqueID, controller: UInt16, value: Int32) {}
  public func perNoteManagement(source: MIDIUniqueID, note: UInt8, detach: Bool, reset: Bool) {}

  public func noteOff(source: MIDIUniqueID, note: UInt8, velocity: UInt8, channel: UInt8) {
    if accepts(source: source, channel: channel) {
      synth?.stopNote(note, onChannel: channel)
    }
  }

  // swiftlint:disable function_parameter_count
  public func noteOff2(
    source: MIDIUniqueID,
    note: UInt8,
    velocity: UInt16,
    channel: UInt8,
    attributeType: UInt8,
    attributeData: UInt16
  ) {
    // noteOff(source: source, note: note, velocity: velocity.b0, channel: channel)
  }
  // swiftlint:enable function_parameter_count

  public func noteOn(source: MIDIUniqueID, note: UInt8, velocity: UInt8, channel: UInt8) {
    if accepts(source: source, channel: channel) {
      synth?.startNote(note, withVelocity: velocity, onChannel: channel)
    }
    // (note, velocity: connectionState.fixedVelocity ?? velocity)
    // keyboard.noteIsOn(note: note)
  }

  // swiftlint:disable function_parameter_count
  public func noteOn2(
    source: MIDIUniqueID,
    note: UInt8,
    velocity: UInt16,
    channel: UInt8,
    attributeType: UInt8,
    attributeData: UInt16
  ) {
    // noteOn(source: source, note: note, velocity: velocity.b0, channel: channel)
  }
  // swiftlint:enable function_parameter_count

  public func polyphonicKeyPressure(source: MIDIUniqueID, note: UInt8, pressure: UInt8, channel: UInt8) {
    if accepts(source: source, channel: channel) {
      synth?.sendPressure(forKey: note, withValue: pressure, onChannel: channel)
    }
  }

  public func polyphonicKeyPressure2(source: MIDIUniqueID, note: UInt8, pressure: UInt32, channel: UInt8) {
    // polyphonicKeyPressure(source: source, note: note, pressure: pressure.b0, channel: channel)
  }

  public func controlChange(source: MIDIUniqueID, controller: UInt8, value: UInt8, channel: UInt8) {
    log.debug("controlCHange: \(controller) - \(value)")
    //
    //    let midiControllerIndex = Int(controller)
    //    let controllerState = midiControllerState[midiControllerIndex]
    //
    //    // Update with last value for display in the MIDI Controllers view
    //    controllerState.lastValue = Int(value)
    //    Self.controllerActivityNotifier.post(source: source, controller: controller, value: value)
    //
    //    // If not enabled, stop processing
    //    guard controllerState.allowed else { return }
    //
    //    // If assigned to an action, notify action handlers
    //    if let actions = midiControllerActionStateManager.lookup[Int(controller)] {
    //      for actionIndex in actions {
    //        let action = midiControllerActionStateManager.actions[actionIndex]
    //        guard let kind = action.kind else { fatalError() }
    //        Self.actionNotifier.post(action: action.action, kind: kind, value: value)
    //      }
    //    }
    //
    // Hand the controller value change to the synth
    if accepts(source: source, channel: channel) {
      synth?.sendController(controller, withValue: value, onChannel: channel)
    }
  }

  public func controlChange2(source: MIDIUniqueID, controller: UInt8, value: UInt32, channel: UInt8) {
    // controlChange(source: source, controller: controller, value: value.b0, channel: channel)
  }

  public func programChange(source: MIDIUniqueID, program: UInt8, channel: UInt8) {
    if accepts(source: source, channel: channel) {
      synth?.sendProgramChange(program, onChannel: channel)
    }
  }

  public func programChange2(source: MIDIUniqueID, program: UInt8, bank: UInt16, channel: UInt8) {
    // synth?.programChange(program: program)
    // log.debug("programChange: \(program)")
  }

  public func channelPressure(source: MIDIUniqueID, pressure: UInt8, channel: UInt8) {
    if accepts(source: source, channel: channel) {
      synth?.sendPressure(pressure, onChannel: channel)
    }
  }

  public func channelPressure2(source: MIDIUniqueID, pressure: UInt32, channel: UInt8) {
    // synth?.channelPressure(pressure: pressure.b0)
  }

  public func pitchBendChange(source: MIDIUniqueID, value: UInt16, channel: UInt8) {
    if accepts(source: source, channel: channel) {
      synth?.sendPitchBend(value, onChannel: channel)
    }
  }

  public func pitchBendChange2(source: MIDIUniqueID, value: UInt32, channel: UInt8) {
    // synth?.pitchBendChange(value: value.w0 & 0x7FFF)
  }

  public func systemReset(source: MIDIUniqueID) {
    synth?.reset()
  }
}
