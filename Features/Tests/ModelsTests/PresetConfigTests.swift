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
  }
}
