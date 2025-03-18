import Dependencies
import Foundation
import GRDB
import SF2ResourceFiles
import Testing

@testable import Models

@Suite("Preset") struct PresetTests {

  @Test("migration") func migration() async throws {
    try await withDependencies {
      $0.defaultDatabase = try DatabaseQueue.appDatabase(addMocks: true)
    } operation: {
      @Dependency(\.defaultDatabase) var db
      let presets = try await db.read { try Preset.fetchAll($0) }
      #expect(presets.count == 506)
    }
  }

  @Test("adding audioConfig") func addingAudioConfig() async throws {
    try await withDependencies {
      $0.defaultDatabase = try DatabaseQueue.appDatabase(addMocks: true)
    } operation: {
      @Dependency(\.defaultDatabase) var db
      let presets = try await db.read { try Preset.fetchAll($0) }
      let preset = presets[0]
      _ = try await db.write { try AudioConfig.make($0, presetId: preset.id) }
      let audioConfig = try await db.read { try preset.audioConfig.fetchOne($0) }
      #expect(audioConfig != nil)
    }
  }

  @Test("cascade") func cascade() async throws {
    try await withDependencies {
      $0.defaultDatabase = try DatabaseQueue.appDatabase(addMocks: true)
    } operation: {
      @Dependency(\.defaultDatabase) var db
      let presets = try await db.read { try Preset.fetchAll($0) }
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
      #expect(found == 0)
    }
  }

  @Test("mock") func mock() async throws {
    try await withDependencies {
      $0.defaultDatabase = try DatabaseQueue.appDatabase()
    } operation: {
      @Dependency(\.defaultDatabase) var db
      let mock = try await db.write {
        try SoundFont.mock($0, name: "SoundFont 1", presetNames: ["Preset 1", "Preset 2", "Preset 3"], tags: [])
      }
      #expect(mock.displayName == "SoundFont 1")
    }
  }
}
