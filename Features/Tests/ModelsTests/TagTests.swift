import XCTest
import Dependencies
import SwiftData

@testable import Models

final class TagTests: XCTestCase {
  var container: ModelContainer!
  var context: ModelContext!

  override func setUp() async throws {
    container = try ModelContainer(
      for: Tag.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    context = .init(container)
  }

  var fetched: [Tag] { (try? context.fetch(FetchDescriptor<Tag>())) ?? [] }

  func makeMockTag(name: String) throws -> Tag {
    let tag = Tag(name: name)
    context.insert(tag)
    try context.save()
    return tag
  }

  func testEmpty() throws {
    XCTAssertTrue(fetched.isEmpty)
  }

  func testCreateNewTag() throws {
    let tag = try makeMockTag(name: "New Tag")
    let found = fetched
    XCTAssertFalse(found.isEmpty)
    XCTAssertEqual(found[0].name, tag.name)
  }

  func testChangeTagName() throws {
    let tag = try makeMockTag(name: "New Tag")
    XCTAssertEqual(fetched[0].name, tag.name)
    fetched[0].name = "Changed Tag"
    try context.save()
    XCTAssertEqual(fetched[0].name, "Changed Tag")
  }

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

  func testAllUbiquitousTags() throws {
    let tagIds = Tag.Ubiquitous.allCases.map { context.ubiquitousTag($0).persistentModelID
    }

    for (index, kind) in Tag.Ubiquitous.allCases.enumerated() {
      let tag = context.ubiquitousTag(kind)
      XCTAssertEqual(tag.name, kind.name)
      XCTAssertTrue(tag.tagged.isEmpty)
      XCTAssertEqual(tag.persistentModelID, tagIds[index])
    }
  }
}
