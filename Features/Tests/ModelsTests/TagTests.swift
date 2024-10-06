import XCTest
import Dependencies
import SwiftData

@testable import Models

final class TagTests: XCTestCase {
  typealias ActiveSchema = SchemaV1

//  func makeMockTag(name: String) throws -> Tag {
//    let tag = Tag(name: name)
//    context.insert(tag)
//    try context.save()
//    return tag
//  }

  func testEmpty() throws {
    try withNewContext(ActiveSchema.self, makeUbiquitousTags: false, addBuiltInFonts: false) { context in
      let found = try context.fetch(FetchDescriptor<TagModel>())
      XCTAssertTrue(found.isEmpty)
    }
  }

  func testTagsCreatesUbiquitous() throws {
    try withNewContext(ActiveSchema.self, makeUbiquitousTags: false, addBuiltInFonts: false) { _ in
      let found = try ActiveSchema.TagModel.tags()
      XCTAssertEqual(found.count, ActiveSchema.TagModel.Ubiquitous.allCases.count)
    }
  }

  func testCreateNewTag() throws {
    try withNewContext(ActiveSchema.self, makeUbiquitousTags: false, addBuiltInFonts: false) { context in
      let tag = try ActiveSchema.TagModel.create(name: "New Tag")
      let found = try context.fetch(ActiveSchema.TagModel.fetchDescriptor())
      XCTAssertFalse(found.isEmpty)
      XCTAssertEqual(found[0].name, tag.name)
    }
  }

  func testCreateDuplicateTagThrows() throws {
    try withNewContext(ActiveSchema.self, makeUbiquitousTags: false, addBuiltInFonts: false) { context in
      _ = try ActiveSchema.TagModel.create(name: "New Tag")
      XCTAssertThrowsError(try ActiveSchema.TagModel.create(name: "New Tag"))
    }
  }

  func testChangeTagName() throws {
    try withNewContext(ActiveSchema.self, makeUbiquitousTags: false, addBuiltInFonts: false) { context in
      let tag = try ActiveSchema.TagModel.create(name: "New Tag")
      var tags = try ActiveSchema.TagModel.tags()
      XCTAssertEqual(tags[0].name, tag.name)
      tags[0].name = "Changed Tag"
      try context.save()
      tags = try ActiveSchema.TagModel.tags()
      XCTAssertEqual(tags[0].name, "Changed Tag")
    }
  }

  func testDeleteTagUpdatesSoundFont() throws {
    try withNewContext(ActiveSchema.self, makeUbiquitousTags: false, addBuiltInFonts: false) { context in
      let tag = try ActiveSchema.TagModel.create(name: "New Tag")
      let soundFont = try Mock.makeSoundFont(context: context, name: "Foobar", presetNames: ["one", "two", "three"],
                                               tags: [tag])
      XCTAssertEqual(soundFont.tags.count, 1)

      let tags = try ActiveSchema.TagModel.tags()
      XCTAssertEqual(tags.count, 1)

      context.delete(tags[0])
      try context.save()

      XCTAssertEqual(soundFont.tags, [])
    }
  }

  func testUbiquitousTagCreation() throws {
    try withNewContext(ActiveSchema.self) { context in
      _ = try ActiveSchema.TagModel.ubiquitous(.all)
      let tags = try context.fetch(ActiveSchema.TagModel.fetchDescriptor())
      XCTAssertEqual(tags.count, ActiveSchema.TagModel.Ubiquitous.allCases.count)
    }
  }

  func testAllUbiquitousTags() throws {
    try withNewContext(ActiveSchema.self, makeUbiquitousTags: false, addBuiltInFonts: false) { context in
      let tags = try ActiveSchema.TagModel.tags()
      XCTAssertEqual(tags.count, ActiveSchema.TagModel.Ubiquitous.allCases.count)

      for kind in ActiveSchema.TagModel.Ubiquitous.allCases {
        let tag = try ActiveSchema.TagModel.ubiquitous(kind)
        XCTAssertEqual(tag.name, kind.name)
        XCTAssertTrue(tag.tagged.isEmpty)
      }
    }
  }
}
