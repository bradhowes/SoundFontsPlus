// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import Foundation
import Sharing
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
struct PresetTests {

  @Shared(.favoritesOnTop) var favoritesOnTop = false
  @Shared(.showOnlyFavorites) var showOnlyFavorites = false
  @Shared(.sortPresetsByName) var sortPresetsByName = false

  init() {
    $favoritesOnTop.withLock { $0 = false }
    $showOnlyFavorites.withLock { $0 = false }
    $sortPresetsByName.withLock { $0 = false }
  }

  @Test
  func soundFontName() async throws {
    let presets = Preset.visible(for: 1)
    #expect(presets[0].soundFontName == "Font 1")
  }

  @Test
  func with() async throws {
    let presets = Preset.visible(for: 1)
    let preset = Preset.with(id: 1)
    #expect(presets[0] == preset)
  }

  @Test(
    .dependencies {
      $0.defaultDatabase = try appDatabase(loadAllPresets: false)
    }
  )
  func presetsOrdering() async throws {
    var presets = Preset.visible(for: .fluidFont)
    #expect(presets.count == 10)

    let preset3Name = presets[3].displayName
    let clone3 = presets[3].cloneFavorite()
    #expect(clone3?.displayName == preset3Name + " copy")

    let preset5Name = presets[5].displayName
    let clone5 = presets[5].cloneFavorite()
    #expect(clone5?.displayName == preset5Name + " copy")

    presets = Preset.visible(for: .fluidFont)
    #expect(presets.count == 12)
    #expect(presets[3].displayName == preset3Name)
    #expect(presets[4].displayName == clone3?.displayName)
    #expect(presets[6].displayName == preset5Name)
    #expect(presets[7].displayName == clone5?.displayName)

    presets = Preset.visible(for: .rolandNicePiano)
    #expect(presets.count == 1)

    $sortPresetsByName.withLock { $0 = true }
    presets = Preset.visible(for: .fluidFont)
    #expect(presets.count == 12)
    #expect(presets[0].displayName == "Bright Yamaha Grand")
    #expect(presets[1].displayName == "Celesta")
    #expect(presets[2].displayName == "Clavinet")
    #expect(presets[3].displayName == "Electric Piano")

    $sortPresetsByName.withLock { $0 = false }
    $favoritesOnTop.withLock { $0 = true }
    presets = Preset.visible(for: .fluidFont)
    #expect(presets.count == SoundFont.testSoundFontPresetLoadLimit + 2)
    #expect(presets[0].displayName == clone3?.displayName)
    #expect(presets[1].displayName == clone5?.displayName)
    #expect(presets[5].displayName == preset3Name)
    #expect(presets[7].displayName == preset5Name)

    presets = Preset.visible(for: .rolandNicePiano)
    #expect(presets.count == 1)

    $sortPresetsByName.withLock { $0 = true }
    presets = Preset.visible(for: .fluidFont)
    #expect(presets.count == SoundFont.testSoundFontPresetLoadLimit + 2)
    #expect(presets[0].displayName == "Honky Tonk copy")
    #expect(presets[1].displayName == "Legend EP 2 copy")
    #expect(presets[2].displayName == "Bright Yamaha Grand")
    #expect(presets[3].displayName == "Celesta")

    $showOnlyFavorites.withLock { $0 = true }

    presets = Preset.visible(for: .fluidFont)
    #expect(presets.count == 2)

    presets = Preset.visible(for: .rolandNicePiano)
    #expect(presets.isEmpty)
  }

  @Test(
    arguments: [false, true]
  )
  func visible(_ showOnlyFavorites: Bool) async throws {
    $showOnlyFavorites.withLock { $0 = showOnlyFavorites }

    let expectedCount = showOnlyFavorites ? 0 : 2
    #expect(Preset.visible(for: 1).count == expectedCount)
    #expect(Preset.visible(for: 2).count == expectedCount)
    #expect(Preset.visible(for: 3).count == expectedCount)
    #expect(Preset.visible(for: 4).count == expectedCount)
    #expect(Preset.visible(for: 5).isEmpty)
  }

  @Test
  func all() async throws {
    #expect(Preset.all(for: 1).count == 3)
    #expect(Preset.all(for: 2).count == 3)
    #expect(Preset.all(for: 3).count == 3)
    #expect(Preset.all(for: 5).isEmpty)
  }

  @Test
  func uniqueName() async throws {
    let presets = Preset.visible(for: 1)
    #expect(presets[0].uniqueName == "Font 1 Preset 1 copy")
    let clone1 = presets[0].cloneFavorite()
    _ = presets[0].cloneFavorite()
    #expect(presets[0].uniqueName == "Font 1 Preset 1 copy 2")

    withDatabaseWriter { db in
      try Preset.delete()
        .where { $0.id.eq(clone1!.id) }
        .execute(db)
    }

    #expect(presets[0].uniqueName == "Font 1 Preset 1 copy")
    _ = presets[0].cloneFavorite()
    #expect(presets[0].uniqueName == "Font 1 Preset 1 copy 2")
  }

  @Test
  func clone() async throws {
    let presets = Preset.visible(for: 1)

    let clone1 = presets[0].cloneFavorite()
    #expect(clone1 != nil)
    #expect(clone1?.audioConfig == nil)
    #expect(clone1?.delayConfig == nil)
    #expect(clone1?.reverbConfig == nil)

    AudioConfig.save(config: presets[0].audioConfigDraft)
    DelayConfig.save(config: presets[0].delayConfigDraft)
    ReverbConfig.save(config: presets[0].reverbConfigDraft)

    let clone2 = presets[0].cloneFavorite()
    #expect(clone2 != nil)
    #expect(clone2?.audioConfig != nil)
    #expect(clone2?.delayConfig != nil)
    #expect(clone2?.reverbConfig != nil)
  }

  @Test
  func toggleVisibility() async throws {
    var presets = Preset.visible(for: 1)
    var preset = presets[0]
    #expect(preset.kind == .preset)
    #expect(preset.displayName == "Font 1 Preset 1")
    preset.toggleVisibility()

    presets = Preset.visible(for: 1)
    #expect(presets[0].displayName == "Font 1 Preset 2")
    #expect(presets.count == 1)
    preset.toggleVisibility()

    presets = Preset.visible(for: 1)
    #expect(presets[0].displayName == "Font 1 Preset 1")
    #expect(presets.count == 2)
  }
}
