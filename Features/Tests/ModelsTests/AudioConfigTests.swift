// Copyright © 2025 Brad Howes. All rights reserved.

import BaseSupport
import Dependencies
import Foundation
import SQLiteData
import Testing
import TestSupport

@testable import Models

@Suite(
  .dependencies {
    $0.defaultDatabase = TestSupport.testDatabase(seeder: TestSupport.addMockPresets)
  },
  //  .snapshots(record: .failed)
)
@MainActor
struct AudioConfigTests {

  @MainActor
  func setup() async throws -> ([Preset], AudioConfig) {
    let presets = withDatabaseReader { db in try Preset.all.fetchAll(db) } ?? []
    let audioConfigDraft = presets[0].audioConfigDraft
    let audioConfigs = withDatabaseWriter { db in
      try AudioConfig.upsert {
        audioConfigDraft
      }
      .returning(\.self)
      .fetchAll(db)
    }

    // swiftlint:disable:next force_unwrapping
    return (presets, audioConfigs![0])
  }

  @Test
  func createNew() async throws {
    let (_, audioConfig) = try await setup()
    #expect(audioConfig.gain == 0.0)
    #expect(audioConfig.pan == 0.0)
    #expect(audioConfig.keyboardLowestNoteEnabled == false)
    #expect(audioConfig.keyboardLowestNote == .C4)
    #expect(audioConfig.pitchBendRange == 2)
    #expect(audioConfig.customTuningEnabled == false)
    #expect(audioConfig.customTuning == 440.0)
  }

  @Test
  func with() async throws {
    let (_, audioConfig) = try await setup()
    #expect(audioConfig == AudioConfig.with(presetId: audioConfig.presetId))
    #expect(nil == AudioConfig.with(presetId: nil))
    #expect(nil == AudioConfig.with(presetId: 123123))
  }

  @Test
  func updating() async throws {
    let (_, audioConfig) = try await setup()
    let check = withDatabaseWriter { db in
      try AudioConfig.update {
        $0.id = audioConfig.id
        $0.gain = -1.0
        $0.pan = 0.25
        $0.keyboardLowestNoteEnabled = true
        $0.keyboardLowestNote = .C4.advanced(by: -15)
        $0.pitchBendRange = 1
        $0.customTuningEnabled = true
        $0.customTuning = 430.0
      }
      .where { $0.id.eq(audioConfig.id) }
      .returning(\.self)
      .fetchOne(db)
    }

    if let check {
      #expect(check != nil)
      #expect(check?.gain == -1.0)
      #expect(check?.pan == 0.25)
      #expect(check?.keyboardLowestNoteEnabled == true)
      #expect(check?.keyboardLowestNote == Note(rawValue: "A2"))
      #expect(check?.pitchBendRange == 1)
      #expect(check?.customTuningEnabled == true)
      #expect(check?.customTuning == 430.0)
    }
  }

  @Test
  func clone() async throws {
    let (_, audioConfig) = try await setup()

    let cloned = audioConfig.clone(presetId: 2)
    #expect(cloned != nil)
    #expect(cloned?.gain == 0.0)
    #expect(cloned?.pan == 0.0)
    #expect(cloned?.keyboardLowestNoteEnabled == false)
    #expect(cloned?.keyboardLowestNote == .C4)
    #expect(cloned?.pitchBendRange == 2)
    #expect(cloned?.customTuningEnabled == false)
    #expect(cloned?.customTuning == 440.0)

    #expect(AudioConfig.with(presetId: 2) == cloned)
  }

  @Test
  func deleteCascades() async throws {
    let (_, audioConfig) = try await setup()

    withDatabaseWriter { db in
      try Preset.delete()
        .where { $0.id.eq(audioConfig.presetId) }
        .execute(db)
    }

    #expect(AudioConfig.with(presetId: audioConfig.presetId) == nil)
  }

#if false

  func testAddGeneratorOverrides() throws {
    try withNewContext(ActiveSchema.self) { context in
      let entry = try makeMockAudioSettings(context: context)
      entry.addOverride(zone: 0, generator: 12, value: 3.45)
      entry.addOverride(zone: -1, generator: 24, value: -3.45)
      entry.addOverride(zone: .globalZone, generator: 25, value: 9.87)
      try context.save()

      let found = try context.fetch(FetchDescriptor<AudioSettingsModel>())
      XCTAssertEqual(found.count, 1)
      XCTAssertEqual(found[0].overrides?.count, 2)
      XCTAssertEqual(found[0].overrides?[0]?.count, 2)
      XCTAssertEqual(found[0].overrides?[.globalZone]?.count, 2)
      XCTAssertEqual(found[0].overrides?[-1]?.count, 1)
    }
  }

  func testRemoveGeneratorOverrides() throws {
    try withNewContext(ActiveSchema.self) { context in
      let entry = try makeMockAudioSettings(context: context)

      entry.addOverride(zone: 0, generator: 12, value: 3.45)
      entry.addOverride(zone: 1, generator: 24, value: -3.45)
      entry.addOverride(zone: .globalZone, generator: 25, value: 9.87)
      try context.save()

      var found = try context.fetch(FetchDescriptor<AudioSettingsModel>())[0]
      found.removeOverride(zone: 1, generator: 24)
      try context.save()

      found = try context.fetch(FetchDescriptor<AudioSettingsModel>())[0]
      found.removeOverride(zone: 0, generator: 12)
      try context.save()

      found = try context.fetch(FetchDescriptor<AudioSettingsModel>())[0]
      XCTAssertEqual(found.overrides?.count, 1)
      found.removeAllOverrides(zone: .globalZone)
      try context.save()

      found = try context.fetch(FetchDescriptor<AudioSettingsModel>())[0]
      XCTAssertEqual(found.overrides?.count, 0)

      found.removeOverride(zone: .globalZone, generator: 24)
      found.removeAllOverrides(zone: -99)
    }
  }
#endif

}
