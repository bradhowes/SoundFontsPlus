import DependenciesTestSupport
import Foundation
import InlineSnapshotTesting
import SharingGRDB
import StructuredQueriesTestSupport
import Testing

@testable import SoundFontsPlus

extension BaseTestSuite {

  struct OperationsTests {

    @Test("presetsOrdering") func presetsOrdering() async throws {
      var presets = Operations.presets
      #expect(presets.count == 235)

      let preset10Name = presets[10].displayName
      let clone10 = presets[10].clone()
      #expect(clone10?.displayName == preset10Name + " copy")

      let preset20Name = presets[20].displayName
      let clone20 = presets[20].clone()
      #expect(clone20?.displayName == preset20Name + " copy")

      @Shared(.favoritesOnTop) var favoritesOnTop
      $favoritesOnTop.withLock { $0 = false }
      presets = Operations.presets
      #expect(presets.count == 237)
      #expect(presets[10].displayName == preset10Name)
      #expect(presets[11].displayName == clone10?.displayName)
      #expect(presets[21].displayName == preset20Name)
      #expect(presets[22].displayName == clone20?.displayName)

      $favoritesOnTop.withLock { $0 = true }
      presets = Operations.presets
      #expect(presets.count == 237)
      #expect(presets[0].displayName == clone10?.displayName)
      #expect(presets[1].displayName == clone20?.displayName)
      #expect(presets[12].displayName == preset10Name)
      #expect(presets[22].displayName == preset20Name)

      @Shared(.showOnlyFavorites) var showOnlyFavorites
      $showOnlyFavorites.withLock { $0 = true }

      presets = Operations.presets
      #expect(presets.count == 2)
    }

    @Test("presets") func presets() async throws {
      @Shared(.activeState) var activeState
      #expect(Operations.presets.count == 235)
      $activeState.withLock { $0.selectedSoundFontId = .init(rawValue: 2) }
      #expect(Operations.presets.count == 270)
      $activeState.withLock { $0.selectedSoundFontId = .init(rawValue: 3) }
      #expect(Operations.presets.count == 1)
      $activeState.withLock { $0.selectedSoundFontId = nil }
      #expect(Operations.presets.count == 235)
      $activeState.withLock { $0.activeSoundFontId = nil }
      #expect(Operations.presets.count == 0)
    }

    @Test("allPresets") func allPresets() async throws {
      @Shared(.activeState) var activeState
      #expect(Operations.allPresets.count == 235)
      $activeState.withLock { $0.selectedSoundFontId = .init(rawValue: 2) }
      #expect(Operations.allPresets.count == 270)
      $activeState.withLock { $0.selectedSoundFontId = .init(rawValue: 3) }
      #expect(Operations.allPresets.count == 1)
      $activeState.withLock { $0.selectedSoundFontId = nil }
      $activeState.withLock { $0.activeSoundFontId = nil }
      #expect(Operations.allPresets.count == 0)
    }

    @Test("soundFontIdsForTag") func soundFontIdsForTag() async throws {
      #expect(Operations.soundFontIds(for: FontTag.Ubiquitous.all.id) == [1, 2, 3])
      #expect(Operations.soundFontIds(for: FontTag.Ubiquitous.builtIn.id) == [1, 2, 3])
      #expect(Operations.soundFontIds(for: FontTag.Ubiquitous.added.id) == [])
      #expect(Operations.soundFontIds(for: FontTag.Ubiquitous.external.id) == [])
    }

    @Test("tagIdsForSoundFont") func tagIdsForSoundFont() async throws {
      #expect(Operations.tagIds(for: .init(rawValue: 1)).count == 2)
      #expect(Operations.tagIds(for: .init(rawValue: 2)).count == 2)
      #expect(Operations.tagIds(for: .init(rawValue: 3)).count == 2)
    }

    @Test("tagSoundFont") func tagSoundFont() async throws {
      @Dependency(\.defaultDatabase) var database
      let newTag = try FontTag.make(displayName: "New Tag")
      Operations.tagSoundFont(newTag.id, soundFontId: .init(rawValue: 1))
      #expect(Operations.tagIds(for: .init(rawValue: 1)) == [1, 2, 5])
      Operations.tagSoundFont(newTag.id, soundFontId: .init(rawValue: 1))
      #expect(Operations.tagIds(for: .init(rawValue: 1)) == [1, 2, 5])
    }

    @Test("untagSoundFont") func untagSoundFont() async throws {
      @Dependency(\.defaultDatabase) var database
      let newTag = try FontTag.make(displayName: "New Tag")
      Operations.tagSoundFont(newTag.id, soundFontId: .init(rawValue: 1))
      #expect(Operations.tagIds(for: .init(rawValue: 1)) == [1, 2, 5])
      Operations.untagSoundFont(newTag.id, soundFontId: .init(rawValue: 1))
      #expect(Operations.tagIds(for: .init(rawValue: 1)) == [1, 2])
    }

    @Test("deleteTag") func deleteTag() async throws {
      @Dependency(\.defaultDatabase) var database
      let newTag = try FontTag.make(displayName: "New Tag")
      Operations.tagSoundFont(newTag.id, soundFontId: .init(rawValue: 1))
      #expect(Operations.tagIds(for: .init(rawValue: 1)) == [1, 2, 5])
      Operations.deleteTag(newTag.id)
      #expect(Operations.tagIds(for: .init(rawValue: 1)) == [1, 2])
    }

    @Test("tagInfos") func tagInfos() async throws {
      @FetchAll(Operations.tagInfosQuery) var tagInfos
      try await $tagInfos.load()
      #expect(tagInfos.count == 4)
      #expect(tagInfos.map(\.displayName) == FontTag.Ubiquitous.allCases.map(\.displayName))
      #expect(tagInfos.map(\.soundFontsCount) == [3, 3, 0, 0])

      @Dependency(\.defaultDatabase) var database

      let count = tagInfos.count
      for (index, tag) in tagInfos.enumerated() {
        try await database.write { db in
          try FontTag.update {
            $0.ordering = count - index
          }
          .where {
            $0.id.eq(tag.id)
          }
          .execute(db)
        }
      }
      try await $tagInfos.load()
      #expect(tagInfos.map(\.displayName) == FontTag.Ubiquitous.allCases.reversed().map(\.displayName))
      #expect(tagInfos.map(\.soundFontsCount) == [0, 0, 3, 3])
    }

    @Test("activePresetLoadingInfo") func activePresetLoadingInfo() async throws {
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

    @Test("tagsOrdering") func tags() async throws {
      @Dependency(\.defaultDatabase) var database
      var found = Operations.tags
      #expect(found.count == 4)
      #expect(found[0].displayName == FontTag.Ubiquitous.all.displayName)
      #expect(found[1].displayName == FontTag.Ubiquitous.builtIn.displayName)
      #expect(found[2].displayName == FontTag.Ubiquitous.added.displayName)
      #expect(found[3].displayName == FontTag.Ubiquitous.external.displayName)
      let count = found.count
      for (index, tag) in found.enumerated() {
        try await database.write { db in
          try FontTag.update {
            $0.ordering = count - index
          }
          .where {
            $0.id.eq(tag.id)
          }
          .execute(db)
        }
      }

      found = Operations.tags
      #expect(found.count == 4)
      #expect(found[0].displayName == FontTag.Ubiquitous.external.displayName)
      #expect(found[1].displayName == FontTag.Ubiquitous.added.displayName)
      #expect(found[2].displayName == FontTag.Ubiquitous.builtIn.displayName)
      #expect(found[3].displayName == FontTag.Ubiquitous.all.displayName)
    }
  }
}
