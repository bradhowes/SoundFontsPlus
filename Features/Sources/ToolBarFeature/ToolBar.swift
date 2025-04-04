import ComposableArchitecture
import Dependencies
import Models
import SwiftUI

@Reducer
public struct ToolBar {

  @ObservableState
  public struct State: Equatable {
    var tagsVisible: Bool = false
    var effectsVisible: Bool = false

    public init() {}
  }

  public enum Action: Equatable {
    case addSoundFontButtonTapped
    case effectsVisibilityButtonTapped
    case tagVisibilityButtonTapped
    case delegate(Delegate)

    @CasePathable
    public enum Delegate: Equatable {
      case addSoundFont
      case setTagVisibility(Bool)
      case setEffectsVisibility(Bool)
    }
  }

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .addSoundFontButtonTapped:
        return .send(.delegate(.addSoundFont))
      case .delegate: return .none
      case .effectsVisibilityButtonTapped:
        state.effectsVisible.toggle()
        return .send(.delegate(.setEffectsVisibility(state.effectsVisible)))
      case .tagVisibilityButtonTapped:
        state.tagsVisible.toggle()
        return .send(.delegate(.setTagVisibility(state.tagsVisible)))
      }
    }
  }

  public init() {}
}

extension ToolBar {

}

public struct ToolBarView: View {
  @Bindable private var store: StoreOf<ToolBar>

  public init(store: StoreOf<ToolBar>) {
    self.store = store
  }

  public var body: some View {
    HStack(alignment: .center, spacing: 12) {
      Button { store.send(.tagVisibilityButtonTapped) } label: { Image(systemName: "plus.circle").imageScale(.large)}
      Button { store.send(.tagVisibilityButtonTapped) } label: { Image(systemName: "tag").imageScale(.large)}
      Button { store.send(.tagVisibilityButtonTapped) } label: { Image(systemName: "waveform").imageScale(.large)}
      Spacer()
      Button { store.send(.tagVisibilityButtonTapped) } label: { Image(systemName: "chevron.left.2").imageScale(.large)}
    }
    .padding(8)
    .frame(height: 40)
    .background(Color.gray.opacity(0.2))
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
