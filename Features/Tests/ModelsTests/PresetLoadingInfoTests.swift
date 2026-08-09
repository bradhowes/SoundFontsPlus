// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import Foundation
import SQLiteData
import Tagged
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

  @Test
  func appActivePresetLoadingInfo() async throws {
    let presets = Preset.all(for: 1)
    var apli = PresetLoadingInfo.for(id: 99999)
    #expect(apli == nil)

    apli = PresetLoadingInfo.for(id: 1)
    #expect(apli != nil)
    #expect(apli?.soundFontId == presets[0].soundFontId)
    #expect(apli?.presetIndex == presets[0].index)
    #expect(apli?.presetName == presets[0].displayName)
    #expect(apli?.originalSoundFontName == "Original " + presets[0].soundFontName)
  }

  @Test
  func activePresetLoadingInfo() async throws {
    let presets = Preset.all(for: 1)
    var apli = PresetLoadingInfo.for(id: 2)
    #expect(apli?.soundFontId == presets[1].soundFontId)
    #expect(apli?.presetIndex == presets[1].index)
    apli = PresetLoadingInfo.for(id: 1)
    #expect(apli?.soundFontId == presets[0].soundFontId)
    #expect(apli?.presetIndex == presets[0].index)
  }

  @Test
  func auv3ActivePresetLoadingInfo() async throws {
    let presets = Preset.all(for: 1)
    var apli = PresetLoadingInfo.for(id: 99999)
    #expect(apli == nil)

    apli = PresetLoadingInfo.for(id: 1)
    #expect(apli != nil)
    #expect(apli?.soundFontId == presets[0].soundFontId)
    #expect(apli?.presetIndex == presets[0].index)
    #expect(apli?.presetName == presets[0].displayName)
    #expect(apli?.originalSoundFontName == "Original " + presets[0].soundFontName)
  }
}
