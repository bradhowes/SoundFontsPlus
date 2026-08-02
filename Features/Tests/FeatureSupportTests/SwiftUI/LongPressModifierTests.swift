import DependenciesTestSupport
import Foundation
import Models
import SnapshotTesting
import SQLiteData
import SwiftUI
import Tagged
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
    withDependencies {
      $0.defaultDatabase = previewDatabase()
    } operation: {
      withSnapshotTesting(record: .failed) {
        TestSupport.assertSnapshot(matching: LongPressGestureModifierPreview())
      }
    }
  }
}
