//import XCTest
//import Dependencies
//import SwiftData
//
//@testable import Models
//
//final class FavoriteTests: XCTestCase {
//  var container: ModelContainer!
//  var context: ModelContext!
//  var soundFont: SoundFontModel!
//  var preset: PresetModel!
//
//  override func setUp() async throws {
//    container = try ModelContainer(
//      for: FavoriteModel.self,
//      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
//    )
//    context = .init(container)
//    soundFont = SoundFontModel(location: .init(kind: .builtin, url: nil, raw: nil), name: "Blah Blah")
//    preset = PresetModel(owner: soundFont, index: 0, name: name)
//    context.insert(preset)
//    try context.save()
//  }
//
//  var fetched: [Favorite] { (try? context.favorites()) ?? [] }
//
//  func makeMockFavorite(name: String, index: Int? = nil) throws -> Favorite {
//    let favorite = try context.createFavorite(name: name, preset: preset)
//    if let index = index {
//      favorite.index = index
//      try context.save()
//    }
//    return favorite
//  }
//
//  func testEmpty() throws {
//    XCTAssertTrue(fetched.isEmpty)
//  }
//
//  func testCreateNewFavorite() throws {
//    let favorite = try makeMockFavorite(name: "New Favorite")
//    XCTAssertEqual(favorite.name, "New Favorite")
//    let found = fetched
//    XCTAssertEqual(found.count, 1)
//    XCTAssertEqual(found[0].name, "New Favorite")
//  }
//
//  func testCreateDupeFavorites() throws {
//    _ = try makeMockFavorite(name: "New Favorite")
//    _ = try makeMockFavorite(name: "New Favorite")
//    _ = try makeMockFavorite(name: "New Favorite")
//    let found = fetched
//
//    XCTAssertEqual(found.count, 3)
//    XCTAssertEqual(found[0].name, "New Favorite")
//    XCTAssertEqual(found[1].name, "New Favorite")
//    XCTAssertEqual(found[2].name, "New Favorite")
//
//    XCTAssertEqual(preset.favorites?.count, 3)
//  }
//
//  func testChangeFavoriteName() throws {
//    let favorite = try makeMockFavorite(name: "New Favorite")
//    XCTAssertEqual(fetched[0].name, favorite.name)
//    fetched[0].name = "Changed Favorite"
//    try context.save()
//    XCTAssertEqual(fetched[0].name, "Changed Favorite")
//  }
//
//  func testDeleteFavoriteCascades() throws {
//    let favorite = try makeMockFavorite(name: "New Favorite")
//    favorite.audioSettings = AudioSettings()
//    favorite.audioSettings?.delayConfig = DelayConfig()
//    try context.save()
//
//    XCTAssertFalse(preset.favorites?.isEmpty ?? true)
//
//    XCTAssertFalse(fetched.isEmpty)
//    XCTAssertFalse(try context.fetch(FetchDescriptor<AudioSettings>()).isEmpty)
//    XCTAssertFalse(try context.fetch(FetchDescriptor<DelayConfig>()).isEmpty)
//
//    context.delete(favorite)
//    try context.save()
//
//    XCTAssertTrue(fetched.isEmpty)
//    XCTAssertTrue(try context.fetch(FetchDescriptor<AudioSettings>()).isEmpty)
//    XCTAssertTrue(try context.fetch(FetchDescriptor<DelayConfig>()).isEmpty)
//
//    XCTAssertTrue(preset.favorites?.isEmpty ?? false)
//  }
//
//  func testFetchOrderedFavorites() throws {
//    _ = try makeMockFavorite(name: "New Favorite 1")
//    _ = try makeMockFavorite(name: "New Favorite 2")
//    _ = try makeMockFavorite(name: "New Favorite 3")
//    var found = fetched
//
//    XCTAssertEqual(found.count, 3)
//    XCTAssertEqual(found[0].name, "New Favorite 1")
//    XCTAssertEqual(found[1].name, "New Favorite 2")
//    XCTAssertEqual(found[2].name, "New Favorite 3")
//
//    XCTAssertEqual(preset.favorites?.count, 3)
//
//    found[2].index = 0
//    found[0].index = 1
//    found[1].index = 2
//
//    try context.save()
//
//    found = fetched
//    XCTAssertEqual(found.count, 3)
//    XCTAssertEqual(found[0].name, "New Favorite 3")
//    XCTAssertEqual(found[1].name, "New Favorite 1")
//    XCTAssertEqual(found[2].name, "New Favorite 2")
//  }
//}
