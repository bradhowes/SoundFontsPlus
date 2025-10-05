import Foundation
import Testing

@testable import FeatureSupport

extension BaseTestSuite {

  @MainActor
  struct ClosedRangeTests {}
}

extension BaseTestSuite.ClosedRangeTests {

  @Test func distance() async throws {
    #expect((0.0...1.0).distance == 1.0)
    #expect((0.0...0.0).distance == 0.0)
    #expect((-0.5...0.5).distance == 1.0)
  }

  @Test func mid() async throws {
    #expect((0.0...1.0).mid == 0.5)
    #expect((10.0...90.0).mid == 50.0)
  }
}
