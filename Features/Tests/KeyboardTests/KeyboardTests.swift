// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import SnapshotTesting
import FeatureSupport
import SQLiteData
import Testing
import TestSupport

@testable import Keyboard

struct MockEventId: SpatialEventId, Hashable {
  let id: Int
  static func == (a: Self, b: Self) -> Bool { a.id == b.id }
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

  @Test
  func keyboardPreviewPortrait() async throws {
    TestSupport.assertSnapshot(
      matching: KeyboardPreview(),
      config: .portrait
    )
  }

  @Test
  func keyboardPreviewLandscape() async throws {
    TestSupport.assertSnapshot(
      matching: KeyboardPreview(),
      config: .landscape
    )
  }

  @Test
  func keyboardRenders64NoLabelsC4() async throws {
    @Shared(.keyWidth) var keyWidth = 64.0
    @Shared(.keyLabels) var keyLabels = .none
    @Shared(.firstVisibleKey) var firstVisibleKey = .C4
    let view = VStack { KeyboardView(store: Store(initialState: Keyboard.State()) { Keyboard() }) }
    TestSupport.assertSnapshot(matching: view)
  }

  @Test
  func keyboardRenders48COnlyLabelsA4() async throws {
    @Shared(.keyWidth) var keyWidth = 48.0
    @Shared(.keyLabels) var keyLabels = .cOnly
    @Shared(.firstVisibleKey) var firstVisibleKey = .A4
    let view = VStack { KeyboardView(store: Store(initialState: Keyboard.State()) { Keyboard() }) }
    TestSupport.assertSnapshot(matching: view)
  }

  @Test
  func keyboardRenders72AllLabelsE1() async throws {
    @Shared(.keyWidth) var keyWidth = 72.0
    @Shared(.keyLabels) var keyLabels = .all
    @Shared(.firstVisibleKey) var firstVisibleKey = .E1
    let view = VStack { KeyboardView(store: Store(initialState: Keyboard.State()) { Keyboard() }) }
    TestSupport.assertSnapshot(matching: view)
  }

  @Test
  func keyboardRendersActiveNotes() async throws {
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
    TestSupport.assertSnapshot(matching: view)
  }

  @Test
  func keyboardRendersRedActiveNotesWhenMuted() async throws {
    let store = Store(
      initialState: Keyboard.State(
        muted: true,
        activeNotes: [
          (.wrap(MockEventId(id: 1)), .C4),
          (.wrap(MockEventId(id: 2)), .E4),
          (.wrap(MockEventId(id: 3)), .G4)
        ]
      )
    ) {
      Keyboard()
    }
    let view = VStack { KeyboardView(store: store) }
    TestSupport.assertSnapshot(matching: view)
  }

  @Test
  func allOffClearsActiveNotes() async throws {
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

  @Test
  func touchBegan() async throws {
    let mau = MockAudioUnit()
    @Shared(.midiChannel) var midiChannel = -1

    let store = TestStore(initialState: Keyboard.State()) { Keyboard() }
    let event: Keyboard.State.EventId = .wrap(MockEventId(id: 1))
    let note: Note = .C4

    await store.send(.midiInstrumentCreated(mau)) {
      $0.midiInstrument = mau
    }

    await store.send(.touchBegan(event, note)) {
      $0.eventNoteMap[event] = note
      $0.noteCounters[note.midiNoteValue] = 1
    }

    await store.receive(\.delegate.noteOn, .C4)

    #expect(mau.events.count == 1)
    #expect(mau.events[0] == (MIDICoreEvent.noteOn, 60, 127, 0))
  }

  @Test
  func touchEndedWithoutBegan() async throws {
    let mau = MockAudioUnit()
    @Shared(.midiChannel) var midiChannel = -1

    let store = TestStore(initialState: Keyboard.State()) { Keyboard() }

    await store.send(.midiInstrumentCreated(mau)) {
      $0.midiInstrument = mau
    }

    let event: Keyboard.State.EventId = .wrap(MockEventId(id: 1))

    await store.send(.touchEnded(event))

    #expect(mau.events.isEmpty)
  }

  @Test
  func touchEndedAfterBegan() async throws {
    let mau = MockAudioUnit()
    @Shared(.midiChannel) var midiChannel = -1

    let store = TestStore(initialState: Keyboard.State()) { Keyboard() }
    let event: Keyboard.State.EventId = .wrap(MockEventId(id: 1))
    let note: Note = .C4

    await store.send(.midiInstrumentCreated(mau)) {
      $0.midiInstrument = mau
    }

    await store.send(.touchBegan(event, note)) {
      $0.eventNoteMap[event] = note
      $0.noteCounters[note.midiNoteValue] = 1
    }

    await store.receive(\.delegate.noteOn, .C4)

    await store.send(.touchEnded(event)) {
      $0.eventNoteMap = [:]
      $0.noteCounters[note.midiNoteValue] = 0
    }

    #expect(mau.events.count == 2)
    #expect(mau.events[0] == (MIDICoreEvent.noteOn, 60, 127, 0))
  }

  @Test
  func outputVolumeChanged() async throws {
    let store = TestStore(initialState: Keyboard.State()) { Keyboard() }
    await store.send(.outputVolumeStateChanged(.muted)) {
      $0.muted = true
    }
    await store.send(.outputVolumeStateChanged(.unmuted)) {
      $0.muted = false
    }
  }

  @Test(
    .dependencies {
      $0.defaultDatabase = TestSupport.testDatabase(seeder: addAudioConfig)
    },
  )
  func activePresetIdChanged() async throws {
    let store = TestStore(initialState: Keyboard.State()) { Keyboard() }
    await store.send(\.activePresetIdChanged, 1)

    await store.receive(\.scrollTo, .G5) {
      $0.scrollTo = .G5
    }

    await store.send(\.activePresetIdChanged, 2)

    await store.send(\.activePresetIdChanged, 3)

    await store.receive(\.scrollTo, .A2) {
      $0.scrollTo = .A2
    }

    await store.send(\.activePresetIdChanged, 4)

    await store.send(\.activePresetIdChanged, nil)

    await store.send(.deinitialize)
  }
}

func addAudioConfig(_ db: Database) throws {
  try TestSupport.addMockPresets(db)
  try AudioConfig.insert {
    AudioConfig.Draft(
      keyboardLowestNoteEnabled: true,
      keyboardLowestNote: .G5,
      presetId: 1
    )
    AudioConfig.Draft(
      keyboardLowestNoteEnabled: false,
      keyboardLowestNote: .A2,
      presetId: 2
    )
    AudioConfig.Draft(
      keyboardLowestNoteEnabled: true,
      keyboardLowestNote: .A2,
      presetId: 3
    )
  }
  .execute(db)
}
