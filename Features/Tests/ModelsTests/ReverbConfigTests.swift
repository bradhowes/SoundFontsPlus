// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import Foundation
import SQLiteData
import Testing
import TestSupport

@testable import Models

@Suite(
  .dependencies {
    $0.defaultDatabase = TestSupport.testDatabase(seeder: TestSupport.addMockPresets)
  },
  //  .snapshots(record: .failed)
)
@MainActor
struct ReverbConfigTests {

  @MainActor
  func setup() async throws -> ([Preset], ReverbConfig) {
    @Dependency(\.defaultDatabase) var database
    let presets = try await database.read { try Preset.all.fetchAll($0) }
    var reverbConfigDraft = presets[0].reverbConfigDraft
    reverbConfigDraft.roomPreset = .plate
    reverbConfigDraft.enabled = true
    let reverbConfig = ReverbConfig.save(config: reverbConfigDraft)
    return (presets, reverbConfig!)
  }

  @Test
  func draft() async throws {
    let (presets, reverbConfig) = try await setup()
    #expect(reverbConfig.roomPreset == .plate)
    #expect(reverbConfig.wetDryMix == 25.0)
    #expect(reverbConfig.enabled == true)
    #expect(reverbConfig.presetId == presets[0].id)

    var draft = ReverbConfig.draft(for: 2)
    var reverbConfigs = withDatabaseReader { try ReverbConfig.all.fetchAll($0) } ?? []
    #expect(reverbConfigs.count == 1)
    #expect(draft.roomPreset == .mediumHall)
    #expect(draft.wetDryMix == reverbConfig.wetDryMix)
    #expect(draft.enabled == false)
    #expect(draft.presetId == 2)

    draft = ReverbConfig.draft(for: 2, cloning: .init(reverbConfig))
    reverbConfigs = withDatabaseReader { try ReverbConfig.all.fetchAll($0) } ?? []
    #expect(reverbConfigs.count == 1)
    #expect(draft.roomPreset == reverbConfig.roomPreset)
    #expect(draft.wetDryMix == reverbConfig.wetDryMix)
    #expect(draft.enabled == false)
    #expect(draft.presetId == 2)

    draft.roomPreset = .cathedral
    ReverbConfig.save(config: draft)

    reverbConfigs = withDatabaseReader { try ReverbConfig.all.fetchAll($0) } ?? []
    #expect(reverbConfigs.count == 2)

    draft = ReverbConfig.draft(for: 2, cloning: .init(reverbConfig))
    #expect(draft.roomPreset == .cathedral)
  }

  @Test
  func save() async throws {
    let (_, reverbConfig) = try await setup()
    var draft = ReverbConfig.Draft(reverbConfig)
    draft.wetDryMix = 100.0
    let savedConfig = ReverbConfig.save(config: draft)
    #expect(savedConfig != nil)
    #expect(savedConfig!.wetDryMix == 100.0)
  }

  @Test
  func deleteCascades() async throws {
    let (_, reverbConfig) = try await setup()

    withDatabaseWriter { db in
      try Preset.delete()
        .where { $0.id.eq(reverbConfig.presetId) }
        .execute(db)
    }

    #expect(ReverbConfig.with(presetId: reverbConfig.presetId) == nil)
    #expect(ReverbConfig.with(presetId: nil) == nil)
    #expect(ReverbConfig.with(presetId: -1) == nil)
  }
}
