import Dependencies
import Foundation
import GRDB
import SF2ResourceFiles
import Testing

@testable import Models

@Suite("Favorite") struct FavoriteTests {

  @Test("migration") func migration() async throws {
    let (db, presets) = try await setup()
    let all = try await db.read { try Favorite.fetchAll($0) }
    #expect(all.isEmpty)
    let forPreset = try await db.read { try presets[0].favorites.fetchAll($0) }
    #expect(forPreset.isEmpty)
  }

  @Test("create") func create() async throws {
    let (db, presets) = try await setup()
    let preset = presets[0]
    let favorite = try await db.write { try Favorite.make($0, preset: preset) }
    #expect(favorite.displayName == preset.displayName)
    let forPreset = try await db.read { try preset.favorites.fetchAll($0) }
    #expect(forPreset.count == 1)
  }

  @Test("create multiple") func createMultiple() async throws {
    let (db, presets) = try await setup()
    let preset = presets[0]
    _ = try await db.write { try Favorite.make($0, preset: preset) }
    _ = try await db.write { try Favorite.make($0, preset: preset) }
    _ = try await db.write { try Favorite.make($0, preset: preset) }
    let forPreset = try await db.read { try preset.favorites.fetchAll($0) }
    #expect(forPreset.count == 3)
  }

  @Test("inherit configs") func inheritConfigs() async throws {
    let (db, presets) = try await setup()
    let preset = presets[0]
    _ = try await db.write {
      var ac = try AudioConfig.make($0, presetId: preset.id)
      ac.gain = 0.2
      try ac.update($0)
      var rc = try ReverbConfig.make($0, for: ac.id)
      rc.preset = 3
      try rc.update($0)
      return ac
    }

    let favorite = try await db.write { return try Favorite.make($0, preset: preset) }
    let presetAudioConfig = try await db.read { try preset.audioConfig.fetchOne($0)}
    let favoriteAudioConfig = try await db.read { try favorite.audioConfig.fetchOne($0) }
    #expect(presetAudioConfig != nil)
    #expect(favoriteAudioConfig != nil)
    #expect(favoriteAudioConfig?.id != presetAudioConfig?.id)
    #expect(favoriteAudioConfig?.gain == 0.2)

    let dc = try await db.read { try favoriteAudioConfig?.delayConfig.fetchOne($0) }
    #expect(dc == nil)
    let rc = try await db.read { try favoriteAudioConfig?.reverbConfig.fetchOne($0) }
    #expect(rc != nil)
    #expect(rc?.preset == 3)
  }

  private func setup() async throws -> (DatabaseQueue, [Preset]) {
    let db = try await setupDatabase()
    let presets = try await db.read { try Preset.fetchAll($0) }
    return (db, presets)
  }
}

private func setupDatabase() async throws -> DatabaseQueue {
  let db = try DatabaseQueue.appDatabase()
  let tag = SF2ResourceFileTag.freeFont
  try await db.write {
    _ = try SoundFont.make(
      $0,
      displayName: tag.name,
      location: Location(kind: .builtin, url: tag.url, raw: nil)
    )
  }

  return db
}

