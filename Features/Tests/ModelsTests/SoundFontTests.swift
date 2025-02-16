import Dependencies
import Foundation
import GRDB
import SF2ResourceFiles
import Testing

@testable import Models

@Test func testMigration() async throws {
  let db = try DatabaseQueue.appDatabase()
  try await db.read {
    for each in V1.tables {
      try $0.execute(sql: "select * from \(each.databaseTableName)")
    }
  }
}

@Test func testSoundFontTable() async throws {
  let db = try DatabaseQueue.appDatabase()
  let tag = SF2ResourceFileTag.freeFont
  let fileInfo = tag.fileInfo!

  try await db.write {
    _  = try SoundFont.make(
      in: $0,
      displayName: tag.fileName,
      location: Location(kind: .builtin, url: tag.url, raw: nil),
      fileInfo: fileInfo
    )
  }

  let query = SoundFont.all()
  let soundFonts = try await db.read { try query.fetchAll($0) }
  #expect(soundFonts.count == 1)
  #expect(soundFonts[0].displayName == "FreeFont")
  #expect(soundFonts[0].id.rawValue == 1)
  #expect(soundFonts[0].location.kind == .builtin)
  #expect(soundFonts[0].embeddedName == "Free Font GM Ver. 3.2")
  #expect(soundFonts[0].embeddedComment == "")
  #expect(soundFonts[0].embeddedAuthor == "")
  #expect(soundFonts[0].embeddedCopyright == "")
  #expect(soundFonts[0].notes == "")
}

@Test
func testSoundFontAdd() async throws {
  let db = try DatabaseQueue.appDatabase()
  var total = 0

  let allTag = try await db.read { try Tag.find($0, id: Tag.Ubiquitous.all.id) }
  let builtInTag = try await db.read { try Tag.find($0, id: Tag.Ubiquitous.builtIn.id) }
  let addedTag = try await db.read { try Tag.find($0, id: Tag.Ubiquitous.added.id) }
  let externalTag = try await db.read { try Tag.find($0, id: Tag.Ubiquitous.external.id) }

  for tag in SF2ResourceFileTag.allCases.enumerated() {
    let fileInfo = tag.1.fileInfo!
    try await db.write {
      _  = try SoundFont.add(
        in: $0,
        displayName: tag.1.name,
        location: Location(kind: .builtin, url: tag.1.url, raw: nil),
        fileInfo: fileInfo
      )
    }

    let soundFonts = try await db.read {
      try SoundFont.all().fetchAll($0).sorted { $0.id < $1.id }
    }

    #expect(soundFonts.count == tag.0 + 1)
    #expect(soundFonts[tag.0].displayName == tag.1.name)
    #expect(soundFonts[tag.0].id.rawValue == tag.0 + 1)
    #expect(soundFonts[tag.0].location.kind == .builtin)
    #expect(soundFonts[tag.0].notes == "")

    var tagged = try await db.read { try allTag.soundFonts.fetchAll($0) }
    #expect(tagged.count == tag.0 + 1)

    tagged = try await db.read { try builtInTag.soundFonts.fetchAll($0) }
    #expect(tagged.count == tag.0 + 1)

    tagged = try await db.read { try addedTag.soundFonts.fetchAll($0) }
    #expect(tagged.count == 0)

    tagged = try await db.read { try externalTag.soundFonts.fetchAll($0) }
    #expect(tagged.count == 0)

    total += fileInfo.size()
    var presets = try await db.read { try Preset.all().fetchAll($0) }
    #expect(presets.count == total)

    presets = try await db.read { try soundFonts[tag.0].presets.fetchAll($0) }
    #expect(presets.count == fileInfo.size())
  }
}

