import XCTest
import Dependencies
import SwiftData
import SF2ResourceFiles

@testable import Models

final class SoundFontModelTests: XCTestCase {
  typealias ActiveSchema = SchemaV1

  func testCreatingV1Database() throws {
    try withNewContext(ActiveSchema.self, makeUbiquitousTags: false, addBuiltInFonts: false) { context in

      _ = try ["All", "Jazz", "Funk"].map { try ActiveSchema.TagModel.create(name: $0) }
      var tags = try! context.fetch(TagModel.fetchDescriptor())
      XCTAssertEqual(tags.count, 3)

      _ = try ["Foo", "Bar", "Bizz", "Buzz"].enumerated().map { index, name in
        try Mock.makeSoundFont(
          name: name,
          presetNames: (1...(3 + index * 2)).map { "\(name) Preset \($0)" },
          tags: Array(tags[0..<min(index + 1, tags.count)])
        )
      }

      let fonts = try! context.fetch(SoundFontModel.fetchDescriptor())
      XCTAssertEqual(fonts.count, 4)
      XCTAssertEqual(fonts[0].displayName, "Bar")
      XCTAssertEqual(fonts[1].displayName, "Bizz")
      XCTAssertEqual(fonts[2].displayName, "Buzz")
      XCTAssertEqual(fonts[3].displayName, "Foo")

      XCTAssertEqual(fonts[0].presets.count, 5)
      XCTAssertEqual(fonts[1].presets.count, 7)
      XCTAssertEqual(fonts[2].presets.count, 9)
      XCTAssertEqual(fonts[3].presets.count, 3)

      for font in fonts {
        XCTAssertEqual(font.orderedPresets.map(\.displayName),
                       (1...font.presets.count).map { "\(font.displayName) Preset \($0)" })
      }

      let preset = fonts[0].orderedPresets[0]
      let favorite = FavoriteModel(
        preset: preset,
        displayName: "My Favorite"
      )

      context.insert(favorite)
      preset.favorites = [favorite]
      try! context.save()

      XCTAssertEqual(fonts[0].tags.map(\.name).sorted(), ["All", "Funk"])
      XCTAssertEqual(fonts[1].tags.map(\.name).sorted(), ["All", "Funk", "Jazz"])
      XCTAssertEqual(fonts[2].tags.map(\.name).sorted(), ["All", "Funk", "Jazz"])
      XCTAssertEqual(fonts[3].tags.map(\.name).sorted(), ["All"])

      tags = try! context.fetch(TagModel.fetchDescriptor())
      XCTAssertEqual(tags.count, 3)
      XCTAssertEqual(tags[0].tagged.map(\.displayName).sorted(), ["Bar", "Bizz", "Buzz", "Foo"])
      XCTAssertEqual(tags[1].tagged.map(\.displayName).sorted(), ["Bar", "Bizz", "Buzz"])
      XCTAssertEqual(tags[2].tagged.map(\.displayName).sorted(), ["Bizz", "Buzz"])
    }
  }

  func testCreateSoundFont() throws {
    try withNewContext(ActiveSchema.self, makeUbiquitousTags: true, addBuiltInFonts: false) { context in
      _ = try Mock.makeSoundFont(
        name: "Foo",
        presetNames: ["One", "Two", "Three"],
        tags: [ActiveSchema.TagModel.ubiquitous(.all)]
      )

      let found = try! context.fetch(SoundFontModel.fetchDescriptor())
      XCTAssertFalse(found.isEmpty)
      XCTAssertEqual(found[0].displayName, "Foo")
      XCTAssertEqual(found[0].tags.count, 1)

      XCTAssertEqual(found[0].presets.count, 3)
      XCTAssertNotNil(found[0].presets[0].displayName, "One")
      XCTAssertNotNil(found[0].presets[1].displayName, "Two")
      XCTAssertNotNil(found[0].presets[2].displayName, "Three")
    }
  }

  func testLoadingBuiltin() throws {
    try withNewContext(ActiveSchema.self) { context in
      let found = try! context.fetch(SoundFontModel.fetchDescriptor())
      XCTAssertEqual(found.count, 3)

      for font in found {
        let tag: SF2ResourceFileTag = SF2ResourceFileTag.from(name: font.displayName)
        XCTAssertEqual(font.displayName, tag.name)
        XCTAssertEqual(font.location.kind, .builtin)
        XCTAssertEqual(font.location.url, tag.url)

        switch tag {
        case .freeFont:
          XCTAssertEqual(font.info.embeddedName, "Free Font GM Ver. 3.2")
          XCTAssertEqual(font.info.embeddedComment, "")
          XCTAssertEqual(font.info.embeddedAuthor, "")
          XCTAssertEqual(font.info.embeddedCopyright, "")
          XCTAssertEqual(font.presets.count, 235)
          XCTAssertEqual(try font.kind(), .builtin(resource: tag.url))

        case .museScore:
          XCTAssertEqual(font.info.embeddedName, "GeneralUser GS MuseScore version 1.442")
          XCTAssertNotEqual(font.info.embeddedComment, "")
          XCTAssertEqual(font.info.embeddedAuthor, "S. Christian Collins")
          XCTAssertEqual(font.info.embeddedCopyright, "2012 by S. Christian Collins")
          XCTAssertEqual(font.presets.count, 270)
          XCTAssertEqual(try font.kind(), .builtin(resource: tag.url))

        case .rolandNicePiano:
          XCTAssertEqual(font.info.embeddedName, "User Bank")
          XCTAssertEqual(font.info.embeddedComment, "Comments Not Present")
          XCTAssertEqual(font.info.embeddedAuthor, "Vienna Master")
          XCTAssertEqual(font.info.embeddedCopyright, "Copyright Information Not Present")
          XCTAssertEqual(font.presets.count, 1)
          XCTAssertEqual(try font.kind(), .builtin(resource: tag.url))
        }

        XCTAssertEqual(font.tags.count, 2)
      }

      let builtIn = try TagModel.ubiquitous(.builtIn)
      XCTAssertEqual(builtIn.tagged.count, 3)
    }
  }

