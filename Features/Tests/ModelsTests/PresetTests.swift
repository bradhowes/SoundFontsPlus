// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import Foundation
import Sharing
import SQLiteData
import Testing
import TestSupport

@testable import Models

@Suite(
  .dependencies {
    $0.defaultDatabase = TestSupport.testDatabase()
  }
  //  .snapshots(record: .failed)
)
@MainActor
struct PresetTests {

  @MainActor
  func setup() async throws -> [Preset] {
    @Shared(.activeState) var activeState
    $activeState.withLock {
      $0.activeSoundFontId = 1
      $0.activePresetId = 1
    }
    return Operations.presets(for: 1)
  }

  @Test
  func soundFontName() async throws {
    let presets = try await setup()
    #expect(presets[0].soundFontName == "Font 1")
  }

  @Test
  func with() async throws {
    let presets = try await setup()
    let preset = Preset.with(id: 1)
    #expect(presets[0] == preset)
  }

  @Test
  func uniqueName() async throws {
    let presets = try await setup()
    #expect(presets[0].uniqueName == "Font 1 Preset 1 copy")
    let clone1 = presets[0].clone()
    _ = presets[0].clone()
    #expect(presets[0].uniqueName == "Font 1 Preset 1 copy 2")

    withDatabaseWriter { db in
      try Preset.delete()
        .where { $0.id.eq(clone1!.id) }
        .execute(db)
    }

    #expect(presets[0].uniqueName == "Font 1 Preset 1 copy")
    _ = presets[0].clone()
    #expect(presets[0].uniqueName == "Font 1 Preset 1 copy 2")
  }

  @Test
  func clone() async throws {
    let presets = try await setup()

    let clone1 = presets[0].clone()
    #expect(clone1 != nil)
    #expect(clone1?.audioConfig == nil)
    #expect(clone1?.delayConfig == nil)
    #expect(clone1?.reverbConfig == nil)

    AudioConfig.save(config: presets[0].audioConfigDraft)
    DelayConfig.save(config: presets[0].delayConfigDraft)
    ReverbConfig.save(config: presets[0].reverbConfigDraft)

    let clone2 = presets[0].clone()
    #expect(clone2 != nil)
    #expect(clone2?.audioConfig != nil)
    #expect(clone2?.delayConfig != nil)
    #expect(clone2?.reverbConfig != nil)
  }

  @Test
  func toggleVisibility() async throws {
    var presets = try await setup()
    var preset = presets[0]
    #expect(preset.kind == .preset)
    #expect(preset.displayName == "Font 1 Preset 1")
    preset.toggleVisibility()

    presets = withDatabaseReader { db in try Preset.all.fetchAll(db) } ?? []
    presets = Operations.presets(for: nil)
    #expect(presets[0].displayName == "Font 1 Preset 2")
    #expect(presets.count == 1)
    preset.toggleVisibility()

    presets = withDatabaseReader { db in try Preset.all.fetchAll(db) } ?? []
    presets = Operations.presets(for: nil)
    #expect(presets[0].displayName == "Font 1 Preset 1")
    #expect(presets.count == 2)
  }
}
