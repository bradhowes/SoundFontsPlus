import Dependencies
import Foundation
import SharingGRDB
import Testing

@testable import SoundFonts2

@Suite(.dependencies { $0.defaultDatabase = try appDatabase() })
struct SoundFontTests {

  @Test("migration") func migration() async throws {
    @FetchAll(Tag.all.order(by: \.id)) var tags
    try await $tags.load()

    @FetchAll(SoundFont.all.order(by: \.id)) var soundFonts
    try await $soundFonts.load()

    #expect(soundFonts.count == 3)
    #expect(soundFonts[0].displayName == SF2ResourceFileTag.freeFont.name)
    #expect(soundFonts[0].id.rawValue == 1)

    #expect(soundFonts[1].displayName == SF2ResourceFileTag.museScore.name)
    #expect(soundFonts[1].id.rawValue == 2)

    #expect(soundFonts[2].displayName == SF2ResourceFileTag.rolandNicePiano.name)
    #expect(soundFonts[2].id.rawValue == 3)

    #expect(try soundFonts[0].source().isBuiltin)
    #expect(try soundFonts[1].source().isBuiltin)
    #expect(try soundFonts[2].source().isBuiltin)

    #expect(soundFonts[0].sourceKind == "built-in")
    #expect(soundFonts[1].sourceKind == "built-in")
    #expect(soundFonts[2].sourceKind == "built-in")

    #expect(!soundFonts[0].sourcePath.isEmpty && soundFonts[0].sourcePath != "N/A")
    #expect(!soundFonts[1].sourcePath.isEmpty && soundFonts[1].sourcePath != "N/A")
    #expect(!soundFonts[2].sourcePath.isEmpty && soundFonts[2].sourcePath != "N/A")

    #expect(soundFonts[0].embeddedName == "Free Font GM Ver. 3.2")
    #expect(soundFonts[0].embeddedComment == "")
    #expect(soundFonts[0].embeddedAuthor == "")
    #expect(soundFonts[0].embeddedCopyright == "")
    #expect(soundFonts[0].notes == "")

    #expect(soundFonts[0].tags.count == 2)
    #expect(soundFonts[1].tags.count == 2)
    #expect(soundFonts[2].tags.count == 2)
  }

  @Test("soundFonts") func active() async throws {
    @FetchAll(SoundFont.activeQuery) var soundFonts
    try await $soundFonts.load()
    #expect(soundFonts.count == 3)
    #expect(soundFonts.map(\.displayName) == [
      "FreeFont",
      "MuseScore",
      "Roland Piano"
    ])
  }
}

