import ComposableArchitecture
import Dependencies
import DependenciesTestSupport
import Models
import Sharing
import SnapshotTesting
import SwiftUI
import Testing

@testable import Keyboard

struct MockEventId: SpatialEventId, Hashable {
  let id: Int
  static func ==(a: Self, b: Self) -> Bool { a.id == b.id }
  func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

@MainActor
struct EventNoteMapTests {

  @Test
  func assignFixedKeysTest() async throws {
    var uat = EventNoteMap<MockEventId>()
    var result = uat.assign(event: .init(id: 1), note: .C4, fixedKeys: true)
    #expect(result.previous == nil)
    #expect(result.firstTime == true)
    #expect(uat.isOn(.C4) == true)

    result = uat.assign(event: .init(id: 2), note: .D4, fixedKeys: true)
    #expect(result.previous == nil)
    #expect(result.firstTime == true)
    #expect(uat.isOn(.D4))

    result = uat.assign(event: .init(id: 2), note: .E4, fixedKeys: true)
    #expect(result.previous == .D4)
    #expect(result.firstTime == true)
    #expect(uat.isOn(.E4))
    #expect(!uat.isOn(.D4))
  }

  @Test
  func assignSlidingKeysTest() async throws {
    var uat = EventNoteMap<MockEventId>()
    var result = uat.assign(event: .init(id: 1), note: .C4, fixedKeys: false)
    #expect(result.previous == nil)
    #expect(result.firstTime == true)
    #expect(uat.isOn(.C4) == true)

    result = uat.assign(event: .init(id: 2), note: .init(midiNoteValue: 61), fixedKeys: false)
    #expect(result.previous == nil)
    #expect(result.firstTime == true)
    #expect(uat.isOn(.init(midiNoteValue: 61)))

    result = uat.assign(event: .init(id: 2), note: .init(midiNoteValue: 62), fixedKeys: false)
    #expect(result.previous == .init(midiNoteValue: 62))
    #expect(result.firstTime == true)
    #expect(!uat.isOn(.init(midiNoteValue: 62)))
    #expect(uat.isOn(.init(midiNoteValue: 61)))
  }

  @Test
  func releaseTest() async throws {
    var uat = EventNoteMap<MockEventId>()
    _ = uat.assign(event: .init(id: 1), note: .C4, fixedKeys: false)
    #expect(uat.isOn(.C4) == true)

    _ = uat.assign(event: .init(id: 2), note: .init(midiNoteValue: 61), fixedKeys: false)
    #expect(uat.isOn(.init(midiNoteValue: 61)))

    var note = uat.release(event: .init(id: 3))
    #expect(note == nil)

    note = uat.release(event: .init(id: 1))
    #expect(note == .C4)
    #expect(uat.isOn(.C4) == false)
    #expect(uat.isOn(.init(midiNoteValue: 61)) == true)
  }

  @Test
  func releaseMultipleSameNoteTest() async throws {
    var uat = EventNoteMap<MockEventId>()
    _ = uat.assign(event: .init(id: 1), note: .C4, fixedKeys: true)
    #expect(uat.isOn(.C4) == true)

    _ = uat.assign(event: .init(id: 2), note: .D4, fixedKeys: true)
    #expect(uat.isOn(.D4))

    _ = uat.assign(event: .init(id: 2), note: .C4, fixedKeys: true)
    #expect(!uat.isOn(.D4))

    let note = uat.release(event: .init(id: 1))
    #expect(note == nil)
    #expect(uat.isOn(.C4) == true)
  }

  @Test
  func releaseAll() async throws {
    var uat = EventNoteMap<MockEventId>()
    var result = uat.assign(event: .init(id: 1), note: .C4, fixedKeys: false)
    #expect(result.previous == nil)
    #expect(result.firstTime == true)
    #expect(uat.isOn(.C4) == true)

    result = uat.assign(event: .init(id: 2), note: .init(midiNoteValue: 61), fixedKeys: false)
    #expect(result.previous == nil)
    #expect(result.firstTime == true)
    #expect(uat.isOn(.init(midiNoteValue: 61)))

    uat.releaseAll()
    #expect(!uat.isOn(.init(midiNoteValue: 60)))
    #expect(!uat.isOn(.init(midiNoteValue: 61)))
  }
}
