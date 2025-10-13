import Dependencies
import DependenciesTestSupport
import Foundation
import Models
import SnapshotTesting
import SwiftUI
import Testing
import TestSupport

@testable import FeatureSupport

@Suite(
  .snapshots(record: .failed)
)
@MainActor
struct LongPressModifierTests {

  @Test
  func testViewModifier() throws {
    try TestSupport.assertSnapshot(matching: LongPressGestureModifierPreview())
  }
}
