import AUv3Controls
import ComposableArchitecture
import Dependencies
import Extensions
import KeyboardFeature
import Models
import SettingsFeature
import Sharing
import SwiftUI
import SwiftUISupport
import Utils

@Reducer
public struct ToolBar {

  @Reducer(state: .equatable, .sendable, action: .equatable)
  public enum Destination {
    case settings(SettingsFeature)
  }

  @ObservableState
  public struct State: Equatable {
    @Presents var destination: Destination.State?

    @Shared(.lowestKey) public var lowestKey
    @Shared(.highestKey) public var highestKey
    @Shared(.keyboardSlides) public var keyboardSlides

    public var tagsListVisible: Bool = false
    public var effectsVisible: Bool = false
    public var editingPresetVisibility: Bool = false
    public var showMoreButtons: Bool = false

    public init(tagsListVisible: Bool, effectsVisible: Bool) {
      self.tagsListVisible = tagsListVisible
      self.effectsVisible = effectsVisible
    }
  }

  public enum Action: Equatable {
    case addSoundFontButtonTapped
    case delegate(Delegate)
    case destination(PresentationAction<Destination.Action>)
    case effectsVisibilityButtonTapped
    case showMoreButtonTapped
    case tagVisibilityButtonTapped
    case lowestKeyButtonTapped
    case slidingKeyboardButtonTapped
    case highestKeyButtonTapped
    case presetsVisibilityButtonTapped
    case settingsButtonTapped
    case helpButtonTapped

    public enum Delegate: Equatable {
      case addSoundFont
      case editingPresetVisibility
      case presetNameTapped
      case effectsVisibilityChanged(Bool)
      case tagsVisibilityChanged(Bool)
    }
  }

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .addSoundFontButtonTapped: return .send(.delegate(.addSoundFont))
      case .delegate: return .none
      case .destination(.dismiss): return .none
      case .destination: return .none
      case .effectsVisibilityButtonTapped: return toggleEffectsVisibility(&state)
      case .showMoreButtonTapped: return toggleShowMoreButtons(&state)
      case .tagVisibilityButtonTapped: return toggleTagsVisibility(&state)
      case .lowestKeyButtonTapped: return lowestKeyButtonTapped(&state)
      case .highestKeyButtonTapped: return highestKeyButtonTapped(&state)
      case .slidingKeyboardButtonTapped: return slidingKeyboardButtonTapped(&state)
      case .presetsVisibilityButtonTapped: return editPresetVisibility(&state)
      case .settingsButtonTapped: return showSettings(&state)
      case .helpButtonTapped: return showHelp(&state)
      }
    }.ifLet(\.$destination, action: \.destination)
  }

  public init() {}
}

extension ToolBar {
  private func toggleEffectsVisibility(_ state: inout State) -> Effect<Action> {
    state.effectsVisible.toggle()
    state.showMoreButtons = false
    return .send(.delegate(.effectsVisibilityChanged(state.effectsVisible)))
  }

  private func toggleShowMoreButtons(_ state: inout State) -> Effect<Action> {
    state.showMoreButtons.toggle()
    if !state.showMoreButtons && state.editingPresetVisibility {
      state.editingPresetVisibility = false
      return .send(.delegate(.editingPresetVisibility))
    }
    return .none
  }

  private func slidingKeyboardButtonTapped(_ state: inout State) -> Effect<Action> {
    state.$keyboardSlides.withLock { $0.toggle() }
    return .none
  }

  private func lowestKeyButtonTapped(_ state: inout State) -> Effect<Action> {
    // return .send(.delegate(.keyRangeChanged(lowest: state.lowestKey, highest: state.highestKey)))
    return .none
  }

  private func highestKeyButtonTapped(_ state: inout State) -> Effect<Action> {
    // return .send(.delegate(.keyRangeChanged(lowest: state.lowestKey, highest: state.highestKey)))
    return .none
  }

  private func toggleTagsVisibility(_ state: inout State) -> Effect<Action> {
    state.tagsListVisible.toggle()
    state.showMoreButtons = false
    return .send(.delegate(.tagsVisibilityChanged(state.tagsListVisible)))
  }

