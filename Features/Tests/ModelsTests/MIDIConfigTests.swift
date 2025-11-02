// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import Foundation
import SQLiteData
import Testing
import TestSupport

@testable import Models

@Suite(
  .dependencies {
    $0.defaultDatabase = TestSupport.testDatabase()
  },
  //  .snapshots(record: .failed)
)
@MainActor
struct MIDIConfigTests {

  @MainActor
  func setup() async throws -> MIDIConfig {
    let midiConfigs = withDatabaseWriter { db in
      try MIDIConfig.upsert {
        MIDIConfig.Draft(uniqueId: 12345, autoConnect: true, fixedVolume: 100)
      }
      .returning(\.self)
      .fetchAll(db)
    } ?? []

    return midiConfigs[0]
  }

  @Test
  func with() async throws {
    let midiConfig = try await setup()
    #expect(midiConfig == MIDIConfig.with(id: 12345))
    #expect(midiConfig.id == 12345)
    #expect(nil == MIDIConfig.with(id: 1))
    #expect(nil == MIDIConfig.with(id: 123123))
  }
}
