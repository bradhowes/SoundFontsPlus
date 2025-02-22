import Dependencies
import Foundation
import GRDB
import SF2ResourceFiles
import Testing

@testable import Models

@Suite("DelayConfig") struct DelayConfigTests {

  @Test("new") func createNew() async throws {
    let (_, _, delayConfig) = try await setup()
    #expect(delayConfig.time == 0.0)
    #expect(delayConfig.feedback == 0.0)
    #expect(delayConfig.cutoff == 0.0)
    #expect(delayConfig.wetDryMix == 0.5)
    #expect(delayConfig.enabled == true)
  }

  @Test("updating") func updating() async throws {
    let (db, _, delayConfig) = try await setup()
    try await db.write {
      var delayConfig = delayConfig
      try delayConfig.updateChanges($0) { dc in
        dc.time = 0.5
        dc.feedback = 0.25
        dc.cutoff = 0.75
        dc.wetDryMix = 0.125
        dc.enabled = false
      }
    }

    let check = try await db.read { try DelayConfig.fetchOne($0, key: delayConfig.id) }
    #expect(check != nil)
    #expect(check?.time == 0.5)
    #expect(check?.feedback == 0.25)
    #expect(check?.cutoff == 0.75)
    #expect(check?.wetDryMix == 0.125)
    #expect(check?.enabled == false)
  }

  @Test("duplicate") func duplicate() async throws {
    let (db, presets, delayConfig) = try await setup()

    let parent = try await db.read { try delayConfig.audioConfig.fetchOne($0) }
    #expect(parent != nil)

    let dupParent = try await db.write { try parent?.duplicate($0, presetId: presets[1].id) }
    #expect(dupParent != nil)

    let dup = try await db.read { try dupParent?.delayConfig.fetchOne($0) }
    #expect(dup != nil)

    #expect(dup != nil)
    #expect(dup?.id != delayConfig.id)
  }

  @Test("cascade") func cascade() async throws {
    let (db, _, delayConfig) = try await setup()
    let parent = try await db.read { try delayConfig.audioConfig.fetchOne($0) }
    #expect(parent != nil)
    let result = try await db.write { try parent?.delete($0) }
    #expect(result == true)
    let dc = try await db.read { try DelayConfig.fetchAll($0) }
    #expect(dc.isEmpty)
  }

  private func setup() async throws -> (DatabaseQueue, [Preset], DelayConfig) {
    let db = try await setupDatabase()
    let presets = try await db.read { try Preset.fetchAll($0) }
    let dc = try await db.write { db in
      let ac = try AudioConfig.make(db, presetId: presets[0].id)
      return try DelayConfig.make( db, for: ac.id)
    }
    return (db, presets, dc)
  }
}
