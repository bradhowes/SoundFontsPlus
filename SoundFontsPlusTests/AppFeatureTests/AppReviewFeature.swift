import ComposableArchitecture
import Dependencies
import DependenciesTestSupport
import Foundation
import Sharing
import Testing

@testable import SoundFontsPlus

extension BaseSuite {

  @Suite
  struct AppReviewTests {

    @Test
    func firstTimeAsk() async throws {
      let now = Date(timeIntervalSince1970: 0)
      let store = await TestStore(initialState: AppReviewFeature.State()) { AppReviewFeature() } withDependencies: {
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
      let store = await TestStore(initialState: AppReviewFeature.State()) { AppReviewFeature() } withDependencies: {
        $0.date.now = now
        $nextReviewRequestDate.withLock { $0 = now }
      }

      #expect(lastReviewRequestVersion == "")

      await store.send(.ask) { $0.activityCounter = 4 }
      await store.send(.ask) { $0.activityCounter = 3 }
      await store.send(.ask) { $0.activityCounter = 2 }
      await store.send(.ask) { $0.activityCounter = 1 }
      await store.send(.ask) {
        $0.activityCounter = 0
        $0.askForReview = true
      }

      #expect(nextReviewRequestDate != now)
      #expect(lastReviewRequestVersion != "")

      await store.send(.reviewAsked) {
        $0.askForReview = false
      }
    }

    @Test
    func noReviewAskIfVersionSame() async throws {
      @Shared(.nextReviewRequestDate) var nextReviewRequestDate
      @Shared(.lastReviewRequestVersion) var lastReviewRequestVersion

      let now = Date(timeIntervalSince1970: 0)
      let store = await TestStore(initialState: AppReviewFeature.State()) { AppReviewFeature() } withDependencies: {
        $0.date.now = now
        $nextReviewRequestDate.withLock { $0 = now }
        $lastReviewRequestVersion.withLock { $0 = AppReviewFeature.currentVersion() }
      }

      await store.send(.ask)
      await store.send(.ask)

      $lastReviewRequestVersion.withLock { $0 = "" }

      await store.send(.ask) { $0.activityCounter = 4 }
    }
  }
}
