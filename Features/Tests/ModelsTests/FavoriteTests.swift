import XCTest
import Dependencies
import SwiftData

@testable import Models

final class FavoriteTests: XCTestCase {
  var container: ModelContainer!
  var context: ModelContext!
  var soundFont: SoundFont!
  var preset: Preset!

  @MainActor
  override func setUp() async throws {
    container = try ModelContainer(
      for: Favorite.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    context = container.mainContext
    soundFont = SoundFont(location: .init(kind: .builtin, url: nil, raw: nil), name: "Blah Blah")
    preset = Preset(owner: soundFont, index: 0, name: name)
    context.insert(preset)
    try context.save()
  }

  var fetched: [Favorite] { (try? context.fetch(FetchDescriptor<Favorite>())) ?? [] }

  @MainActor
  func makeMockFavorite(name: String) throws -> Favorite {
    try context.createFavorite(name: name, preset: preset)
  }

  @MainActor
  func testEmpty() throws {
    XCTAssertTrue(fetched.isEmpty)
  }

  @MainActor
  func testCreateNewFavorite() throws {
    let favorite = try makeMockFavorite(name: "New Favorite")
    XCTAssertEqual(favorite.name, "New Favorite")
    let found = fetched
    XCTAssertEqual(found.count, 1)
    XCTAssertEqual(found[0].name, "New Favorite")
  }

  @MainActor
  func testCreateDupeFavorite() throws {
    _ = try makeMockFavorite(name: "New Favorite")
    _ = try makeMockFavorite(name: "New Favorite")
    _ = try makeMockFavorite(name: "New Favorite")
    let found = fetched

    XCTAssertEqual(found.count, 3)
    XCTAssertEqual(found[0].name, "New Favorite")
    XCTAssertEqual(found[1].name, "New Favorite")
    XCTAssertEqual(found[2].name, "New Favorite")

    XCTAssertEqual(preset.favorites?.count, 3)
  }

  @MainActor
  func testChangeFavoriteName() throws {
    let favorite = try makeMockFavorite(name: "New Favorite")
    XCTAssertEqual(fetched[0].name, favorite.name)
    fetched[0].name = "Changed Favorite"
    try context.save()
    XCTAssertEqual(fetched[0].name, "Changed Favorite")
  }

  @MainActor
  func testDeleteFavoriteCascades() throws {
    let favorite = try makeMockFavorite(name: "New Favorite")
    favorite.audioSettings = AudioSettings()
    favorite.audioSettings?.delayConfig = DelayConfig()
    try context.save()

    XCTAssertFalse(preset.favorites?.isEmpty ?? true)

    XCTAssertFalse(fetched.isEmpty)
    XCTAssertFalse(try context.fetch(FetchDescriptor<AudioSettings>()).isEmpty)
    XCTAssertFalse(try context.fetch(FetchDescriptor<DelayConfig>()).isEmpty)

    context.delete(favorite)
    try context.save()

    XCTAssertTrue(fetched.isEmpty)
    XCTAssertTrue(try context.fetch(FetchDescriptor<AudioSettings>()).isEmpty)
    XCTAssertTrue(try context.fetch(FetchDescriptor<DelayConfig>()).isEmpty)

    XCTAssertTrue(preset.favorites?.isEmpty ?? false)
  }
}