  func testDeletingSoundFontDeletesPresets() throws {
    try withNewContext(ActiveSchema.self, addBuiltInFonts: false) { context in
      _ = try SoundFontModel.add(resourceTag: .freeFont)
      var found = try context.fetch(SoundFontModel.fetchDescriptor())
      XCTAssertEqual(found.count, 1)
      XCTAssertEqual(try context.fetch(FetchDescriptor<PresetModel>()).count, 235)

      context.delete(found[0])
      try context.save()

      found = try context.fetch(SoundFontModel.fetchDescriptor())
      XCTAssertTrue(found.isEmpty)

      let presets = try context.fetch(FetchDescriptor<PresetModel>())
      XCTAssertTrue(presets.isEmpty)
    }
  }

  func testDeletingSoundFontUpdatesTags() throws {
    try withNewContext(ActiveSchema.self) { context in
      let fonts = try context.fetch(SoundFontModel.fetchDescriptor())
      XCTAssertEqual(fonts.count, 3)

      var builtIn = try TagModel.ubiquitous(.builtIn)
      XCTAssertEqual(builtIn.tagged.count, 3)

      context.delete(fonts[0])
      try context.save()

      builtIn = try TagModel.ubiquitous(.builtIn)
      XCTAssertEqual(builtIn.tagged.count, 2)
    }
  }

  func testFetchingOrderedPresetsFromSoundFont() throws {
    try withNewContext(ActiveSchema.self, addBuiltInFonts: false) { context in

      let freeFont = try SoundFontModel.add(resourceTag: .freeFont)
      let museScore = try SoundFontModel.add(resourceTag: .museScore)

      self.measure {
        let freeFontPresets = freeFont.orderedPresets
        XCTAssertEqual(freeFontPresets[0].displayName, "Piano 1")
        XCTAssertEqual(freeFontPresets[1].displayName, "Piano 2")
        XCTAssertEqual(freeFontPresets[2].displayName, "Piano 3")

        let museScorePresets = museScore.orderedPresets
        XCTAssertEqual(museScorePresets[0].displayName, "Stereo Grand")
        XCTAssertEqual(museScorePresets[1].displayName, "Bright Grand")
        XCTAssertEqual(museScorePresets[2].displayName, "Electric Grand")
      }
    }
  }

  func testAddFailure() throws {
    try withNewContext(ActiveSchema.self, addBuiltInFonts: false) { context in
      XCTAssertThrowsError(try SoundFontModel.add(name: "Hubba", kind: .installed(file: URL(filePath: "/a/b/c")), tags: []))
    }
  }

  func testLocationDecoding() throws {
    try withNewContext(ActiveSchema.self, addBuiltInFonts: false) { context in

      let freeFont = try SoundFontModel.add(resourceTag: .freeFont)
      XCTAssertEqual(try freeFont.kind(), .builtin(resource: SF2ResourceFileTag.freeFont.url))

      freeFont.location = .init(kind: .builtin, url: nil , raw: nil)
      XCTAssertThrowsError(try freeFont.kind())

      freeFont.location = .init(kind: .installed, url: nil , raw: nil)
      XCTAssertThrowsError(try freeFont.kind())

      freeFont.location = .init(kind: .installed, url: SF2ResourceFileTag.freeFont.url , raw: nil)
      XCTAssertEqual(try freeFont.kind(), .installed(file: SF2ResourceFileTag.freeFont.url))

      freeFont.location = .init(kind: .external, url: nil, raw: nil)
      XCTAssertThrowsError(try freeFont.kind())

      let bookmark = Bookmark(url: SF2ResourceFileTag.freeFont.url, name: "FreeFont")
      freeFont.location = .init(kind: .external, url: nil , raw: bookmark.bookmark)
      XCTAssertThrowsError(try freeFont.kind())
    }
  }

  func testInitialWith() throws {
    try withNewContext(ActiveSchema.self, addBuiltInFonts: false) { context in
      let fonts = try SoundFontModel.tagged(with: .all)
      XCTAssertEqual(fonts.count, 3)
    }
  }

  func testWith() throws {
    try withNewContext(ActiveSchema.self) { context in
      let fonts = try SoundFontModel.tagged(with: .builtIn)
      XCTAssertEqual(fonts.count, 3)
    }
  }
}
