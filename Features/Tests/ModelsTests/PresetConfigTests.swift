// Copyright © 2026 Brad Howes. All rights reserved.

import BaseSupport
import DependenciesTestSupport
import Foundation
import SQLiteData
import Tagged
import Testing
import TestSupport

@testable import Models

@Suite(
  .dependencies {
    $0.defaultDatabase = TestSupport.testDatabase(seeder: TestSupport.addMockPresets)
  },
)
@MainActor
struct PresetConfigTests {

  @MainActor
  func setup(generatorId: Int, value: Double) async throws -> ([Preset], PresetConfig) {
    let presets = withDatabaseReader { db in try Preset.all.fetchAll(db) } ?? []
    let presetConfig = withDatabaseWriter { db in
      try PresetConfig.upsert {
        PresetConfig.Draft(presetId: presets[0].id, generatorId: generatorId, value: value)
      }
      .returning(\.self)
      .fetchAll(db)
    }

    return (presets, presetConfig![0])
  }

  @Test
  func createNew() async throws {
    let (presets, presetConfig) = try await setup(generatorId: 123, value: 456.78)
    #expect(presetConfig.id.generatorId == 123)
    #expect(presetConfig.id.presetId == presets[0].id)
    #expect(presetConfig.value == 456.78)
    var configs = PresetConfig.with(presetId: presets[0].id)
    #expect(configs.count == 1)
    configs = PresetConfig.with(presetId: presets[1].id)
    #expect(configs.isEmpty)
  }

  @Test
  func createMultiple() async throws {
    let (presets, presetConfig) = try await setup(generatorId: 123, value: 456.78)
    #expect(presetConfig.id.generatorId == 123)
    #expect(presetConfig.id.presetId == presets[0].id)
    #expect(presetConfig.value == 456.78)

    withDatabaseWriter { db in
      try PresetConfig.upsert {
        PresetConfig.Draft(presetId: presets[0].id, generatorId: 124, value: 987.65)
      }
      .execute(db)
    }

    let configs0 = PresetConfig.with(presetId: presets[0].id)
    #expect(configs0.count == 2)
    #expect(configs0[0].id.generatorId == 123)
    #expect(configs0[1].id.generatorId == 124)
    let configs1 = PresetConfig.with(presetId: presets[1].id)
    #expect(configs1.isEmpty)
  }

  @Test
  func deleteCascades() async throws {
    let (presets, _) = try await setup(generatorId: 123, value: 456.78)
    #expect(PresetConfig.with(presetId: presets[0].id).count == 1)
    withDatabaseWriter { db in
      try Preset.all.where { $0.id.eq(presets[0].id) }
        .delete()
        .execute(db)
    }

    #expect(PresetConfig.with(presetId: presets[0].id).isEmpty)
  }
}
