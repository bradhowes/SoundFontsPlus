//import XCTest
//import AVFoundation
//import Dependencies
//import SwiftData
//
//@testable import Models
//
//
//final class AudioSettingsModelTests: XCTestCase {
//
//  func makeMockAudioSettings(context: ModelContext) throws -> AudioSettingsModel {
//    let entry = AudioSettingsModel()
//    context.insert(entry)
//    try context.save()
//    return entry
//  }
//
//  func testCreateNew() throws {
//    try withNewContext(ActiveSchema.self) { context in
//      let entry = try makeMockAudioSettings(context: context)
//      XCTAssertNil(entry.keyboardLowestNote)
//      XCTAssertFalse(entry.keyboardLowestNoteEnabled)
//      XCTAssertNil(entry.pitchBendRange)
//      XCTAssertEqual(entry.gain, 1.0)
//      XCTAssertEqual(entry.pan, 0.0)
//      XCTAssertEqual(entry.presetTuning, 0.0)
//      XCTAssertNil(entry.presetTranspose)
//      XCTAssertNil(entry.overrides)
//      XCTAssertNil(entry.reverbConfig)
//      XCTAssertNil(entry.delayConfig)
//    }
//  }
//
//  func testDeleteCascades() throws {
//    try withNewContext(ActiveSchema.self) { context in
//      let entry = try makeMockAudioSettings(context: context)
//
//      entry.addOverride(zone: 0, generator: 12, value: 3.45)
//      entry.addOverride(zone: -1, generator: 24, value: -3.45)
//      entry.addOverride(zone: .globalZone, generator: 25, value: 9.87)
//
//      let delayConfig = DelayConfigModel()
//      entry.delayConfig = delayConfig
//
//      let reverbConfig = ReverbConfigModel()
//      entry.reverbConfig = reverbConfig
//
//      try context.save()
//
//      XCTAssertFalse(try context.fetch(FetchDescriptor<AudioSettingsModel>()).isEmpty)
//      XCTAssertFalse(try context.fetch(FetchDescriptor<DelayConfigModel>()).isEmpty)
//      XCTAssertFalse(try context.fetch(FetchDescriptor<ReverbConfigModel>()).isEmpty)
//
//      context.delete(entry)
//      try context.save()
//
//      XCTAssertTrue(try context.fetch(FetchDescriptor<AudioSettingsModel>()).isEmpty)
//      XCTAssertTrue(try context.fetch(FetchDescriptor<DelayConfigModel>()).isEmpty)
//      XCTAssertTrue(try context.fetch(FetchDescriptor<ReverbConfigModel>()).isEmpty)
//    }
//  }
//
//  func testDuplication() throws {
//    try withNewContext(ActiveSchema.self) { context in
//      let entry = try makeMockAudioSettings(context: context)
//      let dupe1 = try entry.duplicate()
//      XCTAssertNil(dupe1.delayConfig)
//      XCTAssertNil(dupe1.reverbConfig)
//
//      entry.delayConfig = DelayConfigModel()
//      entry.reverbConfig = ReverbConfigModel()
//
//      let dupe2 = try entry.duplicate()
//      XCTAssertNotNil(dupe2.delayConfig)
//      XCTAssertNotNil(dupe2.reverbConfig)
//    }
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
//
//  func testAddDelayConfig() throws {
//    try withNewContext(ActiveSchema.self) { context in
//      let entry = try makeMockAudioSettings(context: context)
//      let delayConfig = DelayConfigModel()
//      context.insert(delayConfig)
//
//      delayConfig.time = 1.2
//      delayConfig.feedback = 3.4
//      delayConfig.cutoff = 5.6
//      delayConfig.wetDryMix = 0.78
//      entry.delayConfig = delayConfig
//
//      XCTAssertEqual(entry.delayConfig!.time, AUValue(1.2), accuracy: 0.001)
//      XCTAssertEqual(entry.delayConfig!.feedback, AUValue(3.4), accuracy: 0.001)
//      XCTAssertEqual(entry.delayConfig!.cutoff, AUValue(5.6), accuracy: 0.001)
//      XCTAssertEqual(entry.delayConfig!.wetDryMix, AUValue(0.78), accuracy: 0.001)
//      try context.save()
//
//      let found = try context.fetch(FetchDescriptor<AudioSettingsModel>())[0]
//      XCTAssertEqual(found.delayConfig!.time, AUValue(1.2), accuracy: 0.001)
//      XCTAssertEqual(found.delayConfig!.feedback, AUValue(3.4), accuracy: 0.001)
//      XCTAssertEqual(found.delayConfig!.cutoff, AUValue(5.6), accuracy: 0.001)
//      XCTAssertEqual(found.delayConfig!.wetDryMix, AUValue(0.78), accuracy: 0.001)
//    }
//  }
//
//  func testCascadeDeleteDelayConfig() throws {
//    try withNewContext(ActiveSchema.self) { context in
//      let entry = try makeMockAudioSettings(context: context)
//      XCTAssertEqual(try context.fetch(FetchDescriptor<DelayConfigModel>()).count, 0)
//
//      let delayConfig = DelayConfigModel()
//      context.insert(delayConfig)
//
//      delayConfig.time = 1.2
//      delayConfig.feedback = 3.4
//      delayConfig.cutoff = 5.6
//      delayConfig.wetDryMix = 0.78
//      entry.delayConfig = delayConfig
//
//      try context.save()
//      XCTAssertEqual(try context.fetch(FetchDescriptor<DelayConfigModel>()).count, 1)
//
//      let found = try context.fetch(FetchDescriptor<AudioSettingsModel>())[0]
//      XCTAssertEqual(found.delayConfig, delayConfig)
//      context.delete(found)
//      try context.save()
//
//      XCTAssertEqual(try context.fetch(FetchDescriptor<DelayConfigModel>()).count, 0)
//    }
//  }
//
//  func testAddReverbConfig() throws {
//    try withNewContext(ActiveSchema.self) { context in
//      let entry = try makeMockAudioSettings(context: context)
//      let reverbConfig = ReverbConfigModel()
//      context.insert(reverbConfig)
//
//      reverbConfig.preset = 1
//      reverbConfig.wetDryMix = 0.78
//      entry.reverbConfig = reverbConfig
//
//      try context.save()
//      XCTAssertEqual(entry.reverbConfig?.preset, 1)
//      XCTAssertEqual(entry.reverbConfig?.wetDryMix ?? -1.0, AUValue(0.78), accuracy: 0.001)
//      try context.save()
//
//      let found = try context.fetch(FetchDescriptor<AudioSettingsModel>())[0]
//      XCTAssertEqual(found.reverbConfig!.preset, 1)
//      XCTAssertEqual(found.reverbConfig!.wetDryMix, AUValue(0.78), accuracy: 0.001)
//    }
//  }
//
//  func testCascadeDeleteReverbConfig() throws {
//    try withNewContext(ActiveSchema.self) { context in
//      let entry = try makeMockAudioSettings(context: context)
//      let reverbConfig = ReverbConfigModel()
//      context.insert(reverbConfig)
//
//      reverbConfig.preset = 1
//      reverbConfig.wetDryMix = 0.78
//      entry.reverbConfig = reverbConfig
//
//      try context.save()
//      XCTAssertEqual(try context.fetch(FetchDescriptor<ReverbConfigModel>()).count, 1)
//
//      let found = try context.fetch(FetchDescriptor<AudioSettingsModel>())[0]
//      XCTAssertEqual(found.reverbConfig, reverbConfig)
//      context.delete(found)
//      try context.save()
//
//      XCTAssertEqual(try context.fetch(FetchDescriptor<ReverbConfigModel>()).count, 0)
//    }
//  }
//}
