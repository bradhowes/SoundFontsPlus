//import XCTest
//import ComposableArchitecture
//import SwiftData
//
//@testable import Models
//
//final class PresetTests: XCTestCase {
//
//  func testEmpty() throws {
//    try withNewContext(ActiveSchema.self, makeUbiquitousTags: false, addBuiltInFonts: false) { context in
//      XCTAssertTrue((try context.fetch(FetchDescriptor<PresetModel>()).isEmpty))
//    }
//  }
//
//  func testCreateNewPresets() throws {
//    try withNewContext(ActiveSchema.self, addBuiltInFonts: false) { context in
//      _ = try Mock.makeSoundFont(name: "My Font", presetNames: ["Foo", "Bar"], tags: [.ubiquitous(.all)])
//      try context.save()
//      let fonts = try SoundFontModel.tagged(with: TagModel.Ubiquitous.all.key)
//      XCTAssertEqual(fonts[0].presets.count, 2)
//    }
//  }
//
//  func testNameChange() throws {
//    try withNewContext(ActiveSchema.self) { context in
//      var fonts = try SoundFontModel.tagged(with: TagModel.Ubiquitous.builtIn.key)
//      let preset = fonts[0].orderedPresets[0]
//      preset.displayName = "My New Name"
//      try context.save()
//
//      fonts = try SoundFontModel.tagged(with: TagModel.Ubiquitous.builtIn.key)
//      XCTAssertEqual(fonts[0].orderedPresets[0].displayName, "My New Name")
//    }
//  }
//
//  func testDeletingPresetCascades() async throws {
//    try withNewContext(ActiveSchema.self, addBuiltInFonts: false) { context in
//      _ = try SoundFontModel.add(resourceTag: .freeFont)
//      try context.save()
//
//      var found = try context.fetch(SoundFontModel.fetchDescriptor())
//      XCTAssertEqual(found.count, 1)
//      XCTAssertEqual(found[0].presets.count, 235)
//
//      let fav1 = try FavoriteModel.create(preset: found[0].orderedPresets[0])
//      XCTAssertEqual(fav1.basis, found[0].orderedPresets[0])
//
//      let fav2 = try FavoriteModel.create(preset: found[0].orderedPresets[0])
//      XCTAssertEqual(fav2.basis, found[0].orderedPresets[0])
//
//      let aus = AudioSettingsModel()
//      found[0].orderedPresets[0].audioSettings = aus
//      try context.save()
//
//      XCTAssertEqual(try context.fetch(AudioSettingsModel.fetchDescriptor()).count, 1)
//      XCTAssertEqual(try context.fetch(FavoriteModel.fetchDescriptor()).count, 2)
//      XCTAssertEqual(try context.fetch(PresetModel.fetchDescriptor(predicate: #Predicate { $0.favorites.count > 0 })).count, 1)
//
//      context.delete(found[0])
//      try context.save()
//
//      found = try context.fetch(SoundFontModel.fetchDescriptor())
//      XCTAssertEqual(found.count, 0)
//
//      XCTAssertEqual(try context.fetch(PresetModel.fetchDescriptor(predicate: #Predicate { $0.favorites.count > 0 })).count, 0)
//      XCTAssertEqual(try context.fetch(FavoriteModel.fetchDescriptor()).count, 0)
//      XCTAssertEqual(try context.fetch(AudioSettingsModel.fetchDescriptor()).count, 0)
//    }
//  }
//}
