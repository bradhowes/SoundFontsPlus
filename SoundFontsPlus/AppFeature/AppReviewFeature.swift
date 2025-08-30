// Copyright © 2025 Brad Howes. All rights reserved.

import Combine
import ComposableArchitecture
import StoreKit
import SwiftUI

private let log = Logger(category: "AppReviewFeature")

@Reducer
public struct AppReviewFeature {

  let daysAfterFirstLaunchBeforeRequest = 14
  let monthsBetweenReviewRequests = 3

  @ObservableState
  public struct State: Equatable {
    var askForReview: Bool = false
    var counter: Int = 3
  }

  public enum Action {
    case ask
    case reviewAsked
  }

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
}

extension AppReviewFeature {

  private func askForReview(_ state: inout State) -> Effect<Action> {
    let currentVersion: String = Bundle.main.releaseVersionNumber
    @Shared(.lastReviewRequestVersion) var lastReviewRequestVersion

    guard currentVersion != lastReviewRequestVersion else {
      log.debug("same version as last review request")
      return .none
    }

    @Shared(.firstLaunchDate) var firstLaunchDate
    let minDateAfterFirstLaunch = Calendar.current.date(
      byAdding: .day,
      value: daysAfterFirstLaunchBeforeRequest,
      to: firstLaunchDate
    ) ?? Date.distantFuture

    let now = Date.now
    guard now >= minDateAfterFirstLaunch else {
      log.debug("too soon after first launch")
      return .none
    }

    @Shared(.lastReviewRequestDate) var lastReviewRequestDate
    let minDateSinceLastReviewRequest = Calendar.current.date(
      byAdding: .month,
      value: monthsBetweenReviewRequests,
      to: lastReviewRequestDate
    ) ?? Date.distantFuture

    guard now >= minDateSinceLastReviewRequest else {
      log.debug("too soon after last review request")
      return .none
    }

    guard state.counter < 1 else {
      state.counter -= 1
      log.debug("too soon after launching")
      return .none
    }

    state.askForReview = true

    $lastReviewRequestVersion.withLock { $0 = currentVersion }
    $lastReviewRequestDate.withLock { $0 = now }

    return .none
  }
}

public struct AppReviewModifier: ViewModifier {
  private var store: StoreOf<AppReviewFeature>
  @Environment(\.requestReview) private var requestReview

  public init(store: StoreOf<AppReviewFeature>) {
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
  public func appReview(store: StoreOf<AppReviewFeature>) -> some View {
    modifier(AppReviewModifier(store: store))
  }
}