  private func hideMoreButtons(_ state: inout State) -> Effect<Action> {
    state.showMoreButtons = false
    return .none
  }

  private func editPresetVisibility(_ state: inout State) -> Effect<Action> {
    state.editingPresetVisibility.toggle()
    return .send(.delegate(.editingPresetVisibility))
  }

  private func showSettings(_ state: inout State) -> Effect<Action> {
    state.destination = .settings(SettingsFeature.State())
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
      addSoundFontButton
      toggleTagsButton
      toggleEffectsButton
      ZStack {
        presetTitle
          .zIndex(0)
        if store.showMoreButtons {
          moreButtons
            .zIndex(1)
            .transition(.move(edge: .trailing))
        }
      }
      toggleMoreButton
        .zIndex(2)
    }
    .background(Color.black)
    .padding(.init(top: 8, leading: 8, bottom: 8, trailing: 0))
    .frame(height: 40)
    .animation(.smooth, value: store.showMoreButtons)
    .popover(
      item: $store.scope(state: \.destination?.settings, action: \.destination.settings)) { store in
        SettingsView(store: store)
      }
//    .sheet(item: $store.scope(state: \.destination?.settings, action: \.destination.settings)) { settings in
//      NavigationStack {
//        SettingsView(store: settings)
//      }
  }

  private var presetTitle: some View {
    HStack {
      Spacer()
      Text(Operations.activePresetName())
        .font(auv3ControlsTheme.font)
        .foregroundStyle(auv3ControlsTheme.textColor)
        .onTapGesture {
          store.send(.delegate(.presetNameTapped))
        }
      Spacer()
    }
  }

  private var addSoundFontButton: some View {
    Button {
      store.send(.addSoundFontButtonTapped)
    } label: {
      Image(systemName: "plus.circle").imageScale(.large)
    }
  }

  private var toggleTagsButton: some View {
    Button {
      store.send(.tagVisibilityButtonTapped)
    } label: {
      Image(systemName: "tag").imageScale(.large)
        .tint(store.tagsListVisible ? Color.indigo : Color.blue)
    }
  }

  private var toggleEffectsButton: some View {
    Button {
      store.send(.effectsVisibilityButtonTapped)
    } label: {
      Image(systemName: "waveform").imageScale(.large)
        .tint(store.effectsVisible ? Color.indigo : Color.blue)
    }
  }

  private var toggleMoreButton: some View {
    HStack {
      Button { store.send(.showMoreButtonTapped) } label: {
        Image(systemName: "chevron.left").imageScale(.large)
          .tint(store.showMoreButtons ? Color.indigo : Color.blue)
      }
      Color.black
        .frame(width: 4)
    }.background(.black)
  }

  private var moreButtons: some View {
    HStack {
      Spacer()
      Button {
        store.send(.lowestKeyButtonTapped)
      } label: {
        Text("❰" + store.lowestKey.label)
      }
      Button {
        store.send(.slidingKeyboardButtonTapped)
      } label: {
        Image(systemName: store.keyboardSlides ? "arrow.left.and.right.circle.fill" : "arrow.left.and.right" )
          .tint(store.keyboardSlides ? Color.indigo : Color.blue)
      }
      Button {
        store.send(.highestKeyButtonTapped)
      } label: {
        Text(store.highestKey.label + "❱")
      }
      Button {
        store.send(.settingsButtonTapped)
      } label: {
        Image(systemName: "gear").imageScale(.large)
      }
      Button {
        store.send(.presetsVisibilityButtonTapped)
      } label: {
        Image(systemName: "list.bullet").imageScale(.large)
          .tint(store.editingPresetVisibility ? Color.indigo : Color.blue)
      }
      Button {
        store.send(.helpButtonTapped)
      } label: {
        Image(systemName: "questionmark.circle").imageScale(.large)
      }
    }
    .background(.black)
  }
}

extension ToolBarView {
  static var preview: some View {
    let _ = prepareDependencies {
      $0.defaultDatabase = try! .appDatabase()
    }
    @Dependency(\.defaultDatabase) var db
    return ToolBarView(store: Store(initialState: .init(tagsListVisible: false, effectsVisible: false)) { ToolBar() })
  }
}

#Preview {
  ToolBarView.preview
}
