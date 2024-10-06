//import XCTest
//import AVFoundation
//import SwiftData
//
//@testable import Models
//
//
//final class AudioSettingsModelTests: XCTestCase {
//  var container: ModelContainer!
//  var context: ModelContext!
//
//  override func setUp() async throws {
//    container = try ModelContainer(
//      for: AudioSettingsModel.self,
//      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
//    )
//    context = .init(container)
//  }
//
//  var fetched: [AudioSettingsModel] {
//    (try? context.fetch(FetchDescriptor<AudioSettingsModel>())) ?? []
//  }
//
//  func makeMockAudioSettings() throws -> AudioSettingsModel {
//    let audioSettings = AudioSettingsModel()
//    context.insert(audioSettings)
//    try context.save()
//    return audioSettings
//  }
//
//  func testEmpty() throws {
//    XCTAssertTrue(fetched.isEmpty)
//  }
//
//  func testCreateNew() throws {
//    let entry = try makeMockAudioSettings()
//    XCTAssertNil(entry.keyboardLowestNote)
//    XCTAssertFalse(entry.keyboardLowestNoteEnabled)
//    XCTAssertNil(entry.pitchBendRange)
//    XCTAssertEqual(entry.gain, 0.0)
//    XCTAssertEqual(entry.pan, 0.0)
//    XCTAssertEqual(entry.presetTuning, 0.0)
//    XCTAssertNil(entry.presetTranspose)
//    XCTAssertNil(entry.overrides)
//    XCTAssertNil(entry.reverbConfig)
//    XCTAssertNil(entry.delayConfig)
//    let found = fetched
//    XCTAssertEqual(found.count, 1)
//  }
//
//  func testDeleteCascades() throws {
//    let entry = try makeMockAudioSettings()
//    entry.addOverride(to: 0, generator: 12, value: 3.45)
//    entry.addOverride(to: -1, generator: 24, value: -3.45)
//    entry.addOverride(to: .globalZone, generator: 25, value: 9.87)
//
//    let delayConfig = DelayConfigModel()
//    entry.delayConfig = delayConfig
//
//    let reverbConfig = ReverbConfigModel()
//    entry.reverbConfig = reverbConfig
//    try context.save()
//
//    XCTAssertFalse(fetched.isEmpty)
//    XCTAssertFalse(try context.fetch(FetchDescriptor<DelayConfigModel>()).isEmpty)
//    XCTAssertFalse(try context.fetch(FetchDescriptor<ReverbConfigModel>()).isEmpty)
//
//    context.delete(entry)
//    try context.save()
//
//    XCTAssertTrue(fetched.isEmpty)
//    XCTAssertTrue(try context.fetch(FetchDescriptor<DelayConfigModel>()).isEmpty)
//    XCTAssertTrue(try context.fetch(FetchDescriptor<ReverbConfigModel>()).isEmpty)
//  }
//
//  func testAddGeneratorOverrides() throws {
//    let entry = try makeMockAudioSettings()
//    entry.addOverride(to: 0, generator: 12, value: 3.45)
//    entry.addOverride(to: -1, generator: 24, value: -3.45)
//    entry.addOverride(to: .globalZone, generator: 25, value: 9.87)
//    try context.save()
//    let found = fetched
//    XCTAssertEqual(found.count, 1)
//    XCTAssertEqual(found[0].overrides?.count, 2)
//    XCTAssertEqual(found[0].overrides?[0]?.count, 1)
//    XCTAssertEqual(found[0].overrides?[.globalZone]?.count, 2)
//    XCTAssertEqual(found[0].overrides?[-1]?.count, 2)
//  }
//
//  func testRemoveGeneratorOverrides() throws {
//    let entry = try makeMockAudioSettings()
//    entry.addOverride(to: 0, generator: 12, value: 3.45)
//    entry.addOverride(to: .globalZone, generator: 24, value: -3.45)
//    entry.addOverride(to: .globalZone, generator: 25, value: 9.87)
//    try context.save()
//    var found = fetched[0]
//    found.removeOverride(from: 0, generator: 12)
//    try context.save()
//    found = fetched[0]
//    XCTAssertEqual(found.overrides.count, 1)
//    found.removeAllOverrides(from: .globalZone)
//    try context.save()
//    found = fetched[0]
//    XCTAssertEqual(found.overrides.count, 0)
//  }
//
//  func testAddDelayConfig() throws {
//    let entry = try makeMockAudioSettings()
//    let delayConfig = DelayConfig()
//    delayConfig.time = 1.2
//    delayConfig.feedback = 3.4
//    delayConfig.cutoff = 5.6
//    delayConfig.wetDryMix = 0.78
//    entry.delayConfig = delayConfig
//
//    XCTAssertEqual(entry.delayConfig!.time, AUValue(1.2), accuracy: 0.001)
//    XCTAssertEqual(entry.delayConfig!.feedback, AUValue(3.4), accuracy: 0.001)
//    XCTAssertEqual(entry.delayConfig!.cutoff, AUValue(5.6), accuracy: 0.001)
//    XCTAssertEqual(entry.delayConfig!.wetDryMix, AUValue(0.78), accuracy: 0.001)
//    try context.save()
//    let found = fetched[0]
//    XCTAssertEqual(found.delayConfig!.time, AUValue(1.2), accuracy: 0.001)
//    XCTAssertEqual(found.delayConfig!.feedback, AUValue(3.4), accuracy: 0.001)
//    XCTAssertEqual(found.delayConfig!.cutoff, AUValue(5.6), accuracy: 0.001)
//    XCTAssertEqual(found.delayConfig!.wetDryMix, AUValue(0.78), accuracy: 0.001)
//  }
//
//  func testRemoveDelayConfig() throws {
//    let entry = try makeMockAudioSettings()
//    let delayConfig = DelayConfig()
//    delayConfig.time = 1.2
//    delayConfig.feedback = 3.4
//    delayConfig.cutoff = 5.6
//    delayConfig.wetDryMix = 0.78
//    entry.delayConfig = delayConfig
//
//    try context.save()
//    XCTAssertEqual(try context.fetch(FetchDescriptor<DelayConfig>()).count, 1)
//
//    var found = fetched[0]
//    found.delayConfig = nil
//    try context.save()
//
//    found = fetched[0]
//    XCTAssertNil(found.delayConfig)
//    XCTAssertEqual(try context.fetch(FetchDescriptor<DelayConfig>()).count, 1)
//  }
//
//  func testAddReverbConfig() throws {
//    let entry = try makeMockAudioSettings()
//    let reverbConfig = ReverbConfig()
//    reverbConfig.preset = 1
//    reverbConfig.wetDryMix = 0.78
//    entry.reverbConfig = reverbConfig
//
//    XCTAssertEqual(entry.reverbConfig!.preset, 1)
//    XCTAssertEqual(entry.reverbConfig!.wetDryMix, AUValue(0.78), accuracy: 0.001)
//    try context.save()
//    let found = fetched[0]
//    XCTAssertEqual(found.reverbConfig!.preset, 1)
//    XCTAssertEqual(found.reverbConfig!.wetDryMix, AUValue(0.78), accuracy: 0.001)
//  }
//
//  func testRemoveReverbConfig() throws {
//    let entry = try makeMockAudioSettings()
//    let reverbConfig = ReverbConfig()
//    reverbConfig.preset = 1
//    reverbConfig.wetDryMix = 0.78
//    entry.reverbConfig = reverbConfig
//
//    try context.save()
//    XCTAssertEqual(try context.fetch(FetchDescriptor<ReverbConfig>()).count, 1)
//
//    var found = fetched[0]
//    found.reverbConfig = nil
//    try context.save()
//
//    found = fetched[0]
//    XCTAssertNil(found.reverbConfig)
//    XCTAssertEqual(try context.fetch(FetchDescriptor<ReverbConfig>()).count, 1)
//  }
//}
