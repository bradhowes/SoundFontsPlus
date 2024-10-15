import XCTest
import Dependencies
import SwiftData

@testable import Models

final class TagTests: XCTestCase {
  typealias ActiveSchema = SchemaV1

  func testEmpty() throws {
    try withNewContext(ActiveSchema.self, makeUbiquitousTags: false, addBuiltInFonts: false) { context in
      let found = try context.fetch(FetchDescriptor<TagModel>())
      XCTAssertTrue(found.isEmpty)
    }
  }

  func testTagsCreatesUbiquitous() throws {
    try withNewContext(ActiveSchema.self, makeUbiquitousTags: false, addBuiltInFonts: false) { _ in
      let found = try TagModel.tags()
      XCTAssertEqual(found.count, TagModel.Ubiquitous.allCases.count)
    }
  }

  func testCreateNewTag() throws {
    try withNewContext(ActiveSchema.self, makeUbiquitousTags: false, addBuiltInFonts: false) { context in
      let tag = try TagModel.create(name: "New Tag")
      let found = try context.fetch(TagModel.fetchDescriptor())
      XCTAssertFalse(found.isEmpty)
      XCTAssertEqual(found[0].name, tag.name)
      XCTAssertFalse(found[0].ubiquitous)
    }
  }

  func testChangeTagName() throws {
    try withNewContext(ActiveSchema.self, makeUbiquitousTags: false, addBuiltInFonts: false) { context in
      let tag = try TagModel.create(name: "New Tag")
      var tags = try TagModel.tags()
      XCTAssertEqual(tags[0].name, tag.name)
      tags[0].name = "Changed Tag"
      try context.save()
      tags = try TagModel.tags()
      XCTAssertEqual(tags[0].name, "Changed Tag")
    }
  }

  func testDeleteTagUpdatesSoundFont() throws {
    try withNewContext(ActiveSchema.self, makeUbiquitousTags: false, addBuiltInFonts: false) { context in
      let tag = try TagModel.create(name: "New Tag")
      let soundFont = try Mock.makeSoundFont(name: "Foobar", presetNames: ["one", "two", "three"], tags: [tag])
      XCTAssertEqual(soundFont.tags.count, 1)

      let tags = try TagModel.tags()
      XCTAssertEqual(tags.count, 1)

      try TagModel.delete(key: tags[0].key)
      XCTAssertEqual(soundFont.tags, [])

      try TagModel.delete(key: tags[0].key)
    }
  }

  func testUbiquitousTagCreation() throws {
    try withNewContext(ActiveSchema.self, makeUbiquitousTags: false, addBuiltInFonts: false) { context in
      _ = try TagModel.ubiquitous(.all)
      let tags = try context.fetch(TagModel.fetchDescriptor())
      XCTAssertEqual(tags.count, TagModel.Ubiquitous.allCases.count)
    }
  }

  func testAllUbiquitousTags() throws {
    try withNewContext(ActiveSchema.self, makeUbiquitousTags: false, addBuiltInFonts: false) { context in
      var tags = try TagModel.tags()
      XCTAssertEqual(tags.count, TagModel.Ubiquitous.allCases.count)
      tags = try TagModel.tags()
      XCTAssertEqual(tags.count, TagModel.Ubiquitous.allCases.count)

      for kind in TagModel.Ubiquitous.allCases {
        let tag = try TagModel.ubiquitous(kind)
        XCTAssertEqual(tag.name, kind.name)
        XCTAssertTrue(tag.tagged.isEmpty)
        XCTAssertTrue(tag.ubiquitous)
      }
    }
  }

  func testOrderedFonts() throws {
    try withNewContext(ActiveSchema.self) { context in
      _ = try ["Alpha", "Beta", "Zeta"].map {
        try Mock.makeSoundFont(
          name: $0,
          presetNames: ["one", "two", "three"],
          tags: [
            TagModel.ubiquitous(.all),
            TagModel.ubiquitous(.added)
          ]
        )
      }

      var tag = try TagModel.ubiquitous(.builtIn)
      var fonts = tag.orderedFonts
      XCTAssertEqual(fonts.count, 3)
      XCTAssertEqual(fonts[0].displayName, "FreeFont")
      XCTAssertEqual(fonts[1].displayName, "MuseScore")
      XCTAssertEqual(fonts[2].displayName, "Roland Piano")

      tag = try TagModel.ubiquitous(.all)
      fonts = tag.orderedFonts
      XCTAssertEqual(fonts.count, 6)

      XCTAssertEqual(fonts[0].displayName, "Alpha")
      XCTAssertEqual(fonts[1].displayName, "Beta")

      XCTAssertEqual(fonts[2].displayName, "FreeFont")
      XCTAssertEqual(fonts[3].displayName, "MuseScore")
      XCTAssertEqual(fonts[4].displayName, "Roland Piano")
      XCTAssertEqual(fonts[5].displayName, "Zeta")

      tag = try TagModel.ubiquitous(.added)
      fonts = tag.orderedFonts
      XCTAssertEqual(fonts.count, 3)

      XCTAssertEqual(fonts[0].displayName, "Alpha")
      XCTAssertEqual(fonts[1].displayName, "Beta")
      XCTAssertEqual(fonts[2].displayName, "Zeta")

      fonts[0].displayName = "Gamma"
      try context.save()

      fonts = tag.orderedFonts
      XCTAssertEqual(fonts.count, 3)

      XCTAssertEqual(fonts[0].displayName, "Beta")
      XCTAssertEqual(fonts[1].displayName, "Gamma")
      XCTAssertEqual(fonts[2].displayName, "Zeta")

      tag = try TagModel.ubiquitous(.external)
      fonts = tag.orderedFonts
      XCTAssertTrue(fonts.isEmpty)
    }
  }

  func testTagsFor() throws {
    try withNewContext(ActiveSchema.self) { context in
      XCTAssertEqual(try TagModel.tagsFor(kind: .builtin), [
        try TagModel.ubiquitous(.all),
        try TagModel.ubiquitous(.builtIn)
      ])
      XCTAssertEqual(try TagModel.tagsFor(kind: .installed), [
        try TagModel.ubiquitous(.all),
        try TagModel.ubiquitous(.added)
      ])
      XCTAssertEqual(try TagModel.tagsFor(kind: .external), [
        try TagModel.ubiquitous(.all),
        try TagModel.ubiquitous(.added),
        try TagModel.ubiquitous(.external)
      ])
    }
  }
}
