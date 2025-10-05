// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import Foundation
import SQLiteData
import Testing

@testable import Models

extension BaseTestSuite {

  @MainActor
  struct DelayConfigTests {}
}

extension BaseTestSuite.DelayConfigTests {

  @MainActor
  func setup() async throws -> ([Preset], DelayConfig) {
    let presets = withDatabaseReader { db in try Preset.all.fetchAll(db) } ?? []
    var delayConfigDraft = presets[0].delayConfigDraft
    delayConfigDraft.time = 1.5
    delayConfigDraft.enabled = true
    let delayConfig = DelayConfig.save(config: delayConfigDraft)
    return (presets, delayConfig!)
  }

  @Test func draft() async throws {
    let (presets, delayConfig) = try await setup()
    #expect(delayConfig.time == 1.5)
    #expect(delayConfig.feedback == 25.0)
    #expect(delayConfig.cutoff == 12_000.0)
    #expect(delayConfig.wetDryMix == 50.0)
    #expect(delayConfig.enabled == true)
    #expect(delayConfig.presetId == presets[0].id)

    var draft = DelayConfig.draft(for: 2)
    var delayConfigs = withDatabaseReader { try DelayConfig.all.fetchAll($0) } ?? []
    #expect(delayConfigs.count == 1)
    #expect(draft.time == 0.5)
    #expect(draft.feedback == delayConfig.feedback)
    #expect(draft.cutoff == delayConfig.cutoff)
    #expect(draft.wetDryMix == delayConfig.wetDryMix)
    #expect(draft.enabled == false)
    #expect(draft.presetId == 2)

    draft = DelayConfig.draft(for: 2, cloning: .init(delayConfig))
    delayConfigs = withDatabaseReader { try DelayConfig.all.fetchAll($0) } ?? []
    #expect(delayConfigs.count == 1)
    #expect(draft.time == delayConfig.time)
    #expect(draft.feedback == delayConfig.feedback)
    #expect(draft.cutoff == delayConfig.cutoff)
    #expect(draft.wetDryMix == delayConfig.wetDryMix)
    #expect(draft.enabled == false)
    #expect(draft.presetId == 2)

    draft.time = 1.9
    DelayConfig.save(config: draft)

    delayConfigs = withDatabaseReader { try DelayConfig.all.fetchAll($0) } ?? []
    #expect(delayConfigs.count == 2)

    draft = DelayConfig.draft(for: 2, cloning: .init(delayConfig))
    #expect(draft.time == 1.9)
  }

  @Test func save() async throws {
    let (_, delayConfig) = try await setup()
    var draft = DelayConfig.Draft(delayConfig)
    draft.wetDryMix = 100.0
    let savedConfig = DelayConfig.save(config: draft)
    #expect(savedConfig != nil)
    #expect(savedConfig!.wetDryMix == 100.0)
  }

  @Test func deleteCascades() async throws {
    let (_, delayConfig) = try await setup()

    withDatabaseWriter { db in
      try Preset.delete()
        .where { $0.id.eq(delayConfig.presetId) }
        .execute(db)
    }

    #expect(DelayConfig.with(presetId: delayConfig.presetId) == nil)
    #expect(DelayConfig.with(presetId: nil) == nil)
    #expect(DelayConfig.with(presetId: -1) == nil)
  }
}