@Test
func testDeletingSoundFontDeletesPresets() async throws {
  let db = try DatabaseQueue.appDatabase()
  for tag in SF2ResourceFileTag.allCases.enumerated() {
    let fileInfo = tag.1.fileInfo!
    try await db.write {
      _  = try SoundFont.add(
        in: $0,
        displayName: tag.1.name,
        location: Location(kind: .builtin, url: tag.1.url, raw: nil),
        fileInfo: fileInfo
      )
    }
  }

  var soundFonts = try await db.read {
    try SoundFont.all().fetchAll($0).sorted { $0.id < $1.id }
  }
  #expect(soundFonts.count == 3)

  let presetCount1 = try await db.read { try Preset.all().fetchCount($0) }

  let sf = soundFonts[1]
  let result = try await db.write {
    try sf.delete($0)
  }

  #expect(result == true)

  soundFonts = try await db.read {
    try SoundFont.all().fetchAll($0).sorted { $0.id < $1.id }
  }
  #expect(soundFonts.count == 2)

  let presetCount2 = try await db.read { try Preset.all().fetchCount($0) }

  #expect(presetCount2 < presetCount1)
}

@Test
func testDeletingSoundFontUpdatesTags() async throws {
  let db = try DatabaseQueue.appDatabase()

  let allTag = try await db.read { try Tag.find($0, id: Tag.Ubiquitous.all.id) }
  let builtInTag = try await db.read { try Tag.find($0, id: Tag.Ubiquitous.builtIn.id) }

  for tag in SF2ResourceFileTag.allCases.enumerated() {
    let fileInfo = tag.1.fileInfo!
    try await db.write {
      _  = try SoundFont.add(
        in: $0,
        displayName: tag.1.name,
        location: Location(kind: .builtin, url: tag.1.url, raw: nil),
        fileInfo: fileInfo
      )
    }
  }

  var tagged = try await db.read { try allTag.soundFonts.fetchAll($0) }
  #expect(tagged.count == 3)

  tagged = try await db.read { try builtInTag.soundFonts.fetchAll($0) }
  #expect(tagged.count == 3)

  var soundFonts = try await db.read {
    try SoundFont.all().fetchAll($0).sorted { $0.id < $1.id }
  }

  let sf = soundFonts[1]
  let result = try await db.write {
    try sf.delete($0)
  }

  #expect(result == true)

  tagged = try await db.read { try allTag.soundFonts.fetchAll($0) }
  #expect(tagged.count == 2)

  tagged = try await db.read { try builtInTag.soundFonts.fetchAll($0) }
  #expect(tagged.count == 2)
}

@Test
func testFetchingOrderedPresetsFromSoundFont() async throws {
  let db = try DatabaseQueue.appDatabase()
  for tag in SF2ResourceFileTag.allCases.enumerated() {
    let fileInfo = tag.1.fileInfo!
    try await db.write {
      _  = try SoundFont.add(
        in: $0,
        displayName: tag.1.name,
        location: Location(kind: .builtin, url: tag.1.url, raw: nil),
        fileInfo: fileInfo
      )
    }
  }

  let soundFonts = try await db.read {
    try SoundFont.all().fetchAll($0).sorted { $0.id < $1.id }
  }

  let presets = try await db.read { try soundFonts[0].presets.fetchAll($0) }

  #expect(presets[0].index == 0)
  #expect(presets[0].displayName == "Piano 1")
  #expect(presets[1].index == 1)
  #expect(presets[1].displayName == "Piano 2")
  #expect(presets[2].index == 2)
  #expect(presets[2].displayName == "Piano 3")

  let museScorePresets = try await db.read { try soundFonts[1].presets.fetchAll($0) }
  #expect(museScorePresets[0].index == 0)
  #expect(museScorePresets[0].displayName == "Stereo Grand")
  #expect(museScorePresets[1].index == 1)
  #expect(museScorePresets[1].displayName == "Bright Grand")
  #expect(museScorePresets[2].index == 2)
  #expect(museScorePresets[2].displayName == "Electric Grand")
}

