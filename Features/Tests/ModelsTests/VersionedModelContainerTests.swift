import XCTest
import Dependencies
import DependenciesAdditions
import SwiftData
import SF2ResourceFiles

@testable import Models

final class VersionedModelContainerTests: XCTestCase {

  func testMake() {
    let container = VersionedModelContainer.make(isTemporary: true)
    let context = ModelContext(container)
    let found = context.findTagByName(name: Tag.Ubiquitous.all.name)
    XCTAssertTrue(found.isEmpty)
  }

  func testModelContextProvider() throws {
    let factory = ModelContextProvider.make(isTemporary: true)
    let context1 = try factory.generate()
    let found = context1.findTagByName(name: Tag.Ubiquitous.all.name)
    XCTAssertTrue(found.isEmpty)
    context1.createAllUbiquitousTags()

    let context2 = try factory.generate()
    XCTAssertFalse(context2.findTagByName(name: Tag.Ubiquitous.all.name).isEmpty)
  }

  func testModelContextFactorySending() async throws {
    let factory = ModelContextProvider.make(isTemporary: true)
    let context1 = try factory.generate()
    context1.createAllUbiquitousTags()
    let found = context1.ubiquitousTag(.all)
    XCTAssertEqual(found.name, Tag.Ubiquitous.all.name)

    let tagId = found.persistentModelID
    let _ = try await Task {
      let context = try factory.generate()
      let found = context.model(for: tagId) as? Tag
      XCTAssertNotNil(found)
      XCTAssertEqual(found?.name, Tag.Ubiquitous.all.name)
    }.value
  }
}
