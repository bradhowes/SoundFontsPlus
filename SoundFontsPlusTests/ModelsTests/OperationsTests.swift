import DependenciesTestSupport
import Foundation
import InlineSnapshotTesting
import Sharing
import SQLiteData
import StructuredQueriesTestSupport
import Testing

@testable import SoundFontsPlus

extension BaseTestSuite {

  @MainActor
  struct OperationsTests {}
}

extension BaseTestSuite.OperationsTests {

  @Test func presetsOrdering() async throws {
    var presets = Operations.presets
    #expect(presets.count == 189)

    let preset10Name = presets[10].displayName
    let clone10 = presets[10].clone()
    #expect(clone10?.displayName == preset10Name + " copy")

    let preset20Name = presets[20].displayName
    let clone20 = presets[20].clone()
    #expect(clone20?.displayName == preset20Name + " copy")

    @Shared(.favoritesOnTop) var favoritesOnTop
    $favoritesOnTop.withLock { $0 = false }
    presets = Operations.presets
    #expect(presets.count == 191)
    #expect(presets[10].displayName == preset10Name)
    #expect(presets[11].displayName == clone10?.displayName)
    #expect(presets[21].displayName == preset20Name)
    #expect(presets[22].displayName == clone20?.displayName)

    $favoritesOnTop.withLock { $0 = true }
    presets = Operations.presets
    #expect(presets.count == 191)
    #expect(presets[0].displayName == clone10?.displayName)
    #expect(presets[1].displayName == clone20?.displayName)
    #expect(presets[12].displayName == preset10Name)
    #expect(presets[22].displayName == preset20Name)

    @Shared(.showOnlyFavorites) var showOnlyFavorites
    $showOnlyFavorites.withLock { $0 = true }

    presets = Operations.presets
    #expect(presets.count == 2)
  }

  @Test func presets() async throws {
    @Shared(.activeState) var activeState
    @Shared(.selectedSoundFontId) var selectedSoundFontId
    #expect(Operations.presets.count == 189)
    $selectedSoundFontId.withLock { $0 = .init(rawValue: 2) }
    #expect(Operations.presets.count == 235)
    $selectedSoundFontId.withLock { $0 = .init(rawValue: 3) }
    #expect(Operations.presets.count == 270)
    $selectedSoundFontId.withLock { $0 = nil }
    #expect(Operations.presets.count == 189)
    $activeState.withLock { $0.activeSoundFontId = nil }
    #expect(Operations.presets.count == 0)
  }

  @Test func allPresets() async throws {
    @Shared(.activeState) var activeState
    @Shared(.selectedSoundFontId) var selectedSoundFontId
    #expect(Operations.allPresets.count == 189)
    $selectedSoundFontId.withLock { $0 = .init(rawValue: 2) }
    #expect(Operations.allPresets.count == 235)
    $selectedSoundFontId.withLock { $0 = .init(rawValue: 3) }
    #expect(Operations.allPresets.count == 270)
    $selectedSoundFontId.withLock { $0 = nil }
    $activeState.withLock { $0.activeSoundFontId = nil }
    #expect(Operations.allPresets.count == 0)
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
    withExpectedIssue {
      Operations.tagSoundFont(newTag.id, soundFontId: .init(rawValue: 1))
      #expect(Operations.tagIds(for: .init(rawValue: 1)) == [1, 2, 5])
    }
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
    let presets = Operations.presets
    @Shared(.activeState) var activeState
    $activeState.withLock { $0.activePresetId = presets[100].id }
    var apli = Operations.activePresetLoadingInfo
    #expect(apli?.soundFontId == presets[100].soundFontId)
    #expect(apli?.presetIndex == presets[100].index)
    $activeState.withLock { $0.activePresetId = presets[0].id }
    apli = Operations.activePresetLoadingInfo
    #expect(apli?.soundFontId == presets[0].soundFontId)
    #expect(apli?.presetIndex == presets[0].index)
  }

  @Test func activePresetAudioConfig() async throws {
    let presets = Operations.presets
    @Dependency(\.defaultDatabase) var database
    @Shared(.activeState) var activeState
    $activeState.withLock { $0.activePresetId = presets[100].id }
    let apac = Operations.activePresetAudioConfig
    #expect(apac == nil)
  }
}
