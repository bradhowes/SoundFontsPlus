import XCTest
import SwiftData

@testable import Models

@MainActor
final class PresetInfoModelTests: XCTestCase {
  var container: ModelContainer!
  var context: ModelContext!

  override func setUp() async throws {
    container = try ModelContainer(
      for: PresetInfoModel.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    context = container.mainContext
  }

  var fetched: [PresetInfoModel] {
    (try? context.fetch(FetchDescriptor<PresetInfoModel>())) ?? []
  }

  func makeMockPresetInfo(originalName: String, bank: Int, program: Int) throws -> PresetInfoModel {
    let presetInfo = PresetInfoModel(originalName: originalName, bank: bank, program: program)
    context.insert(presetInfo)
    try context.save()
    return presetInfo
  }

  func testEmpty() throws {
    XCTAssertTrue(fetched.isEmpty)
  }

  func testCreateNew() throws {
    let entry = try makeMockPresetInfo(originalName: "foobar", bank: 1, program: 2)
    XCTAssertEqual(entry.originalName, "foobar")
    XCTAssertEqual(entry.bank, 1)
    XCTAssertEqual(entry.program, 2)
    let found = fetched
    XCTAssertFalse(found.isEmpty)
    XCTAssertEqual(found[0].originalName, entry.originalName)
    XCTAssertEqual(found[0].bank, entry.bank)
    XCTAssertEqual(found[0].program, entry.program)
  }

  func testDelete() throws {
    let entry = try makeMockPresetInfo(originalName: "blah blah", bank: 123, program: 456)
    XCTAssertFalse(fetched.isEmpty)
    context.delete(entry)
    try context.save()
    XCTAssertTrue(fetched.isEmpty)
  }
}
