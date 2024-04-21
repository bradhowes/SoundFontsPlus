import XCTest
import Dependencies
import SwiftData

@testable import SF2Files

@MainActor
final class SF2FilesTests: XCTestCase {

  func testResourcesExist() throws {
    XCTAssertEqual(SF2Files.resources.count, 3)
  }
}
