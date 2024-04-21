import XCTest
import SwiftData

@testable import Models

@MainActor
final class PresetModelTests: XCTestCase {

  var container: ModelContainer!
  var context: ModelContext!

  override func setUp() async throws {
    container = try ModelContainer(
      for: SoundFontModel.self, PresetModel.self, PresetInfoModel.self, AudioSettingsModel.self, FavoriteModel.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    context = container.mainContext
  }

  var fetched: [PresetModel] {
    (try? context.fetch(FetchDescriptor<PresetModel>())) ?? []
  }

  func makeMockPreset(name: String, bank: Int, program: Int) throws -> PresetModel {
    let info = PresetInfoModel(originalName: name, bank: bank, program: program)
    let preset = PresetModel(soundFontId: "blah", index: 0, name: name, info: info, audioSettings: .init())
    context.insert(preset)
    try context.save()
    return preset
  }

  func testEmpty() throws {
    XCTAssertTrue(fetched.isEmpty)
  }

  func testCreateNewPreset() throws {
    let preset = try makeMockPreset(name: "Preset", bank: 1, program: 2)
    XCTAssertEqual(preset.name, "Preset")
    XCTAssertEqual(preset.info.originalName, "Preset")
    XCTAssertEqual(preset.info.bank, 1)
    XCTAssertEqual(preset.info.program, 2)
    let found = fetched[0]
    XCTAssertEqual(found.name, preset.name)
    XCTAssertEqual(found.info.originalName, "Preset")
    XCTAssertEqual(found.info.bank, 1)
    XCTAssertEqual(found.info.program, 2)
  }

  func testNameChange() throws {
    let preset = try makeMockPreset(name: "Preset", bank: 1, program: 2)
    var found = fetched[0]
    XCTAssertEqual(found.name, preset.name)
    found.name = "New Name"
    try context.save()
    found = fetched[0]
    XCTAssertEqual(found.name, "New Name")
    XCTAssertEqual(found.info.originalName, "Preset")
  }
}
