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

    var presets = Operations.presets(for: .fluidFont)
    #expect(presets.count == 10)

    let preset3Name = presets[3].displayName
    let clone3 = presets[3].clone()
    #expect(clone3?.displayName == preset3Name + " copy")

    let preset5Name = presets[5].displayName
    let clone5 = presets[5].clone()
    #expect(clone5?.displayName == preset5Name + " copy")

    presets = Operations.presets(for: .fluidFont)
    #expect(presets.count == 12)
    #expect(presets[3].displayName == preset3Name)
    #expect(presets[4].displayName == clone3?.displayName)
    #expect(presets[6].displayName == preset5Name)
    #expect(presets[7].displayName == clone5?.displayName)

    presets = Operations.presets(for: .rolandNicePiano)
    #expect(presets.count == 1)

    $sortPresetsByName.withLock { $0 = true }
    presets = Operations.presets(for: .fluidFont)
    #expect(presets.count == 12)
    #expect(presets[0].displayName == "Bright Yamaha Grand")
    #expect(presets[1].displayName == "Celesta")
    #expect(presets[2].displayName == "Clavinet")
    #expect(presets[3].displayName == "Electric Piano")

    $sortPresetsByName.withLock { $0 = false }
    $favoritesOnTop.withLock { $0 = true }
    presets = Operations.presets(for: .fluidFont)
    #expect(presets.count == SoundFont.testSoundFontPresetLoadLimit + 2)
    #expect(presets[0].displayName == clone3?.displayName)
    #expect(presets[1].displayName == clone5?.displayName)
    #expect(presets[5].displayName == preset3Name)
    #expect(presets[7].displayName == preset5Name)

    presets = Operations.presets(for: .rolandNicePiano)
    #expect(presets.count == 1)

    $sortPresetsByName.withLock { $0 = true }
    presets = Operations.presets(for: .fluidFont)
    #expect(presets.count == SoundFont.testSoundFontPresetLoadLimit + 2)
    #expect(presets[0].displayName == "Honky Tonk copy")
    #expect(presets[1].displayName == "Legend EP 2 copy")
    #expect(presets[2].displayName == "Bright Yamaha Grand")
    #expect(presets[3].displayName == "Celesta")

    $showOnlyFavorites.withLock { $0 = true }

    presets = Operations.presets(for: .fluidFont)
    #expect(presets.count == 2)

    presets = Operations.presets(for: .rolandNicePiano)
    #expect(presets.isEmpty)
  }

  @Test(
    arguments: [false, true]
  )
  func presets(_ showOnlyFavorites: Bool) async throws {
    @Shared(.activeState) var activeState
    @Shared(.selectedSoundFontId) var selectedSoundFontId
    @Shared(.showOnlyFavorites) var showOnlyFavorites = showOnlyFavorites

    let expectedCount = showOnlyFavorites ? 0 : 2
    #expect(Operations.presets(for: nil).count == expectedCount)
    $selectedSoundFontId.withLock { $0 = 2 }
    #expect(Operations.presets(for: nil).count == expectedCount)
    $selectedSoundFontId.withLock { $0 = 3 }
    #expect(Operations.presets(for: nil).isEmpty)
    $selectedSoundFontId.withLock { $0 = nil }
    #expect(Operations.presets(for: nil).count == expectedCount)
    $activeState.withLock { $0.activeSoundFontId = nil }
    #expect(Operations.presets(for: nil).isEmpty)
  }

  @Test
  func allPresets() async throws {
    @Shared(.activeState) var activeState
    @Shared(.selectedSoundFontId) var selectedSoundFontId
    #expect(Operations.allPresets(for: nil).count == 3)
    $selectedSoundFontId.withLock { $0 = 2 }
    #expect(Operations.allPresets(for: nil).count == 3)
    $selectedSoundFontId.withLock { $0 = 3 }
    #expect(Operations.allPresets(for: nil).count == 1)
    $selectedSoundFontId.withLock { $0 = nil }
    $activeState.withLock { $0.activeSoundFontId = nil }
    #expect(Operations.allPresets(for: nil).isEmpty)
  }

  @Test
  func soundFontIdsForTag() async throws {
    #expect(Operations.soundFontIds(for: FontTag.Ubiquitous.all.id) == [1, 2])
    #expect(Operations.soundFontIds(for: FontTag.Ubiquitous.builtIn.id) == [1, 2])
    #expect(Operations.soundFontIds(for: FontTag.Ubiquitous.added.id) == [])
    #expect(Operations.soundFontIds(for: FontTag.Ubiquitous.external.id) == [])
  }

  @Test
  func tagIdsForSoundFont() async throws {
    #expect(Operations.tagIds(for: 1).count == 2)
    #expect(Operations.tagIds(for: 2).count == 2)
    #expect(Operations.tagIds(for: 3).isEmpty)
  }

  @Test
  func tagSoundFont() async throws {
    let newTag = try FontTag.make(displayName: "New Tag")
    Operations.tagSoundFont(newTag.id, soundFontId: 1)
    #expect(Operations.tagIds(for: 1) == [1, 2, 5])
    Operations.tagSoundFont(newTag.id, soundFontId: 1)
    #expect(Operations.tagIds(for: 1) == [1, 2, 5])
    Operations.tagSoundFont(FontTag.Ubiquitous.external.id, soundFontId: 1)
    #expect(Operations.tagIds(for: 1) == [1, 2, 5])
  }

  @Test
  func tagSoundFontIgnoresUbiquitousTags() async throws {
    let newTag = try FontTag.make(displayName: "New Tag")
    Operations.tagSoundFont(newTag.id, soundFontId: 1)
    #expect(Operations.tagIds(for: 1) == [1, 2, 5])
    Operations.tagSoundFont(FontTag.Ubiquitous.external.id, soundFontId: 1)
    #expect(Operations.tagIds(for: 1) == [1, 2, 5])
  }

  @Test
  func untagSoundFont() async throws {
    @Dependency(\.defaultDatabase) var database
    let newTag = try FontTag.make(displayName: "New Tag")
    Operations.tagSoundFont(newTag.id, soundFontId: 1)
    #expect(Operations.tagIds(for: 1) == [1, 2, 5])
    Operations.untagSoundFont(newTag.id, soundFontId: 1)
    #expect(Operations.tagIds(for: 1) == [1, 2])
  }

  @Test
  func untagSoundFontIgnoresUbiquitousTags() async throws {
    @Dependency(\.defaultDatabase) var database
    let newTag = try FontTag.make(displayName: "New Tag")
    Operations.tagSoundFont(newTag.id, soundFontId: 1)
    #expect(Operations.tagIds(for: 1) == [1, 2, 5])
    Operations.untagSoundFont(FontTag.Ubiquitous.all.id, soundFontId: 1)
    #expect(Operations.tagIds(for: 1) == [1, 2, 5])
  }

  @Test
  func activePresetLoadingInfo() async throws {
    let presets = Operations.presets(for: nil)
    @Shared(.activeState) var activeState
    $activeState.withLock { $0.activePresetId = presets[presets.count - 1].id }
    var apli = Operations.presetLoadingInfo()
    #expect(apli?.soundFontId == presets[presets.count - 1].soundFontId)
    #expect(apli?.presetIndex == presets[presets.count - 1].index)
    $activeState.withLock { $0.activePresetId = presets[0].id }
    apli = Operations.presetLoadingInfo()
    #expect(apli?.soundFontId == presets[0].soundFontId)
    #expect(apli?.presetIndex == presets[0].index)
  }

  @Test
  func activePresetAudioConfig() async throws {
    let presets = Operations.presets(for: nil)
    @Dependency(\.defaultDatabase) var database
    @Shared(.activeState) var activeState
    $activeState.withLock { $0.activePresetId = presets[presets.count - 1].id }
    let apac = Operations.presetAudioConfig()
    #expect(apac == nil)
  }
}
