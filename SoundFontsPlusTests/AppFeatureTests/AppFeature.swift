import Testing

import ComposableArchitecture
import Dependencies
import SnapshotTesting
import SwiftUI

@testable import SoundFontsPlus

extension BaseTestSuite {

  @MainActor
  struct AppFeatureTests {}
}

extension BaseTestSuite.AppFeatureTests {

  func store() -> TestStoreOf<AppFeature> {
    TestStoreOf<AppFeature>(initialState: .init()) {
      AppFeature()
    } withDependencies: {
      $0.mainQueue = .immediate
    }
  }

  @Test func disableIdleTimer() throws {
    @Shared(.disableIdleTimer) var disableIdleTimer = false
    #expect(!UIKit.UIApplication.shared.isIdleTimerDisabled)

    AppFeature.disableIdleTimer()
    #expect(!UIKit.UIApplication.shared.isIdleTimerDisabled)

    $disableIdleTimer.withLock { $0 = true }

    AppFeature.disableIdleTimer()
    #expect(UIKit.UIApplication.shared.isIdleTimerDisabled)
  }

  @Test func initialize() async throws {
    
  }

  @Test func appViewPreview() async throws {
    try withSnapshotTesting(record: .failed) {
      try BaseTestSuite.assertSnap(
        matching: AppFeatureView.preview,
        size: .init(width: 400, height: 800),
        colorScheme: .dark
      )
    }
  }
}
