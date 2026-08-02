import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import SnapshotTesting
import SwiftUI
import SQLiteData
import Tagged
import Testing
import TestSupport

@testable import FeatureSupport

@Suite(
  .snapshots(record: .failed)
)
@MainActor
struct ClearButtonTests {

  @Test
  func preview() throws {
    withDependencies {
      $0.defaultDatabase = previewDatabase()
    } operation: {
      withSnapshotTesting(record: .failed) {
        let view = TextFieldClearButton_Previews.previews
        TestSupport.assertSnapshot(matching: view)
      }
    }
  }
}
