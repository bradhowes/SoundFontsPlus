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
    let favoritePreset = try await db.read { try favorite.preset.fetchOne($0) }
    #expect(favoritePreset?.id == preset.id)
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
    let db = try DatabaseQueue.appDatabase()
    let presets = try await db.read { try Preset.fetchAll($0) }
    return (db, presets)
  }
}
