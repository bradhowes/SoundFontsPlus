import Dependencies
import DependenciesTestSupport
import SharingGRDB
import Testing

@testable import Models

@Suite(.dependencies { $0.defaultDatabase = try Models.appDatabase() })
struct TagTests {

  @Test("migration") func migration() async throws {
    @FetchAll(Models.Tag.all) var tags
    try await $tags.load()
    #expect(tags.count == Tag.Ubiquitous.allCases.count)

    @FetchAll(SoundFont.all) var soundFonts
    try await $soundFonts.load()
    #expect(soundFonts.count == 3)

    @FetchAll(TaggedSoundFont.all) var taggedSoundFonts
    try await $taggedSoundFonts.load()
    #expect(taggedSoundFonts.count == 6)

    @FetchAll(Preset.all) var presets
    try await $presets.load()
    #expect(presets.count == 506)
  }

  @Test("tagged") func tagged() async throws {
    @FetchAll(Models.Tag.all) var tags
    try await $tags.load()

    #expect(tags[0].soundFonts.count == 3)
    #expect(tags[1].soundFonts.count == 3)
    #expect(tags[2].soundFonts.count == 0)
    #expect(tags[3].soundFonts.count == 0)
  }

  @Test("create") func create() async throws {
    @FetchAll(Models.Tag.all) var tags
    let displayName = "new tag"
    let tag = try Models.Tag.create(displayName: displayName)
    #expect(tag.displayName == displayName)
    #expect(tag.isUserDefined)
    #expect(!tag.isUbiquitous)
    try await $tags.load()
    #expect(tags.count == Tag.Ubiquitous.allCases.count + 1)
  }

  @Test("delete ubiquitous") func deletingUbiquitous() async throws {
    @FetchAll(Models.Tag.all) var tags
    try await $tags.load()
    for each in Tag.Ubiquitous.allCases {
      #expect(throws: ModelError.deleteUbiquitous(name: each.displayName)) {
        try tags[Int(each.id.rawValue - Int64(1))].delete()
      }
    }
  }

  @Test("delete") func delete() async throws {
    @FetchAll(Models.Tag.all) var tags
    let displayName = "tag to delete"
    let tag = try Models.Tag.create(displayName: displayName)
    try await $tags.load()
    #expect(tags.count == Tag.Ubiquitous.allCases.count + 1)
    try tag.delete()
    try await $tags.load()
    #expect(tags.count == Tag.Ubiquitous.allCases.count)
    #expect(!tags.map(\.id).contains(tag.id))
  }

  @Test("rename ubiquitous") func renameUbiquitous() async throws {
    @FetchAll(Models.Tag.all) var tags
    try await $tags.load()
    for each in Tag.Ubiquitous.allCases {
      #expect(throws: ModelError.renameUbiquitous(name: each.displayName)) {
        try tags[Int(each.id.rawValue - Int64(1))].rename(new: "nope")
      }
    }
  }

  @Test("rename with empty name") func renameToBlank() async throws {
    @FetchAll(Models.Tag.all) var tags
    let displayName = "tag to rename"
    let tag = try Models.Tag.create(displayName: displayName)
    try await $tags.load()
    #expect(tags.count == Tag.Ubiquitous.allCases.count + 1)

    #expect(throws: ModelError.emptyTagName) {
      try tag.rename(new: "")
    }

    #expect(throws: ModelError.emptyTagName) {
      try tag.rename(new: "   ")
    }
  }

  @Test("rename") func rename() async throws {
    @FetchAll(Models.Tag.all) var tags
    let displayName = "tag to rename"
    let tag = try Models.Tag.create(displayName: displayName)
    try await $tags.load()
    #expect(tags.count == Tag.Ubiquitous.allCases.count + 1)

    try tag.rename(new: "another name")
    try await $tags.load()
    #expect(tags.last!.displayName == "another name")
  }

  @Test("create with invalid name") func createWithInvalidName() async throws {
    @FetchAll(Models.Tag.all) var tags
    #expect(throws: ModelError.emptyTagName) {
      try Tag.create(displayName: "")
    }
    #expect(throws: ModelError.emptyTagName) {
      try Tag.create(displayName: "   ")
    }

    for each in Tag.Ubiquitous.allCases {
      #expect(throws: ModelError.duplicateTag(name: each.displayName)) {
        try Tag.create(displayName: each.displayName)
      }
    }
  }

  @Test("reorder") func reorder() async throws {
    @FetchAll(Models.Tag.all.order(by: \.ordering)) var tags
    try await $tags.load()
    try Models.Tag.reorder(tags: [tags[1], tags[0], tags[3], tags[2]])
    try await $tags.load()
    #expect(tags.count == 4)
    #expect(tags.map(\.displayName) == [
      Tag.Ubiquitous.builtIn.displayName,
      Tag.Ubiquitous.all.displayName,
      Tag.Ubiquitous.external.displayName,
      Tag.Ubiquitous.added.displayName
    ])
  }
}
