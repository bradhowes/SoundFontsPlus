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
struct PresetLoadingInfoTests {

  @MainActor
  func setup() async throws -> [Preset] {
    @Shared(.isAUv3) var isAUv3 = true
    @Shared(.activeState) var activeState
    $activeState.withLock { $0 = .none }
    return withDatabaseReader { db in try Preset.all.fetchAll(db) } ?? []
  }

  @Test
  func appActivePresetLoadingInfo() async throws {
    @Shared(.activeState) var activeState

    $activeState.withLock { $0.activePresetId = nil }
    let presets = try await setup()
    var apli = Operations.presetLoadingInfo(id: nil)
    #expect(apli == nil)

    $activeState.withLock { $0.activePresetId = presets[0].id }
    apli = Operations.presetLoadingInfo()
    #expect(apli != nil)
    #expect(apli?.soundFontId == presets[0].soundFontId)
    #expect(apli?.presetIndex == presets[0].index)
    #expect(apli?.presetName == presets[0].displayName)
    #expect(apli?.soundFontName == presets[0].soundFontName)
    #expect(apli?.gain == 0.0)
    #expect(apli?.pan == 0.0)
  }

  @Test
  func auv3ActivePresetLoadingInfo() async throws {
    @Shared(.activeState) var activeState

    $activeState.withLock { $0.activePresetId = nil }
    let presets = try await setup()
    var apli = Operations.presetLoadingInfo(id: nil)
    #expect(apli == nil)

    $activeState.withLock { $0.activePresetId = presets[0].id }
    apli = Operations.presetLoadingInfo()
    #expect(apli != nil)
    #expect(apli?.soundFontId == presets[0].soundFontId)
    #expect(apli?.presetIndex == presets[0].index)
    #expect(apli?.presetName == presets[0].displayName)
    #expect(apli?.soundFontName == presets[0].soundFontName)
    #expect(apli?.gain == 0.0)
    #expect(apli?.pan == 0.0)
  }
}
