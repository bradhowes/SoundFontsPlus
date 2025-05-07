import AUv3Controls
import ComposableArchitecture
import Dependencies
import Extensions
import Models
import Sharing
import SwiftUI
import SwiftUISupport
import Utils

@Reducer
public struct ToolBar {

  @ObservableState
  public struct State: Equatable {
    public var lowestKey: Note = .init(midiNoteValue: 64)
    public var highestKey: Note = .init(midiNoteValue: 80)
    public var tagsListVisible: Bool = false
    public var effectsVisible: Bool = false
    public var editingPresetVisibility: Bool = false
    public var showMoreButtons: Bool = false

    public init() {}
  }

  public enum Action: Equatable {
    case addSoundFontButtonTapped
    case delegate(Delegate)
    case effectsVisibilityButtonTapped
    case showMoreButtonTapped
    case tagVisibilityButtonTapped
    case lowerKeyButtonTapped
    case slidingKeyboardButtonTapped
    case upperKeyButtonTapped
    case presetsVisibilityButtonTapped
    case settingsButtonTapped
    case helpButtonTapped

    @CasePathable
    public enum Delegate: Equatable {
      case addSoundFont
      case editingPresetVisibility
    }
  }

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .addSoundFontButtonTapped: return .send(.delegate(.addSoundFont))
      case .delegate: return .none
      case .effectsVisibilityButtonTapped: return toggleEffectsVisibility(&state)
      case .showMoreButtonTapped: return toggleShowMoreButtons(&state)
      case .tagVisibilityButtonTapped: return toggleTagsVisibility(&state)
      case .lowerKeyButtonTapped: return .none
      case .upperKeyButtonTapped: return .none
      case .slidingKeyboardButtonTapped: return .none
      case .presetsVisibilityButtonTapped: return editPresetVisibility(&state)
      case .settingsButtonTapped: return showSettings(&state)
      case .helpButtonTapped: return showHelp(&state)
      }
    }
  }

  public init() {}
}

extension ToolBar {
  private func toggleEffectsVisibility(_ state: inout State) -> Effect<Action> {
    state.effectsVisible.toggle()
    return hideMoreButtons(&state)
  }

  private func toggleShowMoreButtons(_ state: inout State) -> Effect<Action> {
    state.showMoreButtons.toggle()
    if !state.showMoreButtons && state.editingPresetVisibility {
      state.editingPresetVisibility = false
      return .send(.delegate(.editingPresetVisibility))
    }
    return .none
  }

  private func toggleTagsVisibility(_ state: inout State) -> Effect<Action> {
    state.tagsListVisible.toggle()
    return hideMoreButtons(&state)
  }

  private func hideMoreButtons(_ state: inout State) -> Effect<Action> {
    state.showMoreButtons = false
    return .none
  }

  private func editPresetVisibility(_ state: inout State) -> Effect<Action> {
    state.editingPresetVisibility.toggle()
    print("toolBar.editPresetVisibility:", state.editingPresetVisibility)
    return .send(.delegate(.editingPresetVisibility))
  }

  private func showSettings(_ state: inout State) -> Effect<Action> {
    return hideMoreButtons(&state)
  }

  private func showHelp(_ state: inout State) -> Effect<Action> {
    return hideMoreButtons(&state)
  }
}

public struct ToolBarView: View {
  @Bindable private var store: StoreOf<ToolBar>
  @Shared(.activeState) var activeState
  @Environment(\.appPanelBackground) private var appPanelBackground
  @Environment(\.auv3ControlsTheme) private var auv3ControlsTheme

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
          .tint(store.tagsListVisible ? Color.indigo : Color.blue)
      }
      Button {
        store.send(.effectsVisibilityButtonTapped)
      } label: {
        Image(systemName: "waveform").imageScale(.large)
          .tint(store.effectsVisible ? Color.indigo : Color.blue)
      }
      ZStack {
        HStack {
          Spacer()
          Text(Operations.activePresetName())
            .font(auv3ControlsTheme.font)
            .foregroundStyle(auv3ControlsTheme.textColor)
          Spacer()
        }.zIndex(0)
        if store.showMoreButtons {
          HStack {
            Spacer()
            Button { } label: { Text("❰" + store.lowestKey.label) }
            Button { } label: { Text("➠") }
            Button { } label: { Text(store.highestKey.label + "❱") }
            Button { } label: { Image(systemName: "gear").imageScale(.large) }
            Button {
              store.send(.presetsVisibilityButtonTapped)
            } label: {
              Image(systemName: "list.bullet").imageScale(.large)
                .tint(store.editingPresetVisibility ? Color.indigo : Color.blue)
            }
            Button { } label: { Image(systemName: "questionmark.circle").imageScale(.large) }
          }
          .background(.black)
          .zIndex(1)
          .transition(.move(edge: .trailing))
        }
      }
      HStack {
        Button { store.send(.showMoreButtonTapped) } label: {
          Image(systemName: "chevron.left").imageScale(.large)
            .tint(store.showMoreButtons ? Color.indigo : Color.blue)
        }
        Color.black
          .frame(width: 4)
      }
      .zIndex(2)
      .background(.black)
    }
    .padding(.init(top: 8, leading: 8, bottom: 8, trailing: 0))
    .frame(height: 40)
    .background(Color.black)
    .animation(.smooth, value: store.showMoreButtons)
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
