import XCTest
import Dependencies
import SwiftData

@testable import Models

final class TagTests: XCTestCase {
  var container: ModelContainer!
  var context: ModelContext!

  @MainActor
  override func setUp() async throws {
    container = try ModelContainer(
      for: Tag.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    context = container.mainContext
  }

  var fetched: [Tag] { (try? context.fetch(FetchDescriptor<Tag>())) ?? [] }

  @MainActor
  func makeMockTag(name: String) throws -> Tag {
    let tag = Tag(name: name)
    context.insert(tag)
    try context.save()
    return tag
  }

  @MainActor
  func testEmpty() throws {
    XCTAssertTrue(fetched.isEmpty)
  }

  @MainActor
  func testCreateNewTag() throws {
    let tag = try makeMockTag(name: "New Tag")
    let found = fetched
    XCTAssertFalse(found.isEmpty)
    XCTAssertEqual(found[0].name, tag.name)
  }

  @MainActor
  func testChangeTagName() throws {
    let tag = try makeMockTag(name: "New Tag")
    XCTAssertEqual(fetched[0].name, tag.name)
    fetched[0].name = "Changed Tag"
    try context.save()
    XCTAssertEqual(fetched[0].name, "Changed Tag")
  }

  @MainActor
  func testDeleteTagUpdatesSoundFont() throws {
    let soundFont = SoundFont(location: .init(kind: .builtin, url: nil, raw: nil), name: "Blah Blah")
    context.insert(soundFont)

    let tag = try makeMockTag(name: "New Tag")
    soundFont.tags = [tag]
    try context.save()

    XCTAssertFalse(fetched.isEmpty)

    context.delete(tag)
    try context.save()
    XCTAssertTrue(fetched.isEmpty)

    XCTAssertEqual(soundFont.tags, [])
  }

  @MainActor
  func testAllUbiquitousTags() throws {
    let ephemeral = UserDefaults.Dependency.ephemeral()
    let tagIds = try withDependencies {
      $0.userDefaults = ephemeral
    } operation: {
      try Tag.Ubiquitous.allCases.map { try context.ubiquitousTag($0).persistentModelID }
    }

    try withDependencies {
      $0.userDefaults = ephemeral
    } operation: {
      for (index, kind) in Tag.Ubiquitous.allCases.enumerated() {
        let tag = try context.ubiquitousTag(kind)
        XCTAssertEqual(tag.name, kind.name)
        XCTAssertTrue(tag.tagged.isEmpty)
        XCTAssertEqual(tag.persistentModelID, tagIds[index])
      }
    }
  }
}
