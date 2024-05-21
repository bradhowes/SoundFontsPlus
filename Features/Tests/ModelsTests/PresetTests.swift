import XCTest
import SwiftData

@testable import Models

final class PresetTests: XCTestCase {
  var container: ModelContainer!
  var context: ModelContext!
  var soundFont: SoundFont!

  override func setUp() async throws {
    container = try ModelContainer(
      for: Preset.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    context = .init(container)
    soundFont = SoundFont(location: .init(kind: .builtin, url: nil, raw: nil), name: "Blah Blah")
    context.insert(soundFont)
    try context.save()
  }

  var fetched: [Preset] { (try? context.fetch(FetchDescriptor<Preset>())) ?? [] }

  func makeMockPreset(name: String, bank: Int, program: Int) throws -> Preset {
    let preset = Preset(owner: soundFont, index: 0, name: name)
    preset.info = PresetInfo(originalName: name, bank: bank, program: program)
    preset.favorites = [Favorite(name: "Blah", preset: preset, index: 0)]
    preset.audioSettings = AudioSettings()
    preset.audioSettings?.reverbConfig = ReverbConfig()
    preset.audioSettings?.delayConfig = DelayConfig()
    context.insert(preset)
    try context.save()
    return preset
  }

  func testEmpty() {
    XCTAssertTrue(fetched.isEmpty)
  }

  func testCreateNewPresets() throws {
    let preset = try makeMockPreset(name: "Preset", bank: 1, program: 2)
    XCTAssertEqual(preset.name, "Preset")
    let found = fetched[0]
    XCTAssertEqual(found.name, preset.name)
    _ = try makeMockPreset(name: "Preset 1", bank: 1, program: 2)
    _ = try makeMockPreset(name: "Preset 2", bank: 1, program: 2)
    _ = try makeMockPreset(name: "Preset 3", bank: 1, program: 2)
    try context.save()

    XCTAssertEqual(fetched.count, 4)
    let entry = try context.fetch(FetchDescriptor<SoundFont>())
    XCTAssertEqual(entry[0].presets.count, 4)
  }

  func testNameChange() throws {
    let preset = try makeMockPreset(name: "Preset", bank: 1, program: 2)
    var found = fetched[0]
    XCTAssertEqual(found.name, preset.name)
    found.name = "New Name"
    try context.save()
    found = fetched[0]
    XCTAssertEqual(found.name, "New Name")
    XCTAssertEqual(found.info?.originalName, "Preset")
  }

  func testDeletingPresetCascades() async throws {
    _ = try makeMockPreset(name: "Preset", bank: 1, program: 2)
    try context.save()
    let found = fetched[0]
    context.delete(found)
    try context.save()

    XCTAssertTrue(try context.fetch(FetchDescriptor<PresetInfo>()).isEmpty)
    XCTAssertTrue(try context.fetch(FetchDescriptor<AudioSettings>()).isEmpty)
    XCTAssertTrue(try context.fetch(FetchDescriptor<ReverbConfig>()).isEmpty)

    let faves = try context.fetch(FetchDescriptor<Favorite>())
    try XCTSkipUnless(faves.isEmpty, "SwiftData has broken cascade")
  }

  func testCustomDeletingPresetCascades() async throws {
    _ = try makeMockPreset(name: "Preset", bank: 1, program: 2)
    try context.save()
    let found = fetched[0]
    context.delete(preset: found)
    try context.save()

    XCTAssertTrue(try context.fetch(FetchDescriptor<PresetInfo>()).isEmpty)
    XCTAssertTrue(try context.fetch(FetchDescriptor<AudioSettings>()).isEmpty)
    XCTAssertTrue(try context.fetch(FetchDescriptor<ReverbConfig>()).isEmpty)

    let faves = try context.fetch(FetchDescriptor<Favorite>())
    XCTAssertTrue(faves.isEmpty)
  }
}
