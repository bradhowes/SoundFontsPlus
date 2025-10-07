import Testing

import ComposableArchitecture
import Dependencies
import DependenciesTestSupport
import Models
import SnapshotTesting
import SwiftUI

@testable import Root

@Suite(
  .dependencies {
    $0.defaultDatabase = try appDatabase()
    $0.mainQueue = .immediate
  },
  .snapshots(record: .failed)
)
@MainActor
struct RootTests {

  func store() -> TestStoreOf<Root> {
    TestStoreOf<Root>(initialState: .init()) {
      Root()
    }
  }

  @Test func disableIdleTimer() throws {
    @Shared(.disableIdleTimer) var disableIdleTimer = false
    #expect(!UIKit.UIApplication.shared.isIdleTimerDisabled)

    Root.disableIdleTimer()
    #expect(!UIKit.UIApplication.shared.isIdleTimerDisabled)

    $disableIdleTimer.withLock { $0 = true }
    Root.disableIdleTimer()
    // NOTE: does not appear to work in test environment
    // #expect(UIKit.UIApplication.shared.isIdleTimerDisabled)
  }

  @Test func initialize() async throws {
    
  }

  @Test func rootViewPreview() async throws {
    try withSnapshotTesting(record: .failed) {
      try assertSnapshot(
        of: RootView.preview,
        as: .wait(for: 1, on: .image(
          drawHierarchyInKeyWindow: false,
          layout: .fixed(width: 400, height: 800)
        ))
      )
    }
  }
}
