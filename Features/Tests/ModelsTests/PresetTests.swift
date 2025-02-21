import Dependencies
import Foundation
import GRDB
import SF2ResourceFiles
import Testing

@testable import Models

@Suite("Preset") struct PresetTests {

  @Test("migration") func migration() async throws {
    let db = try await setupDatabase()
    let presets = try await db.read { try Preset.fetchAll($0) }
    #expect(presets.count == 506)
  }

  @Test("adding audioConfig") func addingAudioConfig() async throws {
    let db = try await setupDatabase()
    let presets = try await db.read { try Preset.fetchAll($0) }
    #expect(presets.isEmpty == false)

    let preset = presets[0]
    _ = try await db.write { try AudioConfig.make($0, presetId: preset.id) }
    let audioConfig = try await db.read { try preset.audioConfig.fetchOne($0) }
    #expect(audioConfig != nil)
  }

  @Test("cascade") func cascade() async throws {
    let (db, presets)  = try await setup()
    #expect(presets.isEmpty != true)
    let preset = presets[0]

    try await db.write {
      try AudioConfig.make($0, presetId: preset.id)
      let favorite = try Favorite.make($0, preset: preset)
      try AudioConfig.make($0, favoriteId: favorite.id)
    }

    let result = try await db.write { try preset.delete($0) }
    #expect(result == true)

    var found = try await db.read { try AudioConfig.fetchCount($0) }
    found += try await db.read { try Favorite.fetchCount($0) }
  }

  private func setup() async throws -> (DatabaseQueue, [Preset]) {
    let db = try await setupDatabase()
    let presets = try await db.read { try Preset.fetchAll($0) }
    return (db, presets)
  }
}

private func setupDatabase() async throws -> DatabaseQueue {
  let db = try DatabaseQueue.appDatabase()
  for tag in SF2ResourceFileTag.allCases {
    try await db.write {
      _  = try SoundFont.make(
        $0,
        displayName: tag.name,
        location: Location(kind: .builtin, url: tag.url, raw: nil)
      )
    }
  }

  return db
}
