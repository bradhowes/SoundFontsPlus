// Copyright © 2025 Brad Howes. All rights reserved.

public import CasePaths
public import ComposableArchitecture
import FeatureSupport

@Reducer
public struct Tutorial {

  public enum Page: Int, CaseIterable {
    case intro = 1
    case fonts
    case presets
    case favorites
    case tags
    case toolbar1
    case toolbar2
    case reverb
    case delay
    case settings
    case last

    var prev: Page { .init(rawValue: self.rawValue - 1) ?? .intro }
    var next: Page { .init(rawValue: self.rawValue + 1) ?? .last }
  }

  @ObservableState
  public struct State: Equatable {
    public var page: Page

    public init(page: Page = .intro) {
      self.page = page
    }
  }

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case dismissButtonTapped
    case next
    case page(Page)
    case prev
  }

  public static var shouldShow: Bool {
    @Shared(.showedTutorial) var showedTutorial
    return !showedTutorial
  }

  public init() {}

  @Dependency(\.dismiss) var dismiss

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding: .none
      case .dismissButtonTapped: .run { [dismiss] _ in await dismiss() }
      case .next: nextButtonTapped(&state)
      case .page(let value): pageTapped(&state, page: value)
      case .prev: previousButtonTapped(&state)
      }
    }
  }
}

extension Tutorial {

  private func nextButtonTapped(_ state: inout State) -> Effect<Action> {
    state.page = state.page.next
    return .none
  }

  private func pageTapped(_ state: inout State, page: Page) -> Effect<Action> {
    state.page = page
    return .none
  }

 private func previousButtonTapped(_ state: inout State) -> Effect<Action> {
    state.page = state.page.prev
    return .none
  }
}
