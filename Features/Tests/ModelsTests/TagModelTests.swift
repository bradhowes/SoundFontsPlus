import XCTest
import Dependencies
import SwiftData

@testable import Models

@MainActor
final class TagModelTests: XCTestCase {
  @Dependency(\.uuid) var uuid;

  var container: ModelContainer!
  var context: ModelContext!

  override func setUp() async throws {
    container = try ModelContainer(
      for: TagModel.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    context = container.mainContext
  }

  var fetched: [TagModel] {
    (try? context.fetch(FetchDescriptor<TagModel>())) ?? []
  }

  func makeMockTag(id: UUID, name: String) throws -> TagModel {
    let tag = TagModel(id: id, name: "New Tag")
    context.insert(tag)
    try context.save()
    return tag
  }

  func testEmpty() throws {
    XCTAssertTrue(fetched.isEmpty)
  }

  func testRegisterConstants() throws {
    try TagModel.registerConstants(in: context)
    let found = fetched
    XCTAssertEqual(found.count, 2)
    XCTAssertNotNil(found.first(where: { $0 == TagModel.all }))
    XCTAssertNotNil(found.first(where: { $0 == TagModel.builtIn }))
  }

  func testCreateNewTag() throws {
    try withDependencies {
      $0.uuid = .incrementing
    } operation: {
      let tag = try makeMockTag(id: uuid(), name: "New Tag")
      let found = fetched
      XCTAssertFalse(found.isEmpty)
      XCTAssertEqual(found[0].name, tag.name)
    }
  }

  func testChangeTagName() throws {
    try withDependencies {
      $0.uuid = .incrementing
    } operation: {
      let tag = try makeMockTag(id: uuid(), name: "New Tag")
      XCTAssertEqual(fetched[0].name, tag.name)
      fetched[0].name = "Changed Tag"
      try context.save()
      XCTAssertEqual(fetched[0].name, "Changed Tag")
    }
  }

  func testDeleteTag() throws {
    try withDependencies {
      $0.uuid = .incrementing
    } operation: {
      let tag = try makeMockTag(id: uuid(), name: "New Tag")
      XCTAssertFalse(fetched.isEmpty)
      context.delete(tag)
      try context.save()
      XCTAssertTrue(fetched.isEmpty)
    }
  }
}
