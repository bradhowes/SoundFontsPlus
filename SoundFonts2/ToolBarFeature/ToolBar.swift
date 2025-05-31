import AUv3Controls
import ComposableArchitecture
import Dependencies
import Sharing
import SwiftUI

@Reducer
public struct ToolBar {

  @Reducer(state: .equatable, .sendable, action: .equatable)
  public enum Destination {
    case settings(SettingsFeature)
  }

  @ObservableState
  public struct State: Equatable {
    @Presents var destination: Destination.State?

    @Shared(.firstVisibleKey) var lowestKey
    var highestKey: Note = .C4
    @Shared(.keyboardSlides) var keyboardSlides

    var tagsListVisible: Bool
    var effectsVisible: Bool

    var editingPresetVisibility: Bool = false
    var showMoreButtons: Bool = false

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
    case helpButtonTapped
    case highestKeyButtonTapped
    case lowestKeyButtonTapped
    case presetsVisibilityButtonTapped
    case settingsButtonTapped
    case showMoreButtonTapped
    case slidingKeyboardButtonTapped
    case tagVisibilityButtonTapped

    public enum Delegate: Equatable {
      case addSoundFont
      case editingPresetVisibility(Bool)
      case effectsVisibilityChanged(Bool)
      case presetNameTapped
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
      case .helpButtonTapped: return showHelp(&state)
      case .highestKeyButtonTapped: return highestKeyButtonTapped(&state)
      case .lowestKeyButtonTapped: return lowestKeyButtonTapped(&state)
      case .presetsVisibilityButtonTapped: return editPresetVisibility(&state)
      case .settingsButtonTapped: return showSettings(&state)
      case .showMoreButtonTapped: return toggleShowMoreButtons(&state)
      case .slidingKeyboardButtonTapped: return slidingKeyboardButtonTapped(&state)
      case .tagVisibilityButtonTapped: return toggleTagsVisibility(&state)
      }
    }.ifLet(\.$destination, action: \.destination)
  }

  public init() {}
}

extension ToolBar {

  public static func setTagsListVisible(_ state: inout State, value: Bool) {
    state.tagsListVisible = value
  }

  private func toggleTagsVisibility(_ state: inout State) -> Effect<Action> {
    state.tagsListVisible.toggle()
    state.showMoreButtons = false
    return .send(.delegate(.tagsVisibilityChanged(state.tagsListVisible)))
  }

  private func toggleEffectsVisibility(_ state: inout State) -> Effect<Action> {
    state.effectsVisible.toggle()
    state.showMoreButtons = false
    return .send(.delegate(.effectsVisibilityChanged(state.effectsVisible)))
  }

  private func toggleShowMoreButtons(_ state: inout State) -> Effect<Action> {
    state.showMoreButtons.toggle()
    if !state.showMoreButtons && state.editingPresetVisibility {
      state.editingPresetVisibility = false
      return .send(.delegate(.editingPresetVisibility(false)))
    }
    return .none
  }

  private func slidingKeyboardButtonTapped(_ state: inout State) -> Effect<Action> {
    @Shared(.keyboardSlides) var keyboardSlides
    state.$keyboardSlides.withLock { $0.toggle() }
    $keyboardSlides.withLock { $0 = state.keyboardSlides }
    return .none
  }

  private func lowestKeyButtonTapped(_ state: inout State) -> Effect<Action> {
    let span = state.highestKey.midiNoteValue - state.lowestKey.midiNoteValue
    // Move to the next lower C key
    let newLow = state.lowestKey.noteIndex == 0
    ? Note(midiNoteValue: max(Note.midiRange.lowerBound, state.lowestKey.midiNoteValue - span))
    : Note(midiNoteValue: state.lowestKey.midiNoteValue - (state.lowestKey.midiNoteValue % 12))
    let newHigh = Note(midiNoteValue: min(Note.midiRange.upperBound, newLow.midiNoteValue + span))
    state.$lowestKey.withLock { $0 = newLow }
    state.highestKey = newHigh
    return .none
  }

  private func highestKeyButtonTapped(_ state: inout State) -> Effect<Action> {
    let span = state.highestKey.midiNoteValue - state.lowestKey.midiNoteValue
    let newHigh = Note(midiNoteValue: min(Note.midiRange.upperBound, state.highestKey.midiNoteValue + span))
    let newLow = Note(midiNoteValue: max(Note.midiRange.lowerBound, newHigh.midiNoteValue - span))
    if state.lowestKey.noteIndex != 0 && newLow.noteIndex != 0 {
      state.$lowestKey.withLock { $0 = Note(midiNoteValue: newLow.midiNoteValue - newLow.noteIndex) }
      state.highestKey = Note(midiNoteValue: newHigh.midiNoteValue - newLow.noteIndex)
    } else {
      state.$lowestKey.withLock { $0 = newLow }
      state.highestKey = newHigh
    }
    return .none
  }

  private func hideMoreButtons(_ state: inout State) -> Effect<Action> {
    state.showMoreButtons = false
    return .none
  }

  private func editPresetVisibility(_ state: inout State) -> Effect<Action> {
    state.editingPresetVisibility.toggle()
    return .send(.delegate(.editingPresetVisibility(state.editingPresetVisibility)))
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
      Text(Preset.active?.displayName ?? "-")
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
      }.disabled(store.lowestKey.midiNoteValue == Note.midiRange.lowerBound)
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
      }.disabled(store.highestKey.midiNoteValue == Note.midiRange.upperBound)
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
      $0.defaultDatabase = try! appDatabase()
    }
    @Dependency(\.defaultDatabase) var db
    return ToolBarView(store: Store(initialState: .init(tagsListVisible: true, effectsVisible: false)) { ToolBar() })
  }
}

#Preview {
  ToolBarView.preview
}
