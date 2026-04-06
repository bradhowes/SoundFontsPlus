import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import SnapshotTesting
import SwiftUI
import Testing
import TestSupport
import UIKit

@testable import FeatureSupport

@Suite(
  .snapshots(record: .failed)
)
@MainActor
struct NavigationBarTitleStyleTests {

  @Test
  func preview() throws {
    navigationBarTitleStyle()
    let tmp = UIFont(name: "Eurostile", size: 40)
    #expect(tmp != nil)
  }
}
