import DependenciesTestSupport
import Foundation
import SharingGRDB
import Testing

@testable import SoundFonts2

@Suite(.dependencies { $0.defaultDatabase = try appDatabase() })
struct OperationsTests {

  @Test("preset source") func presetSource() async throws {
    @Shared(.activeState) var activeState
    #expect(Operations.presetSource == SoundFont.ID(rawValue: 1))
    $activeState.withLock { $0.selectedSoundFontId = .init(rawValue: 2) }
    #expect(Operations.presetSource == SoundFont.ID(rawValue: 2))
    $activeState.withLock { $0.selectedSoundFontId = nil }
    #expect(Operations.presetSource == SoundFont.ID(rawValue: 1))
  }

  @Test("active preset name") func activePresetName() async throws {
    @Shared(.activeState) var activeState
    #expect(Operations.activePresetName == "Piano 1")
    $activeState.withLock { $0.activePresetId = .init(rawValue: 2) }
    #expect(Operations.activePresetName == "Piano 2")
    $activeState.withLock { $0.activePresetId = .init(rawValue: -1) }
    #expect(Operations.activePresetName == "-")
    $activeState.withLock { $0.activePresetId = nil }
    #expect(Operations.activePresetName == "-")
  }

  @Test("preset by ID") func presetByID() async throws {
    #expect(Operations.preset(.init(rawValue: 1))?.displayName == "Piano 1")
    #expect(Operations.preset(.init(rawValue: 2))?.displayName == "Piano 2")
    #expect(Operations.preset(.init(rawValue: 3))?.displayName == "Piano 3")
    #expect(Operations.preset(.init(rawValue: 100))?.displayName == "Atmosphere")
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
    #expect(Operations.tagSoundFont(newTag.id, soundFontId: .init(rawValue: 1)))
    #expect(Operations.tagIds(for: .init(rawValue: 1)) == [1, 2, 5])
    #expect(!Operations.tagSoundFont(newTag.id, soundFontId: .init(rawValue: 1)))
  }

  @Test("untagSoundFont") func untagSoundFont() async throws {
    @Dependency(\.defaultDatabase) var database
    let newTag = try Tag.make(displayName: "New Tag")
    #expect(Operations.tagSoundFont(newTag.id, soundFontId: .init(rawValue: 1)))
    #expect(Operations.tagIds(for: .init(rawValue: 1)) == [1, 2, 5])
    #expect(Operations.untagSoundFont(newTag.id, soundFontId: .init(rawValue: 1)))
    #expect(Operations.tagIds(for: .init(rawValue: 1)) == [1, 2])
  }

  @Test("deleteTag") func deleteTag() async throws {
    @Dependency(\.defaultDatabase) var database
    let newTag = try Tag.make(displayName: "New Tag")
    #expect(Operations.tagSoundFont(newTag.id, soundFontId: .init(rawValue: 1)))
    #expect(Operations.tagIds(for: .init(rawValue: 1)) == [1, 2, 5])
    #expect(Operations.deleteTag(newTag.id))
    #expect(Operations.tagIds(for: .init(rawValue: 1)) == [1, 2])
  }

  @Test("updateTags") func updateTags() async throws {
    Operations.updateTags([(1, ""), (4, "Bar"), (2, ""), (3, "Blah")])
    @FetchAll(Tag.all.order(by: \.ordering)) var tags
    try await $tags.load()
    #expect(tags.count == 4)
    #expect(tags[0].displayName == "All")
    #expect(tags[1].displayName == "Bar")
    #expect(tags[2].displayName == "Built-in")
    #expect(tags[3].displayName == "Blah")
  }

  @Test("tagInfos") func tagInfos() async throws {
    @FetchAll(Operations.tagInfos) var tagInfos
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