//  @Test("add") func soundFontAdd() async throws {
//    let db = try DatabaseQueue.appDatabase(addBuiltIns: false)
//    var total = 0
//
//    let allTag = try await db.read { try Tag.find($0, id: Tag.Ubiquitous.all.id) }
//    let builtInTag = try await db.read { try Tag.find($0, id: Tag.Ubiquitous.builtIn.id) }
//    let addedTag = try await db.read { try Tag.find($0, id: Tag.Ubiquitous.added.id) }
//    let externalTag = try await db.read { try Tag.find($0, id: Tag.Ubiquitous.external.id) }
//
//    for (index, tag) in SF2ResourceFileTag.allCases.enumerated() {
//      let fileInfo = tag.fileInfo!
//      _  = try await db.write { try SoundFont.make($0, builtin: tag) }
//      let soundFonts = try await db.read {
//        try SoundFont.all().fetchAll($0).sorted { $0.id < $1.id }
//      }
//
//      #expect(soundFonts.count == index + 1)
//      #expect(soundFonts[index].displayName == tag.name)
//      #expect(soundFonts[index].id.rawValue == index + 1)
//      #expect(try soundFonts[index].source().isBuiltin)
//      #expect(soundFonts[index].notes == "")
//
//      var tagged = try await db.read { try allTag.soundFonts.fetchAll($0) }
//      #expect(tagged.count == index + 1)
//
//      tagged = try await db.read { try builtInTag.soundFonts.fetchAll($0) }
//      #expect(tagged.count == index + 1)
//
//      tagged = try await db.read { try addedTag.soundFonts.fetchAll($0) }
//      #expect(tagged.count == 0)
//
//      tagged = try await db.read { try externalTag.soundFonts.fetchAll($0) }
//      #expect(tagged.count == 0)
//
//      total += fileInfo.size()
//      var presets = try await db.read { try Preset.all().fetchAll($0) }
//      #expect(presets.count == total)
//
//      presets = try await db.read { try soundFonts[index].visiblePresetsQuery.fetchAll($0) }
//      #expect(presets.count == fileInfo.size())
//    }
//  }
//
//  @Test("delete cascades") func deletingSoundFontDeletesPresets() async throws {
//    let db = try DatabaseQueue.appDatabase()
//
//    var soundFonts = try await db.read {
//      try SoundFont.all().fetchAll($0).sorted { $0.id < $1.id }
//    }
//    #expect(soundFonts.count == 3)
//
//    let presetCount1 = try await db.read { try Preset.all().fetchCount($0) }
//
//    let sf = soundFonts[1]
//    let result = try await db.write {
//      try sf.delete($0)
//    }
//
//    #expect(result == true)
//
//    soundFonts = try await db.read {
//      try SoundFont.all().fetchAll($0).sorted { $0.id < $1.id }
//    }
//    #expect(soundFonts.count == 2)
//
//    let presetCount2 = try await db.read { try Preset.all().fetchCount($0) }
//
//    #expect(presetCount2 < presetCount1)
//  }
//
//  @Test("tagging") func tagging() async throws {
//    let database = try DatabaseQueue.appDatabase()
//    prepareDependencies { $0.defaultDatabase = database }
//    let soundFonts = try await database.read { try SoundFont.all().fetchAll($0).sorted { $0.id < $1.id } }
//    let newTag = try await database.write { try Tag.make($0, name: "new") }
//    let soundFont = soundFonts[0]
//    #expect(Operations.tagSoundFont(newTag.id, soundFontId: soundFont.id) != nil)
//    let tagged = try await database.read { try newTag.soundFonts.fetchAll($0) }
//    #expect(tagged.count == 1)
//    #expect(Operations.tagSoundFont(newTag.id, soundFontId: soundFont.id) == nil)
//  }
//
//  @Test("untagging") func untagging() async throws {
//    let database = try DatabaseQueue.appDatabase()
//    prepareDependencies { $0.defaultDatabase = database }
//    let soundFonts = try await database.read { try SoundFont.all().fetchAll($0).sorted { $0.id < $1.id } }
//    let newTag = try await database.write { try Tag.make($0, name: "new") }
//    let soundFont = soundFonts[0]
//    #expect(Operations.tagSoundFont(newTag.id, soundFontId: soundFont.id) != nil)
//    var tagged = try await database.read { try newTag.soundFonts.fetchAll($0) }
//    #expect(tagged.count == 1)
//
//    #expect(Operations.untagSoundFont(newTag.id, soundFontId: soundFont.id))
//    tagged = try await database.read { try newTag.soundFonts.fetchAll($0) }
//    #expect(tagged.count == 0)
//
//    #expect(Operations.untagSoundFont(newTag.id, soundFontId: soundFont.id) == false)
//  }
//
//  @Test("tagging with ubiquitous") func taggingWithUbiquitousFails() async throws {
//    let db = try DatabaseQueue.appDatabase()
//    let soundFonts = try await db.read { try SoundFont.all().fetchAll($0).sorted { $0.id < $1.id } }
//    let soundFont = soundFonts[0]
//    let allTag = try await db.read { try Tag.find($0, id: Tag.Ubiquitous.all.id) }
//    #expect(throws: ModelError.self) {
//      try Operations.tagSoundFont(allTag.id, soundFontId: soundFont.id)
//    }
//  }
//
//  @Test("untagging with ubiquitous") func untaggingWithUbiquitousFails() async throws {
//    let db = try DatabaseQueue.appDatabase()
//    let soundFonts = try await db.read { try SoundFont.all().fetchAll($0).sorted { $0.id < $1.id } }
//    let soundFont = soundFonts[0]
//    let allTag = try await db.read { try Tag.find($0, id: Tag.Ubiquitous.all.id) }
//    #expect(throws: ModelError.self) {
//      try Operations.untagSoundFont(allTag.id, soundFontId: soundFont.id)
//    }
//  }
//
//  @Test("delete updates tags") func deletingSoundFontUpdatesTags() async throws {
//    let db = try DatabaseQueue.appDatabase()
//
//    let allTag = try await db.read { try Tag.find($0, id: Tag.Ubiquitous.all.id) }
//    let builtInTag = try await db.read { try Tag.find($0, id: Tag.Ubiquitous.builtIn.id) }
//
//    var tagged = try await db.read { try allTag.soundFonts.fetchAll($0) }
//    #expect(tagged.count == 3)
//
//    tagged = try await db.read { try builtInTag.soundFonts.fetchAll($0) }
//    #expect(tagged.count == 3)
//
//    let soundFonts = try await db.read {
//      try SoundFont.all().fetchAll($0).sorted { $0.id < $1.id }
//    }
//
//    let sf = soundFonts[1]
//    let result = try await db.write {
//      try sf.delete($0)
//    }
//
//    #expect(result == true)
//
//    tagged = try await db.read { try allTag.soundFonts.fetchAll($0) }
//    #expect(tagged.count == 2)
//
//    tagged = try await db.read { try builtInTag.soundFonts.fetchAll($0) }
//    #expect(tagged.count == 2)
//  }
//
//  @Test("presets ordered by index") func presetsFromSoundFontAreOrderedByIndex() async throws {
//    let db = try DatabaseQueue.appDatabase()
//    let soundFonts = try await db.read {
//      try SoundFont.all().fetchAll($0).sorted { $0.id < $1.id }
//    }
//
//    let presets = try await db.read { try soundFonts[0].visiblePresetsQuery.fetchAll($0) }
//
//    #expect(presets[0].index == 0)
//    #expect(presets[0].displayName == "Piano 1")
//    #expect(presets[1].index == 1)
//    #expect(presets[1].displayName == "Piano 2")
//    #expect(presets[2].index == 2)
//    #expect(presets[2].displayName == "Piano 3")
//
//    let museScorePresets = try await db.read { try soundFonts[1].visiblePresetsQuery.fetchAll($0) }
//    #expect(museScorePresets[0].index == 0)
//    #expect(museScorePresets[0].displayName == "Stereo Grand")
//    #expect(museScorePresets[1].index == 1)
//    #expect(museScorePresets[1].displayName == "Bright Grand")
//    #expect(museScorePresets[2].index == 2)
//    #expect(museScorePresets[2].displayName == "Electric Grand")
//  }
//
//  @Test("presets filtered by visibility") func presetsFromSoundFontAreFilteredByVisibility() async throws {
//    let db = try DatabaseQueue.appDatabase()
//    for tag in SF2ResourceFileTag.allCases.enumerated() {
//      let fileInfo = tag.1.fileInfo!
//      if fileInfo.size() == 1 { continue }
//      let sf = try await db.read { try SoundFont.fetchOne($0, id: SoundFont.ID(Int64(tag.0 + 1)))! }
//      try await db.write {
//        var presets = try sf.visiblePresetsQuery.fetchAll($0)
//        presets[1].visible = false
//        try presets[1].update($0)
//        presets[3].visible = false
//        try presets[3].update($0)
//      }
//    }
//
//    // Insertion order
//    let soundFonts = try await db.read { try SoundFont.all().order(SoundFont.Columns.id).fetchAll($0) }
//
//    var presets = try await db.read { try soundFonts[0].visiblePresetsQuery.fetchAll($0) }
//    #expect(presets[0].index == 0)
//    #expect(presets[0].displayName == "Piano 1")
//    #expect(presets[1].index == 2)
//    #expect(presets[1].displayName == "Piano 3")
//    #expect(presets[2].index == 4)
//    #expect(presets[2].displayName == "E.Piano 1")
//    var allPresets = try await db.read { try soundFonts[0].allPresetsQuery.fetchAll($0) }
//    #expect(presets.count < allPresets.count)
//
//    presets = try await db.read { try soundFonts[1].visiblePresetsQuery.fetchAll($0) }
//    #expect(presets[0].index == 0)
//    #expect(presets[0].displayName == "Stereo Grand")
//    #expect(presets[1].index == 2)
//    #expect(presets[1].displayName == "Electric Grand")
//    #expect(presets[2].index == 4)
//    #expect(presets[2].displayName == "Tine Electric Piano")
//    allPresets = try await db.read { try soundFonts[1].allPresetsQuery.fetchAll($0) }
//    #expect(presets.count < allPresets.count)
//  }
//
//  @Test("fetch by id") func fetchingSpecificSoundFont() async throws {
//    let db = try DatabaseQueue.appDatabase()
//    let soundFont = try await db.read { try SoundFont.fetchOne($0, id: .init(2)) }
//    #expect(soundFont != nil)
//    #expect(soundFont?.displayName == "MuseScore")
//  }
//
//  @Test("add invalid path") func addInvalidPath() async throws {
//    let db = try DatabaseQueue.appDatabase()
//    await #expect(throws: ModelError.self) {
//      try await db.write {
//        let data = URL(filePath: "/a/b/c").absoluteString.data(using: .utf8)!
//        try SoundFont.make($0, displayName: "Blah blah", soundFontKind: .init(kind: .builtin, location: data))
//      }
//    }
//  }
//
//  @Test("location decoding") func testLocationDecoding() async throws {
//    // let db = try await setupDatabase()
//  }
//}
//
////
////  func testTaggedWithInvalidTag() throws {
////    try withNewContext(ActiveSchema.self) { context in
////      let font = try SoundFontModel.tagged(with: TagModel.Ubiquitous.builtIn.key)[0]
////
////      let tag = try withDependencies {
////        $0.uuid = .constant(.init(123))
////      } operation: {
////        let tag = try TagModel.create(name: "blah")
////        font.tag(with: tag)
////        try context.save()
////        return tag
////      }
////
////      XCTAssertTrue(font.tags.contains(tag))
////      XCTAssertTrue(tag.tagged.contains(font))
////
////      do {
////        let tag = try TagModel.fetch(key: tag.key)
////        XCTAssertEqual(tag.name, "blah")
////        XCTAssertTrue(tag.tagged.contains(font))
////      }
////
////      var fonts = try SoundFontModel.tagged(with: tag.key)
////      XCTAssertEqual(fonts.count, 1)
////
////      let tagKey = tag.key
////      context.delete(tag)
////      try context.save()
////
////      fonts = try SoundFontModel.tagged(with: tagKey)
////      XCTAssertEqual(fonts.count, 3)
////    }
////  }
////}
