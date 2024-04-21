import XCTest
import Dependencies
import SwiftData
import Dependencies

@testable import Models

@MainActor
final class SoundFontModelTests: XCTestCase {
  @Dependency(\.uuid) var uuid

  var container: ModelContainer!
  var context: ModelContext!

  override func setUp() async throws {
    container = try ModelContainer(
      for: SoundFontModel.self, PresetModel.self, PresetInfoModel.self, AudioSettingsModel.self, FavoriteModel.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    context = container.mainContext
  }

  func mockSoundFont(id: UUID, name: String, location: Location) throws -> SoundFontModel {
    let soundFont = SoundFontModel(
      id: id,
      name: name,
      location: location,
      presets: [
        PresetModel(soundFontId: id.uuidString, index: 0, name: "One",
                    info: .init(originalName: "One", bank: 0, program: 1), audioSettings: .init()),
        PresetModel(soundFontId: id.uuidString, index: 1, name: "Two",
                    info: .init(originalName: "Two", bank: 0, program: 2), audioSettings: .init()),
        PresetModel(soundFontId: id.uuidString, index: 2, name: "Three",
                    info: .init(originalName: "Three", bank: 0, program: 3), audioSettings: .init()),
      ],
      embeddedName: "Embedded Name",
      embeddedComment: "Embedded Comment",
      embeddedAuthor: "Embedded Author",
      embeddedCopyright: "Embedded Copyright"
    )
    context.insert(soundFont)
    try context.save()

    return soundFont
  }

  func testEmpty() throws {
    let found = try context.fetch(FetchDescriptor<SoundFontModel>())
    XCTAssertTrue(found.isEmpty)
  }

  func testCreateSoundFont() throws {
    let location: Location = .init(kind: .builtin, url: .currentDirectory(), bookmark: nil)
    try withDependencies {
      $0.uuid = .incrementing
    } operation: {
      let id = uuid()
      _ = try mockSoundFont(id: id, name: "Foo", location: location)
      let found = try context.fetch(FetchDescriptor<SoundFontModel>())
      XCTAssertFalse(found.isEmpty)
      XCTAssertEqual(found[0].location.kind, .builtin)
      XCTAssertEqual(found[0].location.url, URL.currentDirectory())
      XCTAssertEqual(found[0].name, "Foo")
      XCTAssertEqual(found[0].embeddedName, "Embedded Name")
      XCTAssertEqual(found[0].embeddedComment, "Embedded Comment")
      XCTAssertEqual(found[0].embeddedAuthor, "Embedded Author")
      XCTAssertEqual(found[0].embeddedCopyright, "Embedded Copyright")
      XCTAssertTrue(found[0].tags.isEmpty)

      let descriptor = FetchDescriptor<PresetModel>(predicate: #Predicate { $0.soundFontId == id.uuidString },
                                                    sortBy: [SortDescriptor(\.index)])
      let presets = try context.fetch(descriptor)
      XCTAssertEqual(presets.count, 3)
      XCTAssertNotNil(presets[0].name, "One")
      XCTAssertNotNil(presets[1].name, "Two")
      XCTAssertNotNil(presets[2].name, "Three")
    }
  }

//  func testChangeSoundFont() throws {
//    let location: Location = .init(kind: .builtin, url: .currentDirectory(), data: nil)
//    let soundFont = try mockSoundFont(location: location, name: "Foo")
//
//    var found = try context.fetch(FetchDescriptor<SoundFontModel>())
//    XCTAssertEqual(found[0].name, "Foo")
//    XCTAssertEqual(found[0].location.kind, .builtin)
//
//    found[0].name = "Foo Bar"
//    found[0].location = Location(kind: .installed, url: .currentDirectory(), data: nil)
//
//    try context.save()
//
//    found = try context.fetch(FetchDescriptor<SoundFontModel>())
//    XCTAssertEqual(found[0].name, "Foo Bar")
//    XCTAssertEqual(found[0].location.kind, .installed)
//  }
//
//  func testDeleteSoundFont() throws {
//    let location: Location = .init(kind: .builtin, url: .currentDirectory(), data: nil)
//    let soundFont = try mockSoundFont(location: location, name: "Foo")
//    var found = try context.fetch(FetchDescriptor<SoundFontModel>())
//    XCTAssertFalse(found.isEmpty)
//
//    context.delete(found[0])
//    try context.save()
//
//    found = try context.fetch(FetchDescriptor<SoundFontModel>())
//    XCTAssertTrue(found.isEmpty)
//  }
//
//  func testAddFavorite() throws {
//    let location: Location = .init(kind: .builtin, url: .currentDirectory(), data: nil)
//    let soundFont = try mockSoundFont(location: location, name: "SoundFont")
//    let favorite = try mockFavorite(name: "Favorite", soundFont: soundFont, preset: soundFont.presets[1])
//    soundFont.presets[1].favorites.append(favorite)
//    try context.save()
//    let found = try context.fetch(FetchDescriptor<SoundFontModel>())
//  }
//
//  func testTagAddition() throws {
//    let location: Location = .init(kind: .builtin, url: .currentDirectory(), data: nil)
//    let soundFont = try mockSoundFont(location: location, name: "Foo")
//    let tag = TagModel(id: .init(UUID()), name: "Tag")
//    context.insert(tag)
//    try context.save()
//
//    var soundFonts = try context.fetch(FetchDescriptor<SoundFontModel>())
//    XCTAssertTrue(soundFonts[0].tags.isEmpty)
//
//    soundFonts[0].tags.append(tag.id)
//    try context.save()
//
//    soundFonts = try context.fetch(FetchDescriptor<SoundFontModel>())
//    XCTAssertEqual(soundFonts[0].tags.count, 1)
//    XCTAssertEqual(soundFonts[0].tags[0], tag.id)
//
//    let tags = try context.fetch(FetchDescriptor<TagModel>())
//    XCTAssertEqual(tags[0].name, "Tag")
//  }
//
//  func testTagDeletion() throws {
//    let location: Location = .init(kind: .builtin, url: .currentDirectory(), data: nil)
//    let soundFont = try mockSoundFont(location: location, name: "Foo")
//    let tag = TagModel(id: .init(UUID()), name: "Tag")
//    context.insert(tag)
//    soundFont.tags.append(tag.id)
//    try context.save()
//
//    let tags = try context.fetch(FetchDescriptor<TagModel>())
//    XCTAssertEqual(tags[0].name, "Tag")
//
//    context.delete(tags[0])
//    try context.save()
//
//    let soundFonts = try context.fetch(FetchDescriptor<SoundFontModel>())
//    XCTAssertTrue(soundFonts[0].tags.isEmpty)
//  }
}
