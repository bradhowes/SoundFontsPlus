import DependenciesTestSupport
import Foundation
import SharingGRDB
import Testing

@testable import SoundFonts2

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
    #expect(Operations.soundFontIds(for: Tag.Ubiquitous.all.id) == [1, 2, 3])
    #expect(Operations.soundFontIds(for: Tag.Ubiquitous.builtIn.id) == [1, 2, 3])
    #expect(Operations.soundFontIds(for: Tag.Ubiquitous.added.id) == [])
    #expect(Operations.soundFontIds(for: Tag.Ubiquitous.external.id) == [])
  }

  @Test("tagIdsForSoundFont") func tagIdsForSoundFont() async throws {
    #expect(Operations.tagIds(for: .init(rawValue: 1)).count == 2)
    #expect(Operations.tagIds(for: .init(rawValue: 2)).count == 2)
    #expect(Operations.tagIds(for: .init(rawValue: 3)).count == 2)
  }

  @Test("tagSoundFont") func tagSoundFont() async throws {
    @Dependency(\.defaultDatabase) var database
    let newTag = try Tag.make(displayName: "New Tag")
    Operations.tagSoundFont(newTag.id, soundFontId: .init(rawValue: 1))
    #expect(Operations.tagIds(for: .init(rawValue: 1)) == [1, 2, 5])
    Operations.tagSoundFont(newTag.id, soundFontId: .init(rawValue: 1))
    #expect(Operations.tagIds(for: .init(rawValue: 1)) == [1, 2, 5])
  }

  @Test("untagSoundFont") func untagSoundFont() async throws {
    @Dependency(\.defaultDatabase) var database
    let newTag = try Tag.make(displayName: "New Tag")
    Operations.tagSoundFont(newTag.id, soundFontId: .init(rawValue: 1))
    #expect(Operations.tagIds(for: .init(rawValue: 1)) == [1, 2, 5])
    Operations.untagSoundFont(newTag.id, soundFontId: .init(rawValue: 1))
    #expect(Operations.tagIds(for: .init(rawValue: 1)) == [1, 2])
  }

  @Test("deleteTag") func deleteTag() async throws {
    @Dependency(\.defaultDatabase) var database
    let newTag = try Tag.make(displayName: "New Tag")
    Operations.tagSoundFont(newTag.id, soundFontId: .init(rawValue: 1))
    #expect(Operations.tagIds(for: .init(rawValue: 1)) == [1, 2, 5])
    Operations.deleteTag(newTag.id)
    #expect(Operations.tagIds(for: .init(rawValue: 1)) == [1, 2])
  }

  @Test("updateTags") func updateTags() async throws {
    Operations.updateTags(
      [
        Tag(id: Tag.ID(rawValue: 1), displayName: "a", ordering: 0),
        Tag(id: Tag.ID(rawValue: 4), displayName: "Bar", ordering: 1),
        Tag(id: Tag.ID(rawValue: 2), displayName: "c", ordering: 2),
        Tag(id: Tag.ID(rawValue: 3), displayName: "Blah", ordering: 3)
      ]
    )
    @FetchAll(Tag.all.order(by: \.ordering)) var tags
    try await $tags.load()
    #expect(tags.count == 4)
    #expect(tags[0].displayName == "a")
    #expect(tags[1].displayName == "Bar")
    #expect(tags[2].displayName == "c")
    #expect(tags[3].displayName == "Blah")
  }

  @Test("tagInfos") func tagInfos() async throws {
    @FetchAll(Operations.tagInfosQuery) var tagInfos
    try await $tagInfos.load()
    #expect(tagInfos.count == 4)
    #expect(tagInfos.map(\.displayName) == [
      Tag.Ubiquitous.all.displayName,
      Tag.Ubiquitous.builtIn.displayName,
      Tag.Ubiquitous.added.displayName,
      Tag.Ubiquitous.external.displayName
    ])
    #expect(tagInfos.map(\.soundFontsCount) == [
      3,
      3,
      0,
      0
    ])
  }
}
