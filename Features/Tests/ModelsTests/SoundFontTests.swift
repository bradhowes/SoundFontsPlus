import XCTest
import Dependencies
import DependenciesAdditions
import SwiftData
import SF2Files

@testable import Models

final class SoundFontModelTests: XCTestCase {
  var container: ModelContainer!
  var context: ModelContext!

  @MainActor
  override func setUp() async throws {
    container = try ModelContainer(
      for: Preset.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    context = container.mainContext
  }

  @MainActor
  func mockSoundFont(name: String, location: Location) throws -> SoundFont {
    let soundFont = SoundFont(location: location, name: name)
    context.insert(soundFont)
    let presets = [
      Preset(owner: soundFont, index: 0, name: "One"),
      Preset(owner: soundFont, index: 1, name: "Two"),
      Preset(owner: soundFont, index: 2, name: "Three")
    ]

    for preset in presets {
      soundFont.presets.append(preset)
    }

    let tag = Tag(name: "Taggert")
    soundFont.tags = [tag]
    tag.tagged = [soundFont]

    try context.save()

    return soundFont
  }

  var fetched: [SoundFont] { (try? context.fetch(FetchDescriptor<SoundFont>())) ?? [] }

  @MainActor
  func testEmpty() throws {
    XCTAssertTrue(fetched.isEmpty)
  }

  @MainActor
  func testCreateSoundFont() throws {
    let location: Location = .init(kind: .builtin, url: .currentDirectory(), raw: nil)
    _ = try mockSoundFont(name: "Foo", location: location)
    let found = fetched
    XCTAssertFalse(found.isEmpty)
    XCTAssertEqual(found[0].location.kind, .builtin)
    XCTAssertEqual(found[0].location.url, .currentDirectory())
    XCTAssertEqual(found[0].displayName, "Foo")
    XCTAssertFalse(found[0].tags.isEmpty)

    XCTAssertEqual(found[0].presets.count, 3)
    XCTAssertNotNil(found[0].presets[0].name, "One")
    XCTAssertNotNil(found[0].presets[1].name, "Two")
    XCTAssertNotNil(found[0].presets[2].name, "Three")
  }

  @MainActor
  func testLoadingSoundFonts() throws {
    try withDependencies {
      $0.userDefaults = UserDefaults.Dependency.ephemeral()
    } operation: {
      _ = try context.createSoundFont(resourceTag: .freeFont)
      _ = try context.createSoundFont(resourceTag: .museScore)
      _ = try context.createSoundFont(resourceTag: .rolandNicePiano)
      
      let found = fetched
      XCTAssertFalse(found.isEmpty)
      XCTAssertEqual(found.count, 3)
      
      for font in found {
        let tag: SF2FileTag = SF2FileTag.from(name: font.displayName)
        XCTAssertEqual(font.displayName, tag.name)
        XCTAssertEqual(font.location.kind, .builtin)
        XCTAssertEqual(font.location.url, tag.url)
        
        switch tag {
        case .freeFont:
          XCTAssertEqual(font.embeddedName, "Free Font GM Ver. 3.2")
          XCTAssertEqual(font.embeddedComment, "")
          XCTAssertEqual(font.embeddedAuthor, "")
          XCTAssertEqual(font.embeddedCopyright, "")
          XCTAssertEqual(font.presets.count, 235)
          
        case .museScore:
          XCTAssertEqual(font.embeddedName, "GeneralUser GS MuseScore version 1.442")
          XCTAssertNotEqual(font.embeddedComment, "")
          XCTAssertEqual(font.embeddedAuthor, "S. Christian Collins")
          XCTAssertEqual(font.embeddedCopyright, "2012 by S. Christian Collins")
          XCTAssertEqual(font.presets.count, 270)
          
        case .rolandNicePiano:
          XCTAssertEqual(font.embeddedName, "User Bank")
          XCTAssertEqual(font.embeddedComment, "Comments Not Present")
          XCTAssertEqual(font.embeddedAuthor, "Vienna Master")
          XCTAssertEqual(font.embeddedCopyright, "Copyright Information Not Present")
          XCTAssertEqual(font.presets.count, 1)
        }
        
        XCTAssertEqual(font.tags.count, 2)
      }
      
      let builtIn = try context.ubiquitousTag(.builtIn)
      XCTAssertEqual(builtIn.tagged.count, 3)
    }
  }

  @MainActor
  func testDeletingSoundFontDeletesPresets() throws {
    try withDependencies {
      $0.userDefaults = UserDefaults.Dependency.ephemeral()
    } operation: {
      _ = try context.createSoundFont(resourceTag: .freeFont)
      var found = fetched
      XCTAssertFalse(found.isEmpty)

      var presets = try context.fetch(FetchDescriptor<Preset>())
      XCTAssertFalse(presets.isEmpty)

      context.delete(found[0])
      try context.save()

      found = fetched
      XCTAssertTrue(found.isEmpty)

      presets = try context.fetch(FetchDescriptor<Preset>())
      print(presets.count)
      try XCTSkipIf(!presets.isEmpty, "SwiftData has broken cascade")
      // XCTAssertEqual(presets.count, 0)
    }
  }

  @MainActor
  func testDeletingSoundFontUpdatesTags() throws {
    try withDependencies {
      $0.userDefaults = UserDefaults.Dependency.ephemeral()
    } operation: {
      let location: Location = .init(kind: .builtin, url: .currentDirectory(), raw: nil)
      _ = try mockSoundFont(name: "Font To Delete", location: location)
      var found = fetched
      XCTAssertFalse(found.isEmpty)

      var tags = try context.fetch(FetchDescriptor<Tag>())
      XCTAssertFalse(tags.isEmpty)
      XCTAssertFalse(tags[0].tagged.isEmpty)

      context.delete(found[0])
      try context.save()

      found = fetched
      XCTAssertTrue(found.isEmpty)

      tags = try context.fetch(FetchDescriptor<Tag>())
      XCTAssertFalse(tags.isEmpty)
      XCTAssertTrue(tags[0].tagged.isEmpty)
    }
  }

  @MainActor
  func testCustomDeletingSoundFontDeletesPresets() throws {
    try withDependencies {
      $0.userDefaults = UserDefaults.Dependency.ephemeral()
    } operation: {
      let location: Location = .init(kind: .builtin, url: .currentDirectory(), raw: nil)
      _ = try mockSoundFont(name: "Font To Delete", location: location)
      var found = fetched
      XCTAssertFalse(found.isEmpty)

      context.delete(soundFont: found[0])
      try context.save()

      found = fetched
      XCTAssertTrue(found.isEmpty)

      let presets = try context.fetch(FetchDescriptor<Preset>())
      XCTAssertEqual(presets.count, 0)
    }
  }

  @MainActor
  func testCustomDeletingSoundFontUpdatesTags() throws {
    try withDependencies {
      $0.userDefaults = UserDefaults.Dependency.ephemeral()
    } operation: {
      let location: Location = .init(kind: .builtin, url: .currentDirectory(), raw: nil)
      _ = try mockSoundFont(name: "Font To Delete", location: location)
      var found = fetched
      XCTAssertFalse(found.isEmpty)
      
      var tags = try context.fetch(FetchDescriptor<Tag>())
      XCTAssertEqual(tags.count, 1)
      XCTAssertFalse(tags[0].tagged.isEmpty)
      
      context.delete(soundFont: found[0])
      try context.save()
      
      found = fetched
      XCTAssertTrue(found.isEmpty)
      
      tags = try context.fetch(FetchDescriptor<Tag>())
      XCTAssertEqual(tags.count, 1)
      XCTAssertTrue(tags[0].tagged.isEmpty)
    }
  }

  @MainActor
  func testFetchingOrderedPresetsFromSoundFont() throws {
    try withDependencies {
      $0.userDefaults = UserDefaults.Dependency.ephemeral()
    } operation: {
      let freeFont = try context.createSoundFont(resourceTag: .freeFont)
      let museScore = try context.createSoundFont(resourceTag: .museScore)

      self.measure {
        let freeFontPresets = freeFont.orderedPresets
        XCTAssertEqual(freeFontPresets[0].name, "Piano 1")
        XCTAssertEqual(freeFontPresets[1].name, "Piano 2")
        XCTAssertEqual(freeFontPresets[2].name, "Piano 3")

        let museScorePresets = museScore.orderedPresets
        XCTAssertEqual(museScorePresets[0].name, "Stereo Grand")
        XCTAssertEqual(museScorePresets[1].name, "Bright Grand")
        XCTAssertEqual(museScorePresets[2].name, "Electric Grand")
      }
    }
  }

  @MainActor
  func testFetchingOrderedPresetsFromContext() throws {
    try withDependencies {
      $0.userDefaults = UserDefaults.Dependency.ephemeral()
    } operation: {
      let freeFont = try context.createSoundFont(resourceTag: .freeFont)
      let museScore = try context.createSoundFont(resourceTag: .museScore)

      self.measure {
        let freeFontPresets = self.context.orderedPresets(for: freeFont)
        XCTAssertEqual(freeFontPresets[0].name, "Piano 1")
        XCTAssertEqual(freeFontPresets[1].name, "Piano 2")
        XCTAssertEqual(freeFontPresets[2].name, "Piano 3")

        let museScorePresets = self.context.orderedPresets(for: museScore)
        XCTAssertEqual(museScorePresets[0].name, "Stereo Grand")
        XCTAssertEqual(museScorePresets[1].name, "Bright Grand")
        XCTAssertEqual(museScorePresets[2].name, "Electric Grand")
      }
    }
  }

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
