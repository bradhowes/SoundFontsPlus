import ComposableArchitecture
import Dependencies
import Models
import Sharing
import SwiftUI

@Reducer
public struct ToolBar {

  @ObservableState
  public struct State: Equatable {
    @Shared(.tagsListVisible) public var tagsListVisible
    @Shared(.effectsVisible) public var effectsVisible

    public init() {}
  }

  public enum Action: Equatable {
    case addSoundFontButtonTapped
    case delegate(Delegate)
    case effectsVisibilityButtonTapped
    case showMoreButtonTapped
    case tagVisibilityButtonTapped

    @CasePathable
    public enum Delegate: Equatable {
      case addSoundFont
    }
  }

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .addSoundFontButtonTapped: return .send(.delegate(.addSoundFont))
      case .delegate: return .none
      case .effectsVisibilityButtonTapped: return toggleEffectsVisibility(&state)
      case .showMoreButtonTapped: return .none
      case .tagVisibilityButtonTapped: return toggleTagVisibility(&state)
      }
    }
  }

  public init() {}
}

private extension ToolBar {

  func toggleEffectsVisibility(_ state: inout State) -> Effect<Action> {
    state.$effectsVisible.withLock { $0.toggle() }
    return .none
  }

  func toggleTagVisibility(_ state: inout State) -> Effect<Action> {
    state.$tagsListVisible.withLock { $0.toggle() }
    return .none
  }
}

public struct ToolBarView: View {
  @Bindable private var store: StoreOf<ToolBar>

  public init(store: StoreOf<ToolBar>) {
    self.store = store
  }

  public var body: some View {
    HStack(alignment: .center, spacing: 12) {
      Button { store.send(.addSoundFontButtonTapped) } label: { Image(systemName: "plus.circle").imageScale(.large)}
      Button {
        store.send(.tagVisibilityButtonTapped)
      } label: {
        Image(systemName: "tag").imageScale(.large)
          .tint(store.tagsListVisible ? Color.orange : Color.blue)
      }
      Button {
        store.send(.effectsVisibilityButtonTapped)
      } label: {
        Image(systemName: "waveform").imageScale(.large)
          .tint(store.effectsVisible ? Color.orange : Color.blue)
      }
      Spacer()
      Button { store.send(.tagVisibilityButtonTapped) } label: { Image(systemName: "chevron.left.2").imageScale(.large)}
    }
    .padding(8)
    .frame(height: 40)
    .background(Color(red: 0.08, green: 0.08, blue: 0.08))
  }
}

extension ToolBarView {
  static var preview: some View {
    let _ = prepareDependencies {
      $0.defaultDatabase = try! .appDatabase()
    }
    @Dependency(\.defaultDatabase) var db
    return ToolBarView(store: Store(initialState: .init()) { ToolBar() })
  }
}

#Preview {
  ToolBarView.preview
}
