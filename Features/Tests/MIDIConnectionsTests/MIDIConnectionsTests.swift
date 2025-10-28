// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import MorkAndMIDI
import SnapshotTesting
import Testing
import TestSupport

@testable import MIDIConnections

@Suite(
  .dependencies {
    $0.defaultDatabase = try appDatabase()
  }
)
@MainActor
struct MIDIConnectionsTests {

  func store(rows: [MIDIConnectionRow]? = nil) -> TestStoreOf<MIDIConnections> {
    return TestStoreOf<MIDIConnections>(
      initialState: .init(
        rows: rows ?? [
          .init(id: 1, displayName: "Foo", channel: 0, fixedVolume: 128, autoConnect: false),
          .init(id: 2, displayName: "Bar", channel: 1, fixedVolume: 64, autoConnect: true),
          .init(id: 3, displayName: "Bar", channel: 255, fixedVolume: 127, autoConnect: true)
        ]
      )
    ) {
      MIDIConnections()
    }
  }

  @Test func autoConnectToggleTapped() async {
    let store = store()
    #expect(store.state.rows.count == 3)
    await store.send(.autoConnectToggleTapped(1)) {
      $0.rows[0].autoConnect = true
    }
    await store.send(.autoConnectToggleTapped(2)) {
      $0.rows[1].autoConnect = false
    }

    let rows = withDatabaseReader { db in
      try MIDIConfig.all.order(by: \.uniqueId).fetchAll(db)
    } ?? []

    #expect(rows.count == 2)
    #expect(rows[0].autoConnect == true)
    #expect(rows[1].autoConnect == false)
  }

  @Test func fixedVolumeDecrementTapped() async {
    let store = store()
    #expect(store.state.rows.count == 3)
    await store.send(.fixedVolumeDecrementTapped(1)) {
      $0.rows[0].fixedVolume = 127
    }
    await store.send(.fixedVolumeDecrementTapped(2)) {
      $0.rows[1].fixedVolume = 63
    }
    let rows = withDatabaseReader { db in
      try MIDIConfig.all.order(by: \.uniqueId).fetchAll(db)
    } ?? []

    #expect(rows.count == 2)
    #expect(rows[0].fixedVolume == 127)
    #expect(rows[1].fixedVolume == 63)
  }

  @Test func fixedVolumeIncrementTapped() async {
    let store = store()
    #expect(store.state.rows.count == 3)
    await store.send(.fixedVolumeIncrementTapped(1)) {
      $0.rows[0].fixedVolume = 129
    }
    await store.send(.fixedVolumeIncrementTapped(2)) {
      $0.rows[1].fixedVolume = 65
    }
    let rows = withDatabaseReader { db in
      try MIDIConfig.all.order(by: \.uniqueId).fetchAll(db)
    } ?? []

    #expect(rows.count == 2)
    #expect(rows[0].fixedVolume == 129)
    #expect(rows[1].fixedVolume == 65)
  }

  @Test func sawMIDITraffic() async {
    let store = store()
    #expect(store.state.rows.count == 3)

    let traffic = MIDITraffic(id: 1, channel: 8, accepted: true)
    await store.send(.sawMIDITraffic(traffic)) {
      $0.rows[0].channel = 8
      $0.midiChannelsCache[1] = 8
    }
  }

  @Test func updateMIDIConnections() async {
    let store = store()
    #expect(store.state.rows.count == 3)

    await store.send(.autoConnectToggleTapped(1)) {
      $0.rows[0].autoConnect = true
    }
    await store.send(.autoConnectToggleTapped(2)) {
      $0.rows[1].autoConnect = false
    }
    await store.send(.fixedVolumeDecrementTapped(1)) {
      $0.rows[0].fixedVolume = 127
    }
    await store.send(.fixedVolumeDecrementTapped(2)) {
      $0.rows[1].fixedVolume = 63
    }

    let sourceConnections: [MIDI.SourceConnectionState] = [
      .init(uniqueId: 1, displayName: "Food", connected: false),
      .init(uniqueId: 2, displayName: "Barry", connected: true),
      .init(uniqueId: 4, displayName: "New", connected: false)
    ]

    await store.send(.midiConnectionsChanged(sourceConnections)) {
      $0.rows[0] = .init(id: 1, displayName: "Food", fixedVolume: 127, autoConnect: false)
      $0.rows[1] = .init(id: 2, displayName: "Barry", fixedVolume: 63, autoConnect: false)
      $0.rows[2] = .init(id: 4, displayName: "New", fixedVolume: 128, autoConnect: true)
    }
  }

  @Test(arguments: [false, true]) func honorsMIDIAutoConnect(_ autoConnect: Bool) async {
    @Shared(.midiAutoConnect) var midiAutoConnect = autoConnect
    let store = store()
    #expect(store.state.rows.count == 3)

    let sourceConnections: [MIDI.SourceConnectionState] = [
      .init(uniqueId: 4, displayName: "New 1", connected: false),
      .init(uniqueId: 5, displayName: "New 2", connected: true)
    ]

    await store.send(.midiConnectionsChanged(sourceConnections)) {
      $0.rows = [
        .init(id: 4, displayName: "New 1", fixedVolume: 128, autoConnect: autoConnect),
        .init(id: 5, displayName: "New 2", fixedVolume: 128, autoConnect: autoConnect),
      ]
    }
  }

  @Test func previewAutoConnect() async throws {
    try withSnapshotTesting(record: .failed) {
      try TestSupport.assertSnapshot(matching: MIDIConnectionsView.preview)
    }
  }

  @Test func previewNoAutoConnect() async throws {
    @Shared(.midiAutoConnect) var midiAutoConnect = false
    try withSnapshotTesting(record: .failed) {
      try TestSupport.assertSnapshot(matching: MIDIConnectionsView.preview)
    }
  }
}
