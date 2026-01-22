// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import BaseSupport
import Combine
import Models
import MorkAndMIDI
import os
import Sharing
import SQLiteData

public struct MIDITrafficStat: Equatable, Sendable {
  public let id: MIDIUniqueID
  public let channel: UInt8
  public let accepted: Bool

  public init(id: MIDIUniqueID, channel: UInt8, accepted: Bool) {
    self.id = id
    self.channel = channel
    self.accepted = accepted
  }
}

public enum MIDINote: Equatable, Sendable {
  case on(Note)
  case off(Note)
}

public final class MIDIMonitor: @unchecked Sendable {

  let midiInstrument: AVAudioUnitMIDIInstrument

  // We want all traffic to appear in the `traffic` tap, regardless of channel. However, we *will* filter
  // traffic ourselvee in the `accepts` method where we use the `midiChannel` shared value to determine if
  // we forward the traffic to the synth.
  public var channel: Int { -1 }
  public var group: Int { -1 }

  /// Publisher of the state of the current connections established between the app and external MIDI devices.
  @Published public var connectivity: [MIDI.SourceConnectionState]
  /// Publisher of traffic info received from the MIDI system
  @Published public var traffic: MIDITrafficStat?
  /// Publisher of note ON/OFF commands that were sent to the synth
  @Published public var notes: MIDINote?

  @Shared(.midi) private var midi

  // TODO: we should be able to use @Dependency(\.defaultDatabase) but during tests it is not being properly set
  private var database: DatabaseWriter

  /**
   Create new instance that sends MIDI traffic to the given MIDI instrument (SF2LibAU).

   - parameter instrument: the SF2LibAU audio unit to communicate with
   */
  public init(instrument: AVAudioUnitMIDIInstrument) {
    self.midiInstrument = instrument
    self.connectivity = []
    @Dependency(\.defaultDatabase) var database
    self.database = database
  }
}

extension MIDIMonitor: Monitor {

  /**
   Determine if the remote device should be connected to.

   - parameter uniqueId: the ID of the remote endpoint that has appeared.
   - returns: true if connection should be established
   */
  public func shouldConnect(to uniqueId: MIDIUniqueID) -> Bool {
    let midiConfig = withErrorReporting {
      try database.read {
        try MIDIConfig.all.find(uniqueId).fetchOne($0)
      } ?? nil
    }

    if let midiConfig {
      log.debug("shouldConnect - uniqueId: \(uniqueId.asHex) result: \(midiConfig.autoConnect)")
      return midiConfig.autoConnect
    }

    @Shared(.midiAutoConnect) var midiAutoConnect
    log.debug("shouldConnect - uniqueId: \(uniqueId.asHex) result: \(midiAutoConnect)")
    return midiAutoConnect
  }

  public func didUpdateConnections(connected: any Sequence<MIDIEndpointRef>, disappeared: any Sequence<MIDIUniqueID>) {
    log.debug("didUpdateConnections: \(connected.map(\.uniqueId.asHex)) - \(String(describing: disappeared), privacy: .public)")
    if let midi {
      self.connectivity = midi.sourceConnections
    }
  }
}

extension MIDIMonitor {
  public func didConnect(to uniqueId: MIDIUniqueID) {}
  public func willUpdateConnections() {}
  public func didInitialize() {}
  public func willUninitialize() {}
  public func didCreate(inputPort: MIDIPortRef) {}
  public func willDelete(inputPort: MIDIPortRef) {}
  public func didStart() {}
  public func didStop() {}
  public func didSee(uniqueId: MIDIUniqueID, group: Int, channel: Int) {}
}

extension MIDIMonitor: Receiver {

  private func acceptsTraffic(source: MIDIUniqueID, channel: UInt8, notify: Bool = false) -> Bool {
    @Shared(.midiChannel) var midiChannel
    let accepted = midiChannel == -1 || midiChannel == Int(channel)
    if notify {
      traffic = .init(id: source, channel: channel, accepted: accepted)
    }
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
    if acceptsTraffic(source: source, channel: channel) {
      midiInstrument.stopNote(note, onChannel: channel)
      notes = .off(Note(midi: note))
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
    if acceptsTraffic(source: source, channel: channel, notify: true) {
      midiInstrument.startNote(note, withVelocity: velocity, onChannel: channel)
      notes = .on(Note(midi: note))
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
    if acceptsTraffic(source: source, channel: channel) {
      midiInstrument.sendPressure(forKey: note, withValue: pressure, onChannel: channel)
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
    if acceptsTraffic(source: source, channel: channel, notify: true) {
      log.debug("controlChange - \(source.asHex) - controller: \(controller) value: \(value)")
      midiInstrument.sendController(controller, withValue: value, onChannel: channel)
    }
  }

  public func controlChange2(source: MIDIUniqueID, controller: UInt8, value: UInt32, channel: UInt8) {
    // controlChange(source: source, controller: controller, value: value.b0, channel: channel)
  }

  public func programChange(source: MIDIUniqueID, program: UInt8, channel: UInt8) {
    if acceptsTraffic(source: source, channel: channel) {
      log.debug("programChange - \(source.asHex) - program: \(program)")
      midiInstrument.sendProgramChange(program, onChannel: channel)
    }
  }

  public func programChange2(source: MIDIUniqueID, program: UInt8, bank: UInt16, channel: UInt8) {
    // synth?.programChange(program: program)
    // log.debug("programChange: \(program)")
  }

  public func channelPressure(source: MIDIUniqueID, pressure: UInt8, channel: UInt8) {
    if acceptsTraffic(source: source, channel: channel) {
      log.debug("channelPressure - \(source.asHex) - pressure: \(pressure)")
      midiInstrument.sendPressure(pressure, onChannel: channel)
    }
  }

  public func channelPressure2(source: MIDIUniqueID, pressure: UInt32, channel: UInt8) {
    // synth?.channelPressure(pressure: pressure.b0)
  }

  public func pitchBendChange(source: MIDIUniqueID, value: UInt16, channel: UInt8) {
    if acceptsTraffic(source: source, channel: channel, notify: true) {
      log.debug("pitchBendChange - \(source.asHex) - value: \(value)")
      midiInstrument.sendPitchBend(value, onChannel: channel)
    }
  }

  public func pitchBendChange2(source: MIDIUniqueID, value: UInt32, channel: UInt8) {
    // synth?.pitchBendChange(value: value.w0 & 0x7FFF)
  }

  public func systemReset(source: MIDIUniqueID) {
    midiInstrument.reset()
  }
}

private let log: Logger = .init(category: "MIDIMonitor")
