// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio.AVAudioUnit
import DependenciesTestSupport
import MorkAndMIDI
import SnapshotTesting
import Testing
import TestSupport

@testable import FeatureSupport

@Suite(
  .dependencies {
    $0.defaultDatabase = TestSupport.testDatabase()
  }
)
@MainActor
struct MIDIMonitorTests {

  @Shared(.midiAutoConnect) var midiAutoConnect = false
  @Shared(.midiChannel) var midiChannel = -1

  @Test
  func misc() {
    let monitor = MIDIMonitor(instrument: MockAudioUnit())
    #expect(monitor.channel == -1)
    #expect(monitor.group == -1)
  }

  @Test
  func autoConnectDisabled() {
    let mau = MockAudioUnit()
    $midiChannel.withLock { $0 = 1 }
    let monitor = MIDIMonitor(instrument: mau)
    #expect(!monitor.shouldConnect(to: MIDIUniqueID(123123)))
  }

  @Test
  func autoConnectEnabled() {
    let mau = MockAudioUnit()
    $midiAutoConnect.withLock { $0 = true }
    $midiChannel.withLock { $0 = 1 }
    let monitor = MIDIMonitor(instrument: mau)
    #expect(monitor.shouldConnect(to: MIDIUniqueID(123123)))
  }

  @Test
  func connectByUniqueIdFalse() {
    let mau = MockAudioUnit()
    $midiAutoConnect.withLock { $0 = true }
    $midiChannel.withLock { $0 = 1 }
    let monitor = MIDIMonitor(instrument: mau)
    @Dependency(\.defaultDatabase) var database
    withDatabaseWriter { db in
      try MIDIConfig.upsert {
        .init(uniqueId: 123123, autoConnect: false, fixedVolume: MIDIConfig.disabledFixedVolume)
      }
      .execute(db)
    }
    #expect(!monitor.shouldConnect(to: MIDIUniqueID(123123)))
  }

  @Test
  func connectByUniqueIdTrue() {
    let mau = MockAudioUnit()
    $midiChannel.withLock { $0 = 1 }
    let monitor = MIDIMonitor(instrument: mau)
    @Dependency(\.defaultDatabase) var database
    withDatabaseWriter { db in
      try MIDIConfig.upsert {
        .init(uniqueId: 123123, autoConnect: true, fixedVolume: MIDIConfig.disabledFixedVolume)
      }
      .execute(db)
    }
    #expect(monitor.shouldConnect(to: MIDIUniqueID(123123)))
  }

  @Test
  func monitorWithSynth() {
    let mau = MockAudioUnit()

    let monitor = MIDIMonitor(instrument: mau)
    monitor.noteOn(source: 123, note: 60, velocity: 64, channel: 0)
    monitor.noteOff(source: 123, note: 60, velocity: 64, channel: 0)
    #expect(mau.events.count == 2)

    $midiChannel.withLock { $0 = 2}
    monitor.noteOn(source: 123, note: 60, velocity: 64, channel: 1)
    monitor.noteOff(source: 123, note: 60, velocity: 64, channel: 1)
    #expect(mau.events.count == 2)
  }

  @Test
  func forwarding() {
    let mau = MockAudioUnit()
    let monitor = MIDIMonitor(instrument: mau)
    monitor.noteOn(source: 123, note: 60, velocity: 64, channel: 0)
    #expect(mau.events.last! == (.noteOn, 60, 64, 0))
    monitor.noteOff(source: 123, note: 60, velocity: 64, channel: 0)
    #expect(mau.events.last! == (.noteOff, 60, 0, 0))
    monitor.noteOn(source: 123, note: 72, velocity: 32, channel: 1)
    #expect(mau.events.last! == (.noteOn, 72, 32, 1))
    monitor.polyphonicKeyPressure(source: 123, note: 72, pressure: 69, channel: 2)
    #expect(mau.events.last! == (.keyPressure, 72, 69, 2))
    monitor.controlChange(source: 123, controller: 31, value: 15, channel: 3)
    #expect(mau.events.last! == (.controlChange, 31, 15, 3))
    monitor.programChange(source: 123, program: 91, channel: 4)
    #expect(mau.events.last! == (.programChange, 91, 0, 4))
    monitor.channelPressure(source: 123, pressure: 38, channel: 5)
    #expect(mau.events.last! == (.channelPressure, 38, 0, 5))
    monitor.pitchBendChange(source: 123, value: 77, channel: 6)
    #expect(mau.events.last! == (.pitchBend, 77, 0, 6))
    monitor.pitchBendChange(source: 123, value: 128, channel: 6)
    #expect(mau.events.last! == (.pitchBend, 0, 1, 6))
    monitor.systemReset(source: 123)
    #expect(mau.events.last! == (.reset, 0, 0, 0))
  }

  @Test
  func trafficOmni() {
    let mau = MockAudioUnit()
    let monitor = MIDIMonitor(instrument: mau)
    monitor.noteOn(source: 123, note: 60, velocity: 64, channel: 0)
    #expect(monitor.traffic != nil)
    #expect(monitor.traffic! == MIDITrafficStat(id: 123, channel: 0, accepted: true))
    // Ignore note OFF
    monitor.noteOff(source: 124, note: 60, velocity: 64, channel: 1)
    #expect(monitor.traffic! == MIDITrafficStat(id: 123, channel: 0, accepted: true))
  }

