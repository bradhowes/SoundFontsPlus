import ComposableArchitecture
import Dependencies
import DependenciesTestSupport
import Foundation
import Sharing
import SnapshotTesting
import SwiftUI
import Testing

@testable import SoundFontsPlus

extension BaseTestSuite {

  @MainActor
  struct AppReviewTests {

    @Test
    func firstTimeAsk() async throws {
      let now = Date(timeIntervalSince1970: 0)
      let store = TestStore(initialState: AppReviewFeature.State()) { AppReviewFeature() } withDependencies: {
        $0.date.now = now
      }

      @Shared(.nextReviewRequestDate) var nextReviewRequestDate
      #expect(nextReviewRequestDate == .distantPast)

      await store.send(.ask)
      await store.send(.ask)

      #expect(nextReviewRequestDate == AppReviewFeature.minDateAfterFirstLaunch(now))
    }

    @Test
    func minDaysAfterLaunchFirstTimeAsk() async throws {
      @Shared(.nextReviewRequestDate) var nextReviewRequestDate
      @Shared(.lastReviewRequestVersion) var lastReviewRequestVersion

      let now = Date(timeIntervalSince1970: 0)
      let store = TestStore(initialState: AppReviewFeature.State(minActivityCounter: 5)) {
        AppReviewFeature()
      } withDependencies: {
        $0.date.now = now
        $nextReviewRequestDate.withLock { $0 = now }
        $lastReviewRequestVersion.withLock { $0 = AppReviewFeature.currentVersion }
      }

      await store.send(.ask) { $0.activityCounter = 1 }
      await store.send(.ask) { $0.activityCounter = 2 }
      await store.send(.ask) { $0.activityCounter = 3 }
      await store.send(.ask) { $0.activityCounter = 4 }
      await store.send(.ask) {
        $0.activityCounter = 0
        $0.askForReview = true
      }

      await store.send(.reviewAsked) {
        $0.askForReview = false
      }

      await store.send(.ask) {
        $0.activityCounter = 1
        $0.askForReview = false
      }
    }

    @Test
    func minDaysAfterVersionChanges() async throws {
      @Shared(.nextReviewRequestDate) var nextReviewRequestDate
      @Shared(.lastReviewRequestVersion) var lastReviewRequestVersion

      let now = Date(timeIntervalSince1970: 0)
      let store = TestStore(initialState: AppReviewFeature.State()) { AppReviewFeature() } withDependencies: {
        $0.date.now = now
        $nextReviewRequestDate.withLock { $0 = now }
        $lastReviewRequestVersion.withLock { $0 = AppReviewFeature.currentVersion }
      }

      await store.send(.ask) { $0.activityCounter = 1 }
      await store.send(.ask) { $0.activityCounter = 2 }

      $lastReviewRequestVersion.withLock { $0 = "99.99.99" }

      await store.send(.ask) { $0.activityCounter = 2 }
    }

    @Test
    func appReviewFeaturePreview() async throws {
      prepareDependencies {
        let now = Date(timeIntervalSince1970: 0)
        $0.date.now = now
        @Shared(.nextReviewRequestDate) var nextReviewRequestDate = now
        @Shared(.lastReviewRequestVersion) var lastReviewRequestVersion = AppReviewFeature.currentVersion
      }

      let store: StoreOf<AppReviewFeature> = .init(initialState: AppReviewFeature.State(activityCounter: 4)) {
        AppReviewFeature()
      }

      let view = AppReviewDemoView(store: store)
      store.send(.ask)

      if BaseTestSuite.isLocal {
        withSnapshotTesting(record: .failed) {
          assertSnapshot(
            of: view,
            as: .image(
              layout: .fixed(width: 400, height: 800),
              traits: .init(userInterfaceStyle: .dark)
            )
          )
        }
      }
    }
  }
}
