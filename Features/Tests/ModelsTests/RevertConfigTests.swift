import Dependencies
import Foundation
import GRDB
import SF2ResourceFiles
import Testing

@testable import Models

@Suite("ReverbConfig") struct ReverbConfigTests {

  @Test("new") func createNew() async throws {
    let (_, _, reverbConfig) = try await setup()
    #expect(reverbConfig.preset == 0)
    #expect(reverbConfig.wetDryMix == 0.5)
    #expect(reverbConfig.enabled == true)
  }

  @Test("updating") func updating() async throws {
    let (db, _, reverbConfig) = try await setup()
    try await db.write {
      var reverbConfig = reverbConfig
      try reverbConfig.updateChanges($0) { rc in
        rc.preset = 1
        rc.wetDryMix = 0.2
        rc.enabled = false
      }
    }

    let check = try await db.read { try ReverbConfig.fetchOne($0, key: reverbConfig.id) }
    #expect(check != nil)
    #expect(check?.preset == 1)
    #expect(check?.wetDryMix == 0.2)
    #expect(check?.enabled == false)
  }

  @Test("duplicate") func duplicate() async throws {
    let (db, presets, reverbConfig) = try await setup()

    let parent = try await db.read { try reverbConfig.audioConfig.fetchOne($0) }
    #expect(parent != nil)

    let dupParent = try await db.write { try parent?.duplicate($0, presetId: presets[1].id) }
    #expect(dupParent != nil)

    let dup = try await db.read { try dupParent?.reverbConfig.fetchOne($0) }
    #expect(dup != nil)

    #expect(dup != nil)
    #expect(dup?.id != reverbConfig.id)
  }

  @Test("cascade") func cascade() async throws {
    let (db, _, reverbConfig) = try await setup()
    let parent = try await db.read { try reverbConfig.audioConfig.fetchOne($0) }
    #expect(parent != nil)
    let result = try await db.write { try parent?.delete($0) }
    #expect(result == true)
    let dc = try await db.read { try ReverbConfig.fetchAll($0) }
    #expect(dc.isEmpty)
  }

  private func setup() async throws -> (DatabaseQueue, [Preset], ReverbConfig) {
    let db = try await setupDatabase()
    let presets = try await db.read { try Preset.fetchAll($0) }
    let rc = try await db.write { db in
      let ac = try AudioConfig.make(db, presetId: presets[0].id)
      return try ReverbConfig.make(db, for: ac.id)
    }
    return (db, presets, rc)
  }
}

private func setupDatabase() async throws -> DatabaseQueue {
  let db = try DatabaseQueue.appDatabase()
  let tag = SF2ResourceFileTag.freeFont
  try await db.write {
    _  = try SoundFont.make(
      $0,
      displayName: tag.name,
      location: Location(kind: .builtin, url: tag.url, raw: nil)
    )
  }
  return db
}