  @Test
  func trafficOneChannel() {
    let mau = MockAudioUnit()
    $midiChannel.withLock { $0 = 1 }
    let monitor = MIDIMonitor(instrument: mau)
    monitor.noteOn(source: 123, note: 60, velocity: 64, channel: 0)
    #expect(monitor.traffic != nil)
    #expect(monitor.traffic! == MIDITrafficStat(id: 123, channel: 0, accepted: false))
    monitor.noteOff(source: 124, note: 60, velocity: 64, channel: 0)
    #expect(monitor.traffic! == MIDITrafficStat(id: 123, channel: 0, accepted: false))
  }

  @Test
  func notesOmni() {
    let mau = MockAudioUnit()
    let monitor = MIDIMonitor(instrument: mau)
    monitor.noteOn(source: 123, note: 60, velocity: 64, channel: 0)
    #expect(monitor.notes != nil)
    #expect(monitor.notes! == .on(Note(midi: 60)))
    monitor.noteOff(source: 124, note: 60, velocity: 64, channel: 1)
    #expect(monitor.notes! == .off(Note(midi: 60)))
  }

  @Test
  func notesOneChannel() {
    let mau = MockAudioUnit()
    $midiChannel.withLock { $0 = 1 }
    let monitor = MIDIMonitor(instrument: mau)
    monitor.noteOn(source: 123, note: 60, velocity: 64, channel: 0)
    #expect(monitor.notes == nil)
    monitor.noteOff(source: 124, note: 60, velocity: 64, channel: 0)
    #expect(monitor.notes == nil)
    monitor.noteOn(source: 123, note: 60, velocity: 64, channel: 1)
    #expect(monitor.notes! == .on(.init(midi: 60)))
    monitor.noteOff(source: 124, note: 60, velocity: 64, channel: 1)
    #expect(monitor.notes! == .off(.init(midi: 60)))
  }

  @Test(
    .dependencies {
      let midi = MIDIProvider.makeMIDI(clientName: "MIDIMonitorTests")
      $0.midiProvider = .init(midiProvider: { midi })
    }
  )
  func didUpdateConnections() {
    let mau = MockAudioUnit()
    $midiChannel.withLock { $0 = 1 }
    let monitor = MIDIMonitor(instrument: mau)

    @Dependency(\.midiProvider) var midiProvider
    let midi = midiProvider.midi()
    midi?.monitor = monitor
    midi?.receiver = monitor

    monitor.didUpdateConnections(connected: [], disappeared: [])
  }

  @Test
  func unusedMethods() {
    let monitor = MIDIMonitor(instrument: MockAudioUnit())
    #expect(throws: Never.self) {
      monitor.didConnect(to: 123123)
      monitor.willUpdateConnections()
      monitor.didInitialize()
      monitor.willUninitialize()
      monitor.didCreate(inputPort: .init(bitPattern: 123123))
      monitor.willDelete(inputPort: .init(bitPattern: 123123))
      monitor.didStart()
      monitor.didStop()
      monitor.didSee(uniqueId: 123123, group: 1, channel: 2)

      monitor.noteOff2(source: 123, note: 84, velocity: 12345, channel: 0, attributeType: 0, attributeData: 0)
      monitor.noteOn2(source: 123, note: 84, velocity: 12345, channel: 1, attributeType: 0, attributeData: 0)
      monitor.polyphonicKeyPressure2(source: 123, note: 84, pressure: 12345, channel: 1)
      monitor.controlChange2(source: 123, controller: 123, value: 123123, channel: 2)
      monitor.programChange2(source: 123, program: 99, bank: 22, channel: 3)
      monitor.channelPressure2(source: 123, pressure: 9876, channel: 4)
      monitor.pitchBendChange2(source: 123, value: 32767, channel: 5)

      monitor.perNotePitchBendChange(source: 1, note: 1, value: 1)
      monitor.timeCodeQuarterFrame(source: 2, value: 2)
      monitor.songPositionPointer(source: 3, value: 3)
      monitor.songSelect(source: 4, value: 4)
      monitor.tuneRequest(source: 5)
      monitor.timingClock(source: 6)
      monitor.startCurrentSequence(source: 7)
      monitor.continueCurrentSequence(source: 8)
      monitor.stopCurrentSequence(source: 9)
      monitor.activeSensing(source: 10)
      monitor.registeredPerNoteControllerChange(source: 11, note: 12, controller: 13, value: 14)
      monitor.assignablePerNoteControllerChange(source: 15, note: 16, controller: 17, value: 18)
      monitor.registeredControllerChange(source: 19, controller: 20, value: 21)
      monitor.assignableControllerChange(source: 22, controller: 23, value: 24)
      monitor.relativeRegisteredControllerChange(source: 25, controller: 26, value: 27)
      monitor.relativeAssignableControllerChange(source: 28, controller: 29, value: 30)
      monitor.perNoteManagement(source: 31, note: 32, detach: false, reset: true)
    }
  }
}
