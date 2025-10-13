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
struct ReverbRoomPresetPickerViewTests {

  @Test
  func testView() throws {
    let view = VStack {
      Text("Hello")
      ReverbRoomPresetPickerView()
      Text("World!")
    }
    try TestSupport.assertSnapshot(matching: view)
  }
}