//import XCTest
//import Dependencies
//import SwiftData
//
//@testable import Models
//
//final class FavoriteTests: XCTestCase {
//  typealias ActiveSchema = SchemaV1
//
//  func testEmpty() throws {
//    try withNewContext(ActiveSchema.self) { context in
//      let found = try context.fetch(FetchDescriptor<FavoriteModel>())
//      XCTAssertTrue(found.isEmpty)
//    }
//  }
//
//  func testCreateNewFavorite() throws {
//    try withNewContext(ActiveSchema.self) { context in
//      let found = try context.fetch(FetchDescriptor<FavoriteModel>())
//      XCTAssertTrue(found.isEmpty)
//
//      let font = try SoundFontModel.tagged(with: TagModel.Ubiquitous.all.key)[0]
//      let preset = font.orderedPresets[0]
//      let fav1 = try FavoriteModel.create(preset: preset)
//      XCTAssertEqual(fav1.basis, preset)
//      XCTAssertEqual(fav1.displayName, preset.displayName + " - 1")
//
//      let fav2 = try FavoriteModel.create(preset: preset)
//      XCTAssertEqual(fav2.basis, preset)
//      XCTAssertEqual(fav2.displayName, preset.displayName + " - 2")
//    }
//  }
//
//  func testChangeFavoriteName() throws {
//    try withNewContext(ActiveSchema.self) { context in
//      let found = try context.fetch(FetchDescriptor<FavoriteModel>())
//      XCTAssertTrue(found.isEmpty)
//
//      let font = try SoundFontModel.tagged(with: TagModel.Ubiquitous.all.key)[0]
//      let preset = font.orderedPresets[0]
//      let fav1 = try FavoriteModel.create(preset: preset)
//
//      var fetched = try context.fetch(FetchDescriptor<FavoriteModel>())
//      XCTAssertEqual(fetched[0].displayName, fav1.displayName)
//      fav1.displayName = "My new name"
//      try context.save()
//
//      fetched = try context.fetch(FetchDescriptor<FavoriteModel>())
//      XCTAssertEqual(fetched[0].displayName, "My new name")
//    }
//  }
//
//  func testAudioSettingsCopyOnWrite() throws {
//    try withNewContext(ActiveSchema.self) { context in
//      let found = try context.fetch(FetchDescriptor<FavoriteModel>())
//      XCTAssertTrue(found.isEmpty)
//
//      let font = try SoundFontModel.tagged(with: TagModel.Ubiquitous.all.key)[0]
//      let preset = font.orderedPresets[0]
//      preset.audioSettings = AudioSettingsModel()
//      preset.audioSettings?.addOverride(zone: 1, generator: 23, value: 1.0)
//      XCTAssertEqual(preset.audioSettings?.override(zone: 1, generator: 23), 1.0)
//
//      try context.save()
//
//      let fav = try FavoriteModel.create(preset: preset)
//
//      let fetched = try context.fetch(FetchDescriptor<FavoriteModel>())
//      XCTAssertEqual(fetched[0].displayName, fav.displayName)
//
//      XCTAssertNotNil(fav.audioSettings)
//      fav.audioSettings?.addOverride(zone: 1, generator: 23, value: 0.25)
//      try context.save()
//      XCTAssertEqual(fav.audioSettings?.override(zone: 1, generator: 23), 0.25)
//
//      XCTAssertEqual(preset.audioSettings?.override(zone: 1, generator: 23), 1.0)
//
//      preset.audioSettings?.removeAllOverrides()
//      try context.save()
//
//      XCTAssertEqual(fav.audioSettings?.override(zone: 1, generator: 23), 0.25)
//    }
//  }
//
//  func testDeleteFavoriteCascades() throws {
//    try withNewContext(ActiveSchema.self) { context in
//      let font = try SoundFontModel.tagged(with: TagModel.Ubiquitous.all.key)[0]
//      let preset = font.orderedPresets[0]
//      let fav = try FavoriteModel.create(preset: preset)
//      fav.audioSettings = AudioSettingsModel()
//      fav.audioSettings?.delayConfig = DelayConfigModel()
//      fav.audioSettings?.reverbConfig = ReverbConfigModel()
//      try context.save()
//
//      var fetched = try context.fetch(FetchDescriptor<FavoriteModel>())
//      XCTAssertNotNil(fetched[0].basis)
//      XCTAssertEqual(fetched[0].basis.favorites.count, 1)
//      XCTAssertFalse(try context.fetch(FetchDescriptor<AudioSettingsModel>()).isEmpty)
//      XCTAssertFalse(try context.fetch(FetchDescriptor<DelayConfigModel>()).isEmpty)
//
//      try fav.delete()
//
//      fetched = try context.fetch(FetchDescriptor<FavoriteModel>())
//      XCTAssertTrue(fetched.isEmpty)
//      XCTAssertTrue(try context.fetch(FetchDescriptor<AudioSettingsModel>()).isEmpty)
//      XCTAssertTrue(try context.fetch(FetchDescriptor<DelayConfigModel>()).isEmpty)
//
//      XCTAssertTrue(preset.favorites.isEmpty)
//    }
//  }
//
//  func testFetchOrderedFavorites() throws {
//    try withNewContext(ActiveSchema.self) { context in
//      let found = try context.fetch(FetchDescriptor<FavoriteModel>())
//      XCTAssertTrue(found.isEmpty)
//
//      let font = try SoundFontModel.tagged(with: TagModel.Ubiquitous.all.key)[0]
//      let preset = font.orderedPresets[0]
//      let fav1 = try FavoriteModel.create(preset: preset)
//      let fav2 = try FavoriteModel.create(preset: preset)
//      let fav3 = try FavoriteModel.create(preset: preset)
//
//      fav2.displayName = "All good"
//      fav1.displayName = "Zero Effort"
//      try context.save()
//
//      let ordered = preset.orderedFavorites
//      XCTAssertEqual(ordered.count, 3)
//      XCTAssertEqual(ordered[0].displayName, "All good")
//      XCTAssertEqual(ordered[1].displayName, fav3.displayName)
//      XCTAssertEqual(ordered[2].displayName, "Zero Effort")
//    }
//  }
//  //}
//}
