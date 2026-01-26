import ComposableArchitecture
import Dependencies
import DependenciesTestSupport
import Foundation
import SnapshotTesting
import SwiftUI
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
    let view = TextFieldClearButton_Previews.previews
    try TestSupport.assertSnapshot(matching: view)
  }
}
