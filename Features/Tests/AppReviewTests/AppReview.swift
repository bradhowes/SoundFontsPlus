import ComposableArchitecture
import CustomSnapshot
import Foundation
import Dependencies
import DependenciesTestSupport
import Models
import Sharing
import SnapshotTesting
import SwiftUI
import Testing

@testable import AppReview

@Suite(
  .dependencies {
    $0.defaultDatabase = try appDatabase()
  },
  .snapshots(record: .failed)
)
@MainActor
struct AppReviewTests {

  @Test
  func firstTimeAsk() async throws {
    let now = Date(timeIntervalSince1970: 0)
    let store = TestStore(initialState: AppReview.State()) { AppReview() } withDependencies: {
      $0.date.now = now
    }

    @Shared(.nextReviewRequestDate) var nextReviewRequestDate
    #expect(nextReviewRequestDate == .distantPast)

    await store.send(.ask)
    await store.send(.ask)

    #expect(nextReviewRequestDate == AppReview.minDateAfterFirstLaunch(now))
  }

  @Test
  func minDaysAfterLaunchFirstTimeAsk() async throws {
    @Shared(.nextReviewRequestDate) var nextReviewRequestDate
    @Shared(.lastReviewRequestVersion) var lastReviewRequestVersion

    let now = Date(timeIntervalSince1970: 0)
    let store = TestStore(initialState: AppReview.State(minActivityCounter: 5)) {
      AppReview()
    } withDependencies: {
      $0.date.now = now
      $nextReviewRequestDate.withLock { $0 = now }
      $lastReviewRequestVersion.withLock { $0 = AppReview.currentVersion }
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
    let store = TestStore(initialState: AppReview.State()) { AppReview() } withDependencies: {
      $0.date.now = now
      $nextReviewRequestDate.withLock { $0 = now }
      $lastReviewRequestVersion.withLock { $0 = AppReview.currentVersion }
    }

    await store.send(.ask) { $0.activityCounter = 1 }
    await store.send(.ask) { $0.activityCounter = 2 }

    $lastReviewRequestVersion.withLock { $0 = "99.99.99" }

    await store.send(.ask) { $0.activityCounter = 2 }
  }

  @Test
  func appReviewPreview() async throws {
    prepareDependencies {
      let now = Date(timeIntervalSince1970: 0)
      $0.date.now = now
      @Shared(.nextReviewRequestDate) var nextReviewRequestDate = now
      @Shared(.lastReviewRequestVersion) var lastReviewRequestVersion = AppReview.currentVersion
    }

    let store: StoreOf<AppReview> = .init(initialState: AppReview.State(activityCounter: 4)) {
      AppReview()
    }

    let view = AppReviewDemoView(store: store)
    store.send(.ask)

    try withSnapshotTesting(record: .failed) {
      try CustomSnapshot.assertSnapshot(matching: view)
    }
  }
}
