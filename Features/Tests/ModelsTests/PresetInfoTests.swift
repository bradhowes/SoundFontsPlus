//import XCTest
//import Engine
//import SwiftUI
//import SwiftData
//
//@testable import Models
//
//class PresetInfoTests: XCTestCase {
//  var container: ModelContainer!
//  var context: ModelContext!
//
//  @MainActor
//  override func setUp() async throws {
//    container = try ModelContainer(
//      for: Favorite.self,
//      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
//    )
//    context = .init(container)
//  }
//
//  var fetched: [PresetInfo] {
//    (try? context.fetch(FetchDescriptor<PresetInfo>(sortBy: [SortDescriptor(\.originalName)]))) ?? []
//  }
//
//  func makeMockPresetInfo(name: String) throws -> PresetInfo {
//    let presetInfo = PresetInfo(originalName: name, bank: 1, program: 2)
//    context.insert(presetInfo)
//    try context.save()
//    return presetInfo
//  }
//
//  func testEmpty() async throws {
//    let presetInfos = try context.presetInfos()
//    XCTAssertTrue(presetInfos.isEmpty)
//  }
//
//  func testCreateNew() async throws {
//    _ = try context.createPresetInfo(originalName: "foo", bank: 1, program: 2)
//    _ = try context.createPresetInfo(originalName: "bar", bank: 1, program: 3)
//
//    let presetInfos = fetched
//    XCTAssertEqual(presetInfos.count, 2)
//    XCTAssertEqual(presetInfos[0].originalName, "bar")
//    XCTAssertEqual(presetInfos[0].bank, 1)
//    XCTAssertEqual(presetInfos[0].program, 3)
//    XCTAssertEqual(presetInfos[1].originalName, "foo")
//    XCTAssertEqual(presetInfos[1].bank, 1)
//    XCTAssertEqual(presetInfos[1].program, 2)
//  }
//
//  func testDelete() async throws {
//    _ = try context.createPresetInfo(originalName: "foo", bank: 1, program: 2)
//    _ = try context.createPresetInfo(originalName: "bar", bank: 1, program: 3)
//
//    var presetInfos = fetched
//    XCTAssertEqual(presetInfos.count, 2)
//
//    context.delete(presetInfos[0])
//    try context.save()
//
//    presetInfos = fetched
//    XCTAssertEqual(presetInfos.count, 1)
//    XCTAssertEqual(presetInfos[0].originalName, "foo")
//    XCTAssertEqual(presetInfos[0].bank, 1)
//    XCTAssertEqual(presetInfos[0].program, 2)
//  }
//
//  func testDeleteById() async throws {
//    _ = try context.createPresetInfo(originalName: "foo", bank: 1, program: 2)
//    _ = try context.createPresetInfo(originalName: "bar", bank: 1, program: 3)
//
//    var presetInfos = fetched
//    XCTAssertEqual(presetInfos.count, 2)
//
//    let id = presetInfos[0].persistentModelID
//    try context.delete(model: PresetInfo.self, where: #Predicate { $0.persistentModelID == id })
//    try context.save()
//
//    presetInfos = fetched
//    XCTAssertEqual(presetInfos.count, 1)
//    XCTAssertEqual(presetInfos[0].originalName, "foo")
//    XCTAssertEqual(presetInfos[0].bank, 1)
//    XCTAssertEqual(presetInfos[0].program, 2)
//
//    try context.delete(model: PresetInfo.self, where: #Predicate { $0.originalName == "foo" })
//    try context.save()
//
//    presetInfos = fetched
//    XCTAssertEqual(presetInfos.count, 0)
//  }
//
//  func testDupes() async throws {
//    _ = try context.createPresetInfo(originalName: "foo", bank: 1, program: 2)
//    _ = try context.createPresetInfo(originalName: "foo", bank: 1, program: 2)
//    _ = try context.createPresetInfo(originalName: "foo", bank: 1, program: 2)
//
//    let presetInfos = fetched
//    XCTAssertEqual(presetInfos.count, 3)
//  }
//}
