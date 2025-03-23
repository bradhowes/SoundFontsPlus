import Dependencies
import Foundation
import GRDB
import IdentifiedCollections
import SF2ResourceFiles
import Testing

@testable import Models

@Suite("Tag") struct TagTests {

  @Test("migration") func migration() async throws {
    try await withDependencies {
      $0.defaultDatabase = try DatabaseQueue.appDatabase(addMocks: true)
    } operation: {
      @Dependency(\.defaultDatabase) var db

      let tags = try await db.read { try Tag.fetchAll($0) }
      let soundFonts = try await db.read { try SoundFont.fetchAll($0) }
      #expect(soundFonts.count == 3)
      #expect(tags.count == Tag.Ubiquitous.allCases.count)

      for sf in soundFonts {
        let t = try await db.read { try sf.tagsQuery.fetchAll($0) }
        #expect(t.count == 2) // all and builtin
      }

      for t in tags {
        let s = try await db.read { try t.soundFonts.fetchCount($0) }
        print(t.name, s)
        if t.name == Tag.Ubiquitous.all.name || t.name == Tag.Ubiquitous.builtIn.name {
          #expect(s == 3)
        } else {
          #expect(s == 0)
        }
      }
    }
  }

  @Test("create") func create() async throws {
    try await withDependencies {
      $0.defaultDatabase = try DatabaseQueue.appDatabase(addMocks: true)
    } operation: {
      @Dependency(\.defaultDatabase) var db
      let tags = try await db.read { try Tag.fetchAll($0) }

      let newTag = try await db.write { try Tag.make($0, name: "new") }
      #expect(newTag.name == "new")
      #expect(newTag.isUserDefined)
      #expect(!newTag.isUbiquitous)
      let orderedTags = Tag.ordered
      #expect(orderedTags.count == tags.count + 1)
      #expect(orderedTags.last!.name == "new")
    }
  }

  @Test("delete") func delete() async throws {
    try await withDependencies {
      $0.defaultDatabase = try DatabaseQueue.appDatabase(addMocks: true)
    } operation: {
      @Dependency(\.defaultDatabase) var db

      let newTag = try await db.write { try Tag.make($0, name: "new") }
      let result = try await db.write { try newTag.delete($0) }
      #expect(result)
    }
  }

  @Test("rename") func rename() async throws {
    try await withDependencies {
      $0.defaultDatabase = try DatabaseQueue.appDatabase(addMocks: true)
    } operation: {
      @Dependency(\.defaultDatabase) var db

      let newTag = try await db.write { try Tag.make($0, name: "new") }
      let changed = try await db.write {
        var tmp = newTag
        try tmp.updateChanges($0) {
          $0.name = "renamed"
        }
        return tmp
      }
      #expect(changed.name == "renamed")
    }
  }

  @Test("rename ubiquitous") func renameUbiquitous() async throws {
    try await withDependencies {
      $0.defaultDatabase = try DatabaseQueue.appDatabase(addMocks: true)
    } operation: {
      @Dependency(\.defaultDatabase) var db
      let tags = try await db.read { try Tag.fetchAll($0) }

      let first = tags[0]
      try await db.write {
        var tmp = first
        try tmp.updateChanges($0) {
          $0.name = "renamed"
        }
      }
    }
  }

  @Test("delete ubuquitous") func deleteUbiquitous() async throws {
    try await withDependencies {
      $0.defaultDatabase = try DatabaseQueue.appDatabase(addMocks: true)
    } operation: {
      @Dependency(\.defaultDatabase) var db
      let tags = try await db.read { try Tag.fetchAll($0) }

      await #expect(throws: ModelError.self) {
        _ = try await db.write { try tags[0].delete($0) }
      }
    }
  }

  @Test("create with invalid name") func createWithInvalidName() async throws {
    try await withDependencies {
      $0.defaultDatabase = try DatabaseQueue.appDatabase(addMocks: true)
    } operation: {
      @Dependency(\.defaultDatabase) var db

      await #expect(throws: ModelError.self) {
        try await db.write { try Tag.make($0, name: Tag.Ubiquitous.all.name) }
      }
    }
  }

  @Test("reorder") func reorder() async throws {
    try await withDependencies {
      $0.defaultDatabase = try DatabaseQueue.appDatabase(addMocks: true)
    } operation: {
      @Dependency(\.defaultDatabase) var db
      let tags = try await db.read { try Tag.fetchAll($0) }

      let newTag = try await db.write { try Tag.make($0, name: "new") }
      #expect(newTag.name == "new")
      _ = Tag.ordered
      try await db.write { try Tag.reorder($0, tags: [newTag, tags[1], tags[0], tags[2]]) }
      let reorderedTags = Tag.ordered
      #expect(reorderedTags.first!.name == "new")
      #expect(reorderedTags.last!.name == Tag.Ubiquitous.external.name)
    }
  }
}
