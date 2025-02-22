import Dependencies
import Foundation
import GRDB
import IdentifiedCollections
import SF2ResourceFiles
import Testing

@testable import Models

@Suite("Tag") struct TagTests {

  @Test("migration") func migration() async throws {
    let (db, soundFonts, tags) = try await setup()
    #expect(soundFonts.count == 3)
    #expect(tags.count == Tag.Ubiquitous.allCases.count)

    for sf in soundFonts {
      let t = try await db.read { try sf.tags.fetchAll($0) }
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

  @Test("create") func create() async throws {
    let (db, _, tags) = try await setup()
    let newTag = try await db.write { try Tag.make($0, name: "new") }
    #expect(newTag.name == "new")
    let orderedTags = try await db.read { try Tag.allOrdered($0) }
    #expect(orderedTags.count == tags.count + 1)
    #expect(orderedTags.last!.name == "new")
  }

  @Test("delete") func delete() async throws {
    let (db, _, _) = try await setup()
    let newTag = try await db.write { try Tag.make($0, name: "new") }
    let result = try await db.write { try newTag.delete($0) }
    #expect(result)
  }

  @Test("rename") func rename() async throws {
    let (db, _, _) = try await setup()
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

  @Test("rename ubiquitous") func renameUbiquitous() async throws {
    let (db, _, tags) = try await setup()
    let first = tags[0]
    try await db.write {
      var tmp = first
      try tmp.updateChanges($0) {
        $0.name = "renamed"
      }
    }
  }

  @Test("delete ubuquitous") func deleteUbiquitous() async throws {
    let (db, _, tags) = try await setup()
    await #expect(throws: ModelError.self) {
      _ = try await db.write { try tags[0].delete($0) }
    }
  }

  @Test("create with invalid name") func createWithInvalidName() async throws {
    let (db, _, _) = try await setup()
    await #expect(throws: ModelError.self) {
      try await db.write { try Tag.make($0, name: Tag.Ubiquitous.all.name) }
    }
  }

  @Test("reorder") func reorder() async throws {
    let (db, _, tags) = try await setup()
    let newTag = try await db.write { try Tag.make($0, name: "new") }
    #expect(newTag.name == "new")
    _ = try await db.read { try Tag.allOrdered($0) }
    try await db.write { try Tag.reorder($0, tags: [newTag, tags[1], tags[0], tags[2]]) }
    let reorderedTags = try await db.read { try Tag.allOrdered($0) }
    #expect(reorderedTags.first!.name == "new")
    #expect(reorderedTags.last!.name == Tag.Ubiquitous.external.name)
  }

  private func setup() async throws -> (DatabaseQueue, [SoundFont], [Models.Tag]) {
    let db = try await setupDatabase()
    let tags = try await db.read { try Tag.fetchAll($0) }
    let soundFonts = try await db.read { try SoundFont.fetchAll($0) }
    return (db, soundFonts, tags)
  }
}

private func setupDatabase() async throws -> DatabaseQueue {
  let db = try DatabaseQueue.appDatabase()
  for tag in SF2ResourceFileTag.allCases {
    try await db.write {
      _  = try SoundFont.make(
        $0,
        displayName: tag.name,
        location: Location(kind: .builtin, url: tag.url, raw: nil)
      )
    }
  }

  return db
}


//import XCTest
//import ComposableArchitecture
//import Dependencies
//import SwiftData
//
//@testable import Models
//
//final class TagTests: XCTestCase {
//  typealias ActiveSchema = SchemaV1
//
//  func testEmpty() throws {
//    try withNewContext(ActiveSchema.self, makeUbiquitousTags: false, addBuiltInFonts: false) { context in
//      let found = try context.fetch(FetchDescriptor<TagModel>())
//      XCTAssertTrue(found.isEmpty)
//    }
//  }
//
//  func testTagsCreatesUbiquitous() throws {
//    try withNewContext(ActiveSchema.self, makeUbiquitousTags: false, addBuiltInFonts: false) { _ in
//      let found = try TagModel.tags()
//      XCTAssertEqual(found.count, TagModel.Ubiquitous.allCases.count)
//    }
//  }
//
//  func testCreateNewTag() throws {
//    try withNewContext(ActiveSchema.self, makeUbiquitousTags: false, addBuiltInFonts: false) { context in
//      let tag = try TagModel.create(name: "New Tag")
//      let found = try context.fetch(TagModel.fetchDescriptor())
//      XCTAssertFalse(found.isEmpty)
//      XCTAssertEqual(found[0].name, tag.name)
//      XCTAssertFalse(found[0].ubiquitous)
//    }
//  }
//
//  func testChangeTagName() throws {
//    try withNewContext(ActiveSchema.self, makeUbiquitousTags: false, addBuiltInFonts: false) { context in
//      let tag = try TagModel.create(name: "New Tag")
//      var tags = try TagModel.tags()
//      XCTAssertEqual(tags[0].name, tag.name)
//      tags[0].name = "Changed Tag"
//      try context.save()
//      tags = try TagModel.tags()
//      XCTAssertEqual(tags[0].name, "Changed Tag")
//    }
//  }
//
//  func testDeleteTagUpdatesSoundFont() throws {
//    try withNewContext(ActiveSchema.self, makeUbiquitousTags: false, addBuiltInFonts: false) { context in
//      let tag = try TagModel.create(name: "New Tag")
//      let soundFont = try Mock.makeSoundFont(name: "Foobar", presetNames: ["one", "two", "three"], tags: [tag])
//      XCTAssertEqual(soundFont.tags.count, 1)
//
//      let tags = try TagModel.tags()
//      XCTAssertEqual(tags.count, 1)
//
//      try TagModel.delete(key: tags[0].key)
//      XCTAssertEqual(soundFont.tags, [])
//
//      try TagModel.delete(key: tags[0].key)
//    }
//  }
//
//  func testUbiquitousTagCreation() throws {
//    try withNewContext(ActiveSchema.self, makeUbiquitousTags: false, addBuiltInFonts: false) { context in
//      _ = try TagModel.ubiquitous(.all)
//      let tags = try context.fetch(TagModel.fetchDescriptor())
//      XCTAssertEqual(tags.count, TagModel.Ubiquitous.allCases.count)
//    }
//  }
//
//  func testAllUbiquitousTags() throws {
//    try withNewContext(ActiveSchema.self, makeUbiquitousTags: false, addBuiltInFonts: false) { context in
//      var tags = try TagModel.tags()
//      XCTAssertEqual(tags.count, TagModel.Ubiquitous.allCases.count)
//      tags = try TagModel.tags()
//      XCTAssertEqual(tags.count, TagModel.Ubiquitous.allCases.count)
//
//      for kind in TagModel.Ubiquitous.allCases {
//        let tag = try TagModel.ubiquitous(kind)
//        XCTAssertEqual(tag.name, kind.name)
//        XCTAssertTrue(tag.tagged.isEmpty)
//        XCTAssertTrue(tag.ubiquitous)
//      }
//    }
//  }
//
//  func testOrderedFonts() throws {
//    try withNewContext(ActiveSchema.self) { context in
//      _ = try ["Alpha", "Beta", "Zeta"].map {
//        try Mock.makeSoundFont(
//          name: $0,
//          presetNames: ["one", "two", "three"],
//          tags: [
//            TagModel.ubiquitous(.all),
//            TagModel.ubiquitous(.added)
//          ]
//        )
//      }
//
//      var tag = try TagModel.ubiquitous(.builtIn)
//      var fonts = tag.orderedFonts
//      XCTAssertEqual(fonts.count, 3)
//      XCTAssertEqual(fonts[0].displayName, "FreeFont")
//      XCTAssertEqual(fonts[1].displayName, "MuseScore")
//      XCTAssertEqual(fonts[2].displayName, "Roland Piano")
//
//      tag = try TagModel.ubiquitous(.all)
//      fonts = tag.orderedFonts
//      XCTAssertEqual(fonts.count, 6)
//
//      XCTAssertEqual(fonts[0].displayName, "Alpha")
//      XCTAssertEqual(fonts[1].displayName, "Beta")
//
//      XCTAssertEqual(fonts[2].displayName, "FreeFont")
//      XCTAssertEqual(fonts[3].displayName, "MuseScore")
//      XCTAssertEqual(fonts[4].displayName, "Roland Piano")
//      XCTAssertEqual(fonts[5].displayName, "Zeta")
//
//      tag = try TagModel.ubiquitous(.added)
//      fonts = tag.orderedFonts
//      XCTAssertEqual(fonts.count, 3)
//
//      XCTAssertEqual(fonts[0].displayName, "Alpha")
//      XCTAssertEqual(fonts[1].displayName, "Beta")
//      XCTAssertEqual(fonts[2].displayName, "Zeta")
//
//      fonts[0].displayName = "Gamma"
//      try context.save()
//
//      fonts = tag.orderedFonts
//      XCTAssertEqual(fonts.count, 3)
//
//      XCTAssertEqual(fonts[0].displayName, "Beta")
//      XCTAssertEqual(fonts[1].displayName, "Gamma")
//      XCTAssertEqual(fonts[2].displayName, "Zeta")
//
//      tag = try TagModel.ubiquitous(.external)
//      fonts = tag.orderedFonts
//      XCTAssertTrue(fonts.isEmpty)
//    }
//  }
//
//  func testTagsFor() throws {
//    try withNewContext(ActiveSchema.self) { context in
//      try withTestAppStorage {
//        let userDefined = try withDependencies {
//          $0.uuid = .constant(.init(123))
//        } operation: {
//          try TagModel.create(name: "blah")
//        }
//
//        XCTAssertEqual(try TagModel.tagsFor(kind: .builtin), [
//          try TagModel.ubiquitous(.all),
//          try TagModel.ubiquitous(.builtIn)
//        ])
//        XCTAssertEqual(try TagModel.tagsFor(kind: .installed), [
//          try TagModel.ubiquitous(.all),
//          try TagModel.ubiquitous(.added)
//        ])
//        XCTAssertEqual(try TagModel.tagsFor(kind: .external), [
//          try TagModel.ubiquitous(.all),
//          try TagModel.ubiquitous(.added),
//          try TagModel.ubiquitous(.external)
//        ])
//
//        @Shared(.activeState) var activeState
//        activeState.setActiveTagKey(userDefined.key)
//
//        XCTAssertEqual(try TagModel.tagsFor(kind: .external), [
//          try TagModel.ubiquitous(.all),
//          try TagModel.ubiquitous(.added),
//          try TagModel.ubiquitous(.external),
//          userDefined
//        ])
//      }
//    }
//  }
//}