//
//  func testFetchingOrderedVisiblePresetsFromSoundFont() throws {
//    try withNewContext(ActiveSchema.self, addBuiltInFonts: false) { context in
//
//      let freeFont = try SoundFontModel.add(resourceTag: .freeFont)
//      freeFont.orderedPresets[0].visible = false
//      freeFont.orderedPresets[2].visible = false
//      let museScore = try SoundFontModel.add(resourceTag: .museScore)
//      museScore.orderedPresets[1].visible = false
//      museScore.orderedPresets[2].visible = false
//      self.measure {
//        let freeFontPresets = freeFont.orderedVisiblePresets
//        XCTAssertEqual(freeFontPresets[0].displayName, "Piano 2")
//        XCTAssertEqual(freeFontPresets[1].displayName, "Honky-tonk")
//        XCTAssertEqual(freeFontPresets[2].displayName, "E.Piano 1")
//
//        let museScorePresets = museScore.orderedVisiblePresets
//        XCTAssertEqual(museScorePresets[0].displayName, "Stereo Grand")
//        XCTAssertEqual(museScorePresets[1].displayName, "Honky-Tonk")
//        XCTAssertEqual(museScorePresets[2].displayName, "Tine Electric Piano")
//      }
//    }
//  }
//
//  func testFetchingSpecifcSoundFont() throws {
//    try withNewContext(ActiveSchema.self, addBuiltInFonts: false) { context in
//      let freeFont = try SoundFontModel.add(resourceTag: .freeFont)
//      _ = try ActiveSchema.SoundFontModel.fetch(key: freeFont.key)
//    }
//  }
//
//  func testAddFailure() throws {
//    try withNewContext(ActiveSchema.self, addBuiltInFonts: false) { context in
//      XCTAssertThrowsError(try SoundFontModel.add(name: "Hubba", kind: .installed(file: URL(filePath: "/a/b/c")), tags: []))
//    }
//  }
//
//  func testLocationDecoding() throws {
//    try withNewContext(ActiveSchema.self, addBuiltInFonts: false) { context in
//
//      let freeFont = try SoundFontModel.add(resourceTag: .freeFont)
//      XCTAssertEqual(try freeFont.kind(), .builtin(resource: SF2ResourceFileTag.freeFont.url))
//
//      freeFont.location = .init(kind: .builtin, url: nil , raw: nil)
//      XCTAssertThrowsError(try freeFont.kind())
//
//      freeFont.location = .init(kind: .installed, url: nil , raw: nil)
//      XCTAssertThrowsError(try freeFont.kind())
//
//      freeFont.location = .init(kind: .installed, url: SF2ResourceFileTag.freeFont.url , raw: nil)
//      XCTAssertEqual(try freeFont.kind(), .installed(file: SF2ResourceFileTag.freeFont.url))
//
//      freeFont.location = .init(kind: .external, url: nil, raw: nil)
//      XCTAssertThrowsError(try freeFont.kind())
//
//      let bookmark = Bookmark(url: SF2ResourceFileTag.freeFont.url, name: "FreeFont")
//      freeFont.location = .init(kind: .external, url: nil , raw: bookmark.bookmark)
//      XCTAssertThrowsError(try freeFont.kind())
//    }
//  }
//
//  func testTaggedWithInvalidTag() throws {
//    try withNewContext(ActiveSchema.self) { context in
//      let font = try SoundFontModel.tagged(with: TagModel.Ubiquitous.builtIn.key)[0]
//
//      let tag = try withDependencies {
//        $0.uuid = .constant(.init(123))
//      } operation: {
//        let tag = try TagModel.create(name: "blah")
//        font.tag(with: tag)
//        try context.save()
//        return tag
//      }
//
//      XCTAssertTrue(font.tags.contains(tag))
//      XCTAssertTrue(tag.tagged.contains(font))
//
//      do {
//        let tag = try TagModel.fetch(key: tag.key)
//        XCTAssertEqual(tag.name, "blah")
//        XCTAssertTrue(tag.tagged.contains(font))
//      }
//
//      var fonts = try SoundFontModel.tagged(with: tag.key)
//      XCTAssertEqual(fonts.count, 1)
//
//      let tagKey = tag.key
//      context.delete(tag)
//      try context.save()
//
//      fonts = try SoundFontModel.tagged(with: tagKey)
//      XCTAssertEqual(fonts.count, 3)
//    }
//  }
//}
