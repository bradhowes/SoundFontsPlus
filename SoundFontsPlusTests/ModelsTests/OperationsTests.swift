import DependenciesTestSupport
import Foundation
import SharingGRDB
import Testing

@testable import SoundFontsPlus

@Suite(.dependencies { $0.defaultDatabase = try appDatabase() })
struct OperationsTests {

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
    #expect(tagInfos.map(\.displayName) == [
      FontTag.Ubiquitous.all.displayName,
      FontTag.Ubiquitous.builtIn.displayName,
      FontTag.Ubiquitous.added.displayName,
      FontTag.Ubiquitous.external.displayName
    ])
    #expect(tagInfos.map(\.soundFontsCount) == [
      3,
      3,
      0,
      0
    ])
  }
}
