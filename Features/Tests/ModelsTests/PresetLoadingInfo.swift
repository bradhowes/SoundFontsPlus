// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import Foundation
import Sharing
import SQLiteData
import Testing

@testable import Models

extension BaseTestSuite {
  @MainActor
  struct PresetLoadingInfoTests {}
}

extension BaseTestSuite.PresetLoadingInfoTests {

  @MainActor
  func setup() async throws -> [Preset] {
    withDatabaseReader { db in try Preset.all.fetchAll(db) } ?? []
  }

  @Test func activePresetLoadingInfo() async throws {
    @Shared(.activeState) var activeState

    $activeState.withLock { $0.activePresetId = nil }
    let presets = try await setup()
    var apli = Operations.activePresetLoadingInfo
    #expect(apli == nil)

    $activeState.withLock { $0.activePresetId = presets[0].id }
    apli = Operations.activePresetLoadingInfo
    #expect(apli != nil)
    #expect(apli?.soundFontId == presets[0].soundFontId)
    #expect(apli?.presetIndex == presets[0].index)
    #expect(apli?.presetName == presets[0].displayName)
    #expect(apli?.soundFontName == presets[0].soundFontName)
    #expect(apli?.gain == 0.0)
    #expect(apli?.pan == 0.0)
  }
}
