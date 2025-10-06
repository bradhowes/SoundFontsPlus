// Copyright © 2025 Brad Howes. All rights reserved.

import BaseSupport
import ComposableArchitecture
import Dependencies
import FeatureSupport
import Models
import StoreKit
import SwiftUI

private let log = Logger(category: "AppReview")

/**
 Provides an app review prompt at appropriate times.

 From Apple's documentation for
 [RequestReviewAction](https://developer.apple.com/documentation/storekit/requestreviewaction):

 - If the person hasn’t rated or reviewed your app on this device, StoreKit displays the ratings and review request
   a maximum of three times within a 365-day period.
 - If the person has rated or reviewed your app on this device, StoreKit displays the ratings and review request if
   the app version is new, and if more than 365 days have passed since the person’s previous review.

 Additionally, this code delays 14 days before first asking for a review.
 */
@Reducer
public struct AppReview {

  static let daysAfterFirstLaunchBeforeRequest = 14

  @ObservableState
  public struct State: Equatable {
    public var askForReview: Bool = false
    public var activityCounter: Int = 0
    public let minActivityCounter: Int

    public init(activityCounter: Int = 0, minActivityCounter: Int = 50) {
      self.activityCounter = activityCounter
      self.minActivityCounter = minActivityCounter
    }
  }

  public enum Action {
    case ask
    case reviewAsked
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .ask:
        return askForReview(&state)

      case .reviewAsked:
        state.askForReview = false
        return .none
      }
    }
  }

  @Dependency(\.date.now) var now
}

extension AppReview {

  static func minDateAfterFirstLaunch(_ now: Date) -> Date {
    Calendar.current.date(
      byAdding: .day,
      value: daysAfterFirstLaunchBeforeRequest,
      to: now
    )! // swiftlint:disable:this force_unwrapping
  }

  static var currentVersion: String { return Bundle.main.releaseVersionNumber }

  private func askForReview(_ state: inout State) -> Effect<Action> {
    @Dependency(\.date.now) var now
    @Shared(.nextReviewRequestDate) var nextReviewRequestDate
    @Shared(.lastReviewRequestVersion) var lastReviewRequestVersion

    // Postpone asking for a review 14 days since first launching or 14 days after starting a new version.
    // Additional restrictions are controlled by Apple's StoreKit.
    if nextReviewRequestDate == .distantPast || Self.currentVersion != lastReviewRequestVersion {
      $nextReviewRequestDate.withLock { $0 = Self.minDateAfterFirstLaunch(now) }
      $lastReviewRequestVersion.withLock { $0 = Self.currentVersion }
    }

    guard now >= nextReviewRequestDate else {
      log.debug("before next review request date \(nextReviewRequestDate)")
      return .none
    }

    // Postpone asking for a review until the user has performed N activities.
    state.activityCounter += 1
    state.askForReview = state.activityCounter >= state.minActivityCounter
    if state.askForReview {
      state.activityCounter = 0
    }

    return .none
  }
}

public struct AppReviewModifier: ViewModifier {
  private var store: StoreOf<AppReview>
  @Environment(\.requestReview) private var requestReview

  public init(store: StoreOf<AppReview>) {
    self.store = store
  }

  public func body(content: Content) -> some View {
    content
      .onChange(of: store.askForReview) {
        if store.askForReview {
          requestReview()
          store.send(.reviewAsked)
        }
      }
  }
}

extension View {
  public func appReview(store: StoreOf<AppReview>) -> some View {
    modifier(AppReviewModifier(store: store))
  }
}

struct AppReviewDemoView: View {
  @State var store: StoreOf<AppReview>

  init(store: StoreOf<AppReview>) {
    self.store = store
  }

  var body: some View {
    let label = "\(store.activityCounter) - \(store.askForReview)"
    return VStack(spacing: 20) {
      Text("Hello, World!")
        .appReview(store: store)
      Text(label)
      Button {
        store.send(.ask)
      } label: {
        Text("Ask for review")
      }
    }
  }
}

#Preview {
  // swiftlint:disable:next redundant_discardable_let
  let _ = prepareDependencies {
    let now = Date(timeIntervalSince1970: 0)
    $0.date.now = now
    @Shared(.nextReviewRequestDate) var nextReviewRequestDate = now
    @Shared(.lastReviewRequestVersion) var lastReviewRequestVersion = AppReview.currentVersion
  }

  let store: StoreOf<AppReview> = .init(initialState: AppReview.State(
    activityCounter: 4
  )) { AppReview() }

  AppReviewDemoView(store: store)
}
