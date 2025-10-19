import BaseSupport
import ComposableArchitecture
import Dependencies
import DependenciesTestSupport
import Models
import SnapshotTesting
import SwiftUI
import Testing
import TestSupport

@testable import Keyboard

struct MockEventId: SpatialEventId, Hashable {
  let id: Int
  static func ==(a: Self, b: Self) -> Bool { a.id == b.id }
  func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Keyboard.State.EventId {

  static func wrap(_ id: MockEventId) -> Self {
    .init(id, equals: { ($0 as? MockEventId) == ($1 as? MockEventId) })
  }
}

@Suite(
  .snapshots(record: .failed)
)
@MainActor
struct KeyboardTests {

  @Test func keyboardPreviewPortrait() async throws {
    @Shared(.activeState) var activeState
    $activeState.withLock { $0 = .none }
    try TestSupport.assertSnapshot(
      matching: KeyboardPreview(),
      config: .portrait
    )
  }

  @Test func keyboardPreviewLandscape() async throws {
    @Shared(.activeState) var activeState
    $activeState.withLock { $0 = .none }
    try TestSupport.assertSnapshot(
      matching: KeyboardPreview(),
      config: .landscape
    )
  }

  @Test func keyboardRenders64NoLabelsC4() async throws {
    @Shared(.activeState) var activeState
    $activeState.withLock { $0 = .none }
    @Shared(.keyWidth) var keyWidth
    $keyWidth.withLock { $0 = 64.0 }
    @Shared(.keyLabels) var keyLabels
    $keyLabels.withLock { $0 = .none }
    @Shared(.firstVisibleKey) var firstVisibleKey
    $firstVisibleKey.withLock { $0 = .C4 }
    let view = VStack { KeyboardView(store: Store(initialState: Keyboard.State()) { Keyboard() }) }
    try TestSupport.assertSnapshot(matching: view)
  }

  @Test func keyboardRenders48COnlyLabelsA4() async throws {
    @Shared(.activeState) var activeState
    $activeState.withLock { $0 = .none }
    @Shared(.keyWidth) var keyWidth
    $keyWidth.withLock { $0 = 48.0 }
    @Shared(.keyLabels) var keyLabels
    $keyLabels.withLock { $0 = .cOnly }
    @Shared(.firstVisibleKey) var firstVisibleKey
    $firstVisibleKey.withLock { $0 = .A4 }
    let view = VStack { KeyboardView(store: Store(initialState: Keyboard.State()) { Keyboard() }) }
    try TestSupport.assertSnapshot(matching: view)
  }

  @Test func keyboardRenders72AllLabelsE1() async throws {
    @Shared(.activeState) var activeState
    $activeState.withLock { $0 = .none }
    @Shared(.keyWidth) var keyWidth
    $keyWidth.withLock { $0 = 72.0 }
    @Shared(.keyLabels) var keyLabels
    $keyLabels.withLock { $0 = .all }
    @Shared(.firstVisibleKey) var firstVisibleKey
    $firstVisibleKey.withLock { $0 = .E1 }
    let view = VStack { KeyboardView(store: Store(initialState: Keyboard.State()) { Keyboard() }) }
    try TestSupport.assertSnapshot(matching: view)
  }

  @Test func keyboardRendersActiveNotes() async throws {
    @Shared(.activeState) var activeState
    $activeState.withLock { $0 = .none }

    let store = Store(
      initialState: Keyboard.State(activeNotes: [
        (.wrap(MockEventId(id: 1)), .C4),
        (.wrap(MockEventId(id: 2)), .E4),
        (.wrap(MockEventId(id: 3)), .G4)
      ])
    ) {
      Keyboard()
    }
    let view = VStack { KeyboardView(store: store) }
    try TestSupport.assertSnapshot(matching: view)
  }

  @Test func allOffClearsActiveNotes() async throws {
    @Shared(.activeState) var activeState
    $activeState.withLock { $0 = .none }

    let activeNotes: [(Keyboard.State.EventId, Note)] = [
      (.wrap(MockEventId(id: 1)), .C4),
      (.wrap(MockEventId(id: 2)), .E4),
      (.wrap(MockEventId(id: 3)), .G4)
    ]

    let store = TestStore(initialState: Keyboard.State(activeNotes: activeNotes)) { Keyboard() }
    #expect(store.state.eventNoteMap.count == 3)
    #expect(store.state.noteCounters[Note.C4.midiNoteValue] == 1)
    #expect(store.state.noteCounters[Note.E4.midiNoteValue] == 1)
    #expect(store.state.noteCounters[Note.G4.midiNoteValue] == 1)

    await store.send(.allOff) {
      $0.eventNoteMap = [:]
      $0.noteCounters = .init(repeating: 0, count: Note.midiRange.count)
    }
  }

  @Test func touchBegan() async throws {
    let mau = TestSupport.MockAudioUnit()
    @Shared(.midiChannel) var midiChannel = -1
    @Shared(.synthAudioUnit) var synthAudioUnit = mau
    @Shared(.activeState) var activeState
    $activeState.withLock { $0 = .none }

    let store = TestStore(initialState: Keyboard.State()) { Keyboard() }
    let event: Keyboard.State.EventId = .wrap(MockEventId(id: 1))
    let note: Note = .C4

    await store.send(.touchBegan(event, note)) {
      $0.eventNoteMap[event] = note
      $0.noteCounters[note.midiNoteValue] = 1
    }

    await store.receive(.delegate(.noteOn(.C4)))

    #expect(mau.events.count == 1)
    #expect(mau.events[0] == (MIDICoreEvent.noteOn, 60, 127, 0))
  }

  @Test func touchEndedWithoutBegan() async throws {
    let mau = TestSupport.MockAudioUnit()
    @Shared(.midiChannel) var midiChannel = -1
    @Shared(.synthAudioUnit) var synthAudioUnit = mau
    @Shared(.activeState) var activeState
    $activeState.withLock { $0 = .none }

    let store = TestStore(initialState: Keyboard.State()) { Keyboard() }
    let event: Keyboard.State.EventId = .wrap(MockEventId(id: 1))

    await store.send(.touchEnded(event))

    #expect(mau.events.count == 0)
  }

  @Test func touchEndedAfterBegan() async throws {
    let mau = TestSupport.MockAudioUnit()
    @Shared(.midiChannel) var midiChannel = -1
    @Shared(.synthAudioUnit) var synthAudioUnit = mau
    @Shared(.activeState) var activeState
    $activeState.withLock { $0 = .none }

    let store = TestStore(initialState: Keyboard.State()) { Keyboard() }
    let event: Keyboard.State.EventId = .wrap(MockEventId(id: 1))
    let note: Note = .C4

    await store.send(.touchBegan(event, note)) {
      $0.eventNoteMap[event] = note
      $0.noteCounters[note.midiNoteValue] = 1
    }

    await store.receive(.delegate(.noteOn(.C4)))

    await store.send(.touchEnded(event)) {
      $0.eventNoteMap = [:]
      $0.noteCounters[note.midiNoteValue] = 0
    }

    #expect(mau.events.count == 2)
    #expect(mau.events[0] == (MIDICoreEvent.noteOn, 60, 127, 0))
  }
}
