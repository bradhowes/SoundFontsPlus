// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import Dependencies
import StoreKit
import SwiftUI

private let log = Logger(category: "AppReviewFeature")

@Reducer
public struct AppReviewFeature {

  static let daysAfterFirstLaunchBeforeRequest = 14
  static let monthsBetweenReviewRequests = 3
  static let initActivityCounter = 5

  @ObservableState
  public struct State: Equatable {
    var askForReview: Bool = false
    var activityCounter: Int = AppReviewFeature.initActivityCounter
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

  @Dependency(\.date.now) var now
}

extension AppReviewFeature {

  static func minDateAfterFirstLaunch(_ now: Date) -> Date {
    Calendar.current.date(
      byAdding: .day,
      value: daysAfterFirstLaunchBeforeRequest,
      to: now
    )! // swiftlint:disable:this force_unwrapping
  }

  static func minDateSinceLastReviewRequest(_ now: Date) -> Date {
    Calendar.current.date(
      byAdding: .month,
      value: monthsBetweenReviewRequests,
      to: now
    )! // swiftlint:disable:this force_unwrapping
  }

  static var currentVersion: String { return Bundle.main.releaseVersionNumber }

  private func askForReview(_ state: inout State) -> Effect<Action> {
    @Shared(.lastReviewRequestVersion) var lastReviewRequestVersion

    guard Self.currentVersion != lastReviewRequestVersion else {
      log.debug("same version as last review request")
      return .none
    }

    @Dependency(\.date.now) var now
    @Shared(.nextReviewRequestDate) var nextReviewRequestDate

    if nextReviewRequestDate == .distantPast {
      $nextReviewRequestDate.withLock { $0 = Self.minDateAfterFirstLaunch(now) }
    }

    guard now >= nextReviewRequestDate else {
      log.debug("before next review request date \(nextReviewRequestDate)")
      return .none
    }

    guard state.activityCounter == 1 else {
      state.activityCounter -= 1
      log.debug("too soon after launching")
      return .none
    }

    state.activityCounter = 0
    state.askForReview = true

    $lastReviewRequestVersion.withLock { $0 = Self.currentVersion }
    $nextReviewRequestDate.withLock { $0 = Self.minDateSinceLastReviewRequest(now) }

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

struct AppReviewDemoView: View {
  @State var store = StoreOf<AppReviewFeature>(initialState: AppReviewFeature.State()) { AppReviewFeature() }

  init() {
    prepareDependencies {
      let now = Date(timeIntervalSince1970: 0)
      $0.date.now = now
      @Shared(.nextReviewRequestDate) var nextReviewRequestDate
      $nextReviewRequestDate.withLock { $0 = now }
    }
  }

  var body: some View {
    VStack(spacing: 20) {
      Text("Hello, World!")
        .appReview(store: store)
      Text("\(store.activityCounter) - \(store.askForReview)")
      Button {
        store.send(.ask)
      } label: {
        Text("Ask for review")
      }
    }
  }
}

#Preview {
  AppReviewDemoView()
}
