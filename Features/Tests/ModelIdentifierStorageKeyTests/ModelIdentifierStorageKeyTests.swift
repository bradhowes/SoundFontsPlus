import Foundation
import SwiftData
import Models
import XCTest

@testable import ModelIdentifierStorageKey

final class ModelIdentifierStorageKeyTests: XCTestCase {

  @MainActor
  func testKeyEncodingDecoding() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Tag.self, configurations: config)
    container.mainContext.createAllUbiquitousTags()
    let fetchDescriptor = FetchDescriptor<Tag>(sortBy: [.init(\Tag.name)])
    let tags = try! container.mainContext.fetch(fetchDescriptor)
    let encoder = JSONEncoder()
    let raw = try! encoder.encode(tags[0].persistentModelID)
    let decoder = JSONDecoder()
    let key = try! decoder.decode(PersistentIdentifier.self, from: raw)
    let tag = container.mainContext.model(for: key) as! Tag

    XCTAssertEqual(tag.persistentModelID, key)
    XCTAssertEqual(tag.name, "All")
  }
}
