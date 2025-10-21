// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import Foundation
import Sharing
import SQLiteData
import Testing

@testable import Models

@Suite(
  .dependencies {
    $0.defaultDatabase = try appDatabase()
  },
  //  .snapshots(record: .failed)
)
@MainActor
struct OperationsTests {

  @Test func presetsOrdering() async throws {
    var presets = Operations.presets(for: .fluidFont)
    #expect(presets.count == 10)

    let preset3Name = presets[3].displayName
    let clone3 = presets[3].clone()
    #expect(clone3?.displayName == preset3Name + " copy")

    let preset5Name = presets[5].displayName
    let clone5 = presets[5].clone()
    #expect(clone5?.displayName == preset5Name + " copy")

    @Shared(.favoritesOnTop) var favoritesOnTop
    $favoritesOnTop.withLock { $0 = false }
    presets = Operations.presets(for: .fluidFont)
    #expect(presets.count == 12)
    #expect(presets[3].displayName == preset3Name)
    #expect(presets[4].displayName == clone3?.displayName)
    #expect(presets[6].displayName == preset5Name)
    #expect(presets[7].displayName == clone5?.displayName)

    presets = Operations.presets(for: .rolandNicePiano)
    #expect(presets.count == 1)

    $favoritesOnTop.withLock { $0 = true }
    presets = Operations.presets(for: .fluidFont)
    #expect(presets.count == SoundFont.soundFontPresetLoadLimit + 2)
    #expect(presets[0].displayName == clone3?.displayName)
    #expect(presets[1].displayName == clone5?.displayName)
    #expect(presets[5].displayName == preset3Name)
    #expect(presets[7].displayName == preset5Name)

    presets = Operations.presets(for: .rolandNicePiano)
    #expect(presets.count == 1)

    @Shared(.showOnlyFavorites) var showOnlyFavorites
    $showOnlyFavorites.withLock { $0 = true }

    presets = Operations.presets(for: .fluidFont)
    #expect(presets.count == 2)

    presets = Operations.presets(for: .rolandNicePiano)
    #expect(presets.count == 0)
  }

  @Test func presets() async throws {
    @Shared(.activeState) var activeState
    @Shared(.selectedSoundFontId) var selectedSoundFontId
    #expect(Operations.presets(for: nil).count == SoundFont.soundFontPresetLoadLimit)
    $selectedSoundFontId.withLock { $0 = .init(rawValue: 2) }
    #expect(Operations.presets(for: nil).count == SoundFont.soundFontPresetLoadLimit)
    $selectedSoundFontId.withLock { $0 = .init(rawValue: 3) }
    #expect(Operations.presets(for: nil).count == SoundFont.soundFontPresetLoadLimit)
    $selectedSoundFontId.withLock { $0 = nil }
    #expect(Operations.presets(for: nil).count == SoundFont.soundFontPresetLoadLimit)
    $activeState.withLock { $0.activeSoundFontId = nil }
    #expect(Operations.presets(for: nil).count == 0)
  }

  @Test func allPresets() async throws {
    @Shared(.activeState) var activeState
    @Shared(.selectedSoundFontId) var selectedSoundFontId
    #expect(Operations.allPresets(for: nil).count == SoundFont.soundFontPresetLoadLimit)
    $selectedSoundFontId.withLock { $0 = .init(rawValue: 2) }
    #expect(Operations.allPresets(for: nil).count == SoundFont.soundFontPresetLoadLimit)
    $selectedSoundFontId.withLock { $0 = .init(rawValue: 3) }
    #expect(Operations.allPresets(for: nil).count == SoundFont.soundFontPresetLoadLimit)
    $selectedSoundFontId.withLock { $0 = nil }
    $activeState.withLock { $0.activeSoundFontId = nil }
    #expect(Operations.allPresets(for: nil).count == 0)
  }

  @Test func soundFontIdsForTag() async throws {
    #expect(Operations.soundFontIds(for: FontTag.Ubiquitous.all.id) == [1, 2, 3, 4])
    #expect(Operations.soundFontIds(for: FontTag.Ubiquitous.builtIn.id) == [1, 2, 3, 4])
    #expect(Operations.soundFontIds(for: FontTag.Ubiquitous.added.id) == [])
    #expect(Operations.soundFontIds(for: FontTag.Ubiquitous.external.id) == [])
  }

  @Test func tagIdsForSoundFont() async throws {
    #expect(Operations.tagIds(for: .init(rawValue: 1)).count == 2)
    #expect(Operations.tagIds(for: .init(rawValue: 2)).count == 2)
    #expect(Operations.tagIds(for: .init(rawValue: 3)).count == 2)
  }

  @Test func tagSoundFont() async throws {
    let newTag = try FontTag.make(displayName: "New Tag")
    Operations.tagSoundFont(newTag.id, soundFontId: .init(rawValue: 1))
    #expect(Operations.tagIds(for: .init(rawValue: 1)) == [1, 2, 5])
    Operations.tagSoundFont(newTag.id, soundFontId: .init(rawValue: 1))
    #expect(Operations.tagIds(for: .init(rawValue: 1)) == [1, 2, 5])
  }

  @Test func untagSoundFont() async throws {
    @Dependency(\.defaultDatabase) var database
    let newTag = try FontTag.make(displayName: "New Tag")
    Operations.tagSoundFont(newTag.id, soundFontId: .init(rawValue: 1))
    #expect(Operations.tagIds(for: .init(rawValue: 1)) == [1, 2, 5])
    Operations.untagSoundFont(newTag.id, soundFontId: .init(rawValue: 1))
    #expect(Operations.tagIds(for: .init(rawValue: 1)) == [1, 2])
  }

  @Test func activePresetLoadingInfo() async throws {
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

  @Test func activePresetAudioConfig() async throws {
    let presets = Operations.presets(for: nil)
    @Dependency(\.defaultDatabase) var database
    @Shared(.activeState) var activeState
    $activeState.withLock { $0.activePresetId = presets[presets.count - 1].id }
    let apac = Operations.presetAudioConfig()
    #expect(apac == nil)
  }
}
