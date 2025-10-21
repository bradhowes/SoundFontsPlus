// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import Testing
import TestSupport

@testable import Root

@Suite(
  .dependencies {
    let mockVolume = OutputVolumeFlipFlop()
    $0.outputVolume = mockVolume.makeOutputVolume()
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
    try TestSupport.assertSnapshot(matching: RootView.preview)
  }
}
