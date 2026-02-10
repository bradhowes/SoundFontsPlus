// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
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
)
@MainActor
struct OperationsTests {

  @Test(
    .dependencies {
      $0.defaultDatabase = try appDatabase(loadAllPresets: false)
    },
  )
  func presetsOrdering() async throws {
    @Shared(.favoritesOnTop) var favoritesOnTop = false
    @Shared(.showOnlyFavorites) var showOnlyFavorites = false
    @Shared(.sortPresetsByName) var sortPresetsByName = false

    var presets = Preset.visible(for: .fluidFont)
    #expect(presets.count == 10)

    let preset3Name = presets[3].displayName
    let clone3 = presets[3].clone()
    #expect(clone3?.displayName == preset3Name + " copy")

    let preset5Name = presets[5].displayName
    let clone5 = presets[5].clone()
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
  func presets(_ showOnlyFavorites: Bool) async throws {
    @Shared(.showOnlyFavorites) var showOnlyFavorites = showOnlyFavorites

    let expectedCount = showOnlyFavorites ? 0 : 2
    #expect(Preset.visible(for: 1).count == expectedCount)
    #expect(Preset.visible(for: 2).count == expectedCount)
    #expect(Preset.visible(for: 3).count == expectedCount)
    #expect(Preset.visible(for: 4).count == expectedCount)
    #expect(Preset.visible(for: 5).isEmpty)
  }

  @Test
  func allPresets() async throws {
    #expect(Preset.all(for: 1).count == 3)
    #expect(Preset.all(for: 2).count == 3)
    #expect(Preset.all(for: 3).count == 3)
    #expect(Preset.all(for: 5).isEmpty)
  }

  @Test
  func soundFontIdsForTag() async throws {
    @Shared(.hideBuiltinFonts) var hideBuiltinFonts = false
    @Shared(.hideEmptyTags) var hideEmptyTags = false
    #expect(Operations.soundFontIds(for: Tag.Ubiquitous.all.id) == [1, 2, 3, 4])
    #expect(Operations.soundFontIds(for: Tag.Ubiquitous.builtIn.id) == [1, 2])
    #expect(Operations.soundFontIds(for: Tag.Ubiquitous.added.id) == [3, 4])
    #expect(Operations.soundFontIds(for: Tag.Ubiquitous.external.id) == [4])
  }

  @Test
  func tagIdsForSoundFont() async throws {
    #expect(SoundFont.with(id: 1)?.tags.count == 2)
    #expect(SoundFont.with(id: 2)?.tags.count == 2)
    #expect(SoundFont.with(id: 3)?.tags.map(\.id) == [-4, -3, -1])
  }

  @Test
  func tagSoundFont() async throws {
    let newTag = try Tag.make(displayName: "New Tag")
    Operations.tagSoundFont(newTag.id, soundFontId: 1)
    #expect(SoundFont.with(id: 1)?.tags.map(\.id) == [-2, -1, 1])
    Operations.tagSoundFont(newTag.id, soundFontId: 1)
    #expect(SoundFont.with(id: 1)?.tags.map(\.id) == [-2, -1, 1])
    Operations.tagSoundFont(Tag.Ubiquitous.external.id, soundFontId: 1)
    #expect(SoundFont.with(id: 1)?.tags.map(\.id) == [-2, -1, 1])
  }

  @Test
  func tagSoundFontIgnoresUbiquitousTags() async throws {
    let newTag = try Tag.make(displayName: "New Tag")
    Operations.tagSoundFont(newTag.id, soundFontId: 1)
    #expect(SoundFont.with(id: 1)?.tags.map(\.id) == [-2, -1, 1])
    Operations.tagSoundFont(Tag.Ubiquitous.external.id, soundFontId: 1)
    #expect(SoundFont.with(id: 1)?.tags.map(\.id) == [-2, -1, 1])
  }

  @Test
  func untagSoundFont() async throws {
    @Dependency(\.defaultDatabase) var database
    let newTag = try Tag.make(displayName: "New Tag")
    Operations.tagSoundFont(newTag.id, soundFontId: 1)
    #expect(SoundFont.with(id: 1)?.tags.map(\.id) == [-2, -1, 1])
    Operations.untagSoundFont(newTag.id, soundFontId: 1)
    #expect(SoundFont.with(id: 1)?.tags.map(\.id) == [-2, -1])
  }

  @Test
  func untagSoundFontIgnoresUbiquitousTags() async throws {
    @Dependency(\.defaultDatabase) var database
    let newTag = try Tag.make(displayName: "New Tag")
    Operations.tagSoundFont(newTag.id, soundFontId: 1)
    #expect(SoundFont.with(id: 1)?.tags.map(\.id) == [-2, -1, 1])
    Operations.untagSoundFont(Tag.Ubiquitous.all.id, soundFontId: 1)
    #expect(SoundFont.with(id: 1)?.tags.map(\.id) == [-2, -1, 1])
  }

  @Test
  func activePresetLoadingInfo() async throws {
    let presets = Preset.visible(for: 1)
    var apli = Operations.presetLoadingInfo(id: 2)
    #expect(apli?.soundFontId == presets[presets.count - 1].soundFontId)
    #expect(apli?.presetIndex == presets[presets.count - 1].index)
    apli = Operations.presetLoadingInfo(id: 1)
    #expect(apli?.soundFontId == presets[0].soundFontId)
    #expect(apli?.presetIndex == presets[0].index)
  }
}
