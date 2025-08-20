import Dependencies
import Foundation
import GRDB
import Testing

@testable import SoundFontsPlus

//@Suite("AudioConfig", .dependencies { $0.defaultDatabase = try appDatabase() })
//struct AudioConfigTests {
//
//  func setup() async throws -> ([Preset], AudioConfig) {
//    @Dependency(\.defaultDatabase) var database
//    let presets = try await database.read { try Preset.all.fetchAll($0) }
//    let audioConfig = withDatabaseWriter { db in
//      try AudioConfig.upsert {
//        presets[0].audioConfigDraft
//      }
//      .returning(\.self)
//      .fetchOneForced(db)
//    }
//
//    return (presets, audioConfig!)
//  }
//
//  @Test("new") func createNew() async throws {
//    let (_, audioConfig) = try await setup()
//    #expect(audioConfig.gain == 1.0)
//    #expect(audioConfig.pan == 0.0)
//    #expect(audioConfig.keyboardLowestNoteEnabled == false)
//    #expect(audioConfig.keyboardLowestNote == nil)
//    #expect(audioConfig.pitchBendRange == nil)
//    #expect(audioConfig.presetTuning == nil)
//    #expect(audioConfig.presetTranspose == nil)
//  }

//  @Test("updating") func updating() async throws {
//    let (db, _, audioConfigs) = try await setup()
//    let audioConfig = audioConfigs[0]
//    try await db.write {
//      var audioConfig = audioConfig
//      try audioConfig.updateChanges($0) { rc in
//        rc.gain = 0.5
//        rc.pan = -1.0
//        rc.keyboardLowestNoteEnabled = true
//      }
//    }
//
//    let check = try await db.read { try AudioConfig.fetchOne($0, key: audioConfig.id) }
//    #expect(check != nil)
//    #expect(check?.gain == 0.5)
//    #expect(check?.pan == -1.0)
//    #expect(check?.keyboardLowestNoteEnabled == true)
//  }
//
//  @Test("duplicate") func duplicate() async throws {
//    let (db, presets, _) = try await setup()
//
//    let acs = try await db.read { try AudioConfig.fetchAll($0) }
//    #expect(acs.count == 4)
//
//    for each in acs.enumerated() {
//      let dc0 = try await db.read { try each.1.delayConfig.fetchOne($0) }
//      let rc0 = try await db.read { try each.1.reverbConfig.fetchOne($0) }
//
//      let dup = try await db.write {
//        var tmp = each.1
//        tmp.gain = 0.8
//        tmp.pan = 1.0
//        tmp.keyboardLowestNoteEnabled = true
//        return try tmp.duplicate($0, presetId: presets[each.0 + 4].id)
//      }
//
//      #expect(dup.id != each.1.id)
//      #expect(dup.gain == 0.8)
//      #expect(dup.pan == 1.0)
//      #expect(dup.keyboardLowestNoteEnabled)
//
//      let dc = try await db.read { try dup.delayConfig.fetchOne($0) }
//      if each.0 == 1 || each.0 == 3 {
//        #expect(dc != nil)
//        #expect(dc0 != nil)
//        #expect(dc?.id != dc0?.id)
//      } else {
//        #expect(dc == nil)
//        #expect(dc0 == nil)
//      }
//
//      let rc = try await db.read { try dup.reverbConfig.fetchOne($0) }
//      if each.0 == 2 || each.0 == 3 {
//        #expect(rc != nil)
//        #expect(rc0 != nil)
//        #expect(rc?.id != rc0?.id)
//      } else {
//        #expect(rc == nil)
//        #expect(rc0 == nil)
//      }
//    }
//  }
//
//  @Test("delete cascades") func deleteCascades() async throws {
//    let (db, _, audioConfigs) = try await setup()
//    #expect(audioConfigs.count == 4)
//
//    for each in audioConfigs.enumerated() {
//      let deleted = try await db.write { try each.1.delete($0) }
//      #expect(deleted == true)
//    }
//
//    let dc = try await db.read { try DelayConfig.fetchAll($0) }
//    #expect(dc.count == 0)
//    let rc = try await db.read { try ReverbConfig.fetchAll($0) }
//    #expect(rc.count == 0)
//  }
//
//  func testAddGeneratorOverrides() throws {
//    try withNewContext(ActiveSchema.self) { context in
//      let entry = try makeMockAudioSettings(context: context)
//      entry.addOverride(zone: 0, generator: 12, value: 3.45)
//      entry.addOverride(zone: -1, generator: 24, value: -3.45)
//      entry.addOverride(zone: .globalZone, generator: 25, value: 9.87)
//      try context.save()
//
//      let found = try context.fetch(FetchDescriptor<AudioSettingsModel>())
//      XCTAssertEqual(found.count, 1)
//      XCTAssertEqual(found[0].overrides?.count, 2)
//      XCTAssertEqual(found[0].overrides?[0]?.count, 2)
//      XCTAssertEqual(found[0].overrides?[.globalZone]?.count, 2)
//      XCTAssertEqual(found[0].overrides?[-1]?.count, 1)
//    }
//  }
//
//  func testRemoveGeneratorOverrides() throws {
//    try withNewContext(ActiveSchema.self) { context in
//      let entry = try makeMockAudioSettings(context: context)
//
//      entry.addOverride(zone: 0, generator: 12, value: 3.45)
//      entry.addOverride(zone: 1, generator: 24, value: -3.45)
//      entry.addOverride(zone: .globalZone, generator: 25, value: 9.87)
//      try context.save()
//
//      var found = try context.fetch(FetchDescriptor<AudioSettingsModel>())[0]
//      found.removeOverride(zone: 1, generator: 24)
//      try context.save()
//
//      found = try context.fetch(FetchDescriptor<AudioSettingsModel>())[0]
//      found.removeOverride(zone: 0, generator: 12)
//      try context.save()
//
//      found = try context.fetch(FetchDescriptor<AudioSettingsModel>())[0]
//      XCTAssertEqual(found.overrides?.count, 1)
//      found.removeAllOverrides(zone: .globalZone)
//      try context.save()
//
//      found = try context.fetch(FetchDescriptor<AudioSettingsModel>())[0]
//      XCTAssertEqual(found.overrides?.count, 0)
//
//      found.removeOverride(zone: .globalZone, generator: 24)
//      found.removeAllOverrides(zone: -99)
//    }
//  }
//}
