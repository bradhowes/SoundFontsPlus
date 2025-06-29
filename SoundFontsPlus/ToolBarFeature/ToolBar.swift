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

    var lowestKey: Note
    var highestKey: Note

    @Shared(.keyboardSlides) var keyboardSlides

    var tagsListVisible: Bool
    var effectsVisible: Bool

    var editingPresetVisibility: Bool = false
    var showMoreButtons: Bool = false

    public init(tagsListVisible: Bool, effectsVisible: Bool) {
      @Shared(.firstVisibleKey) var firstVisibleKey: Note
      self.tagsListVisible = tagsListVisible
      self.effectsVisible = effectsVisible
      self.lowestKey = firstVisibleKey
      self.highestKey = .C4
    }
  }

  public enum Action: Equatable {
    case addSoundFontButtonTapped
    case delegate(Delegate)
    case destination(PresentationAction<Destination.Action>)
    case effectsVisibilityButtonTapped
    case helpButtonTapped
    case monitorStateChanges
    case shiftKeyboardUpButtonTapped
    case shiftKeyboardDownButtonTapped
    case presetsVisibilityButtonTapped
    case settingsButtonTapped
    case setVisibleKeyRange(lowest: Note, highest: Note)
    case showMoreButtonTapped
    case slidingKeyboardButtonTapped
    case tagVisibilityButtonTapped

    public enum Delegate: Equatable {
      case addSoundFont
      case editingPresetVisibility(Bool)
      case effectsVisibilityChanged(Bool)
      case presetNameTapped
      case tagsVisibilityChanged(Bool)
      case settingsButtonTapped
      case settingsDismissed
      case visibleKeyRangeChanged(lowest: Note, highest: Note)
    }
  }

  @Shared(.firstVisibleKey) var firstVisibleKey: Note

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .addSoundFontButtonTapped: return .send(.delegate(.addSoundFont))
      case .delegate: return .none
      case .destination(.dismiss): return .send(.delegate(.settingsDismissed))
      case .destination: return .none
      case .effectsVisibilityButtonTapped: return toggleEffectsVisibility(&state)
      case .helpButtonTapped: return showHelp(&state)
      case .monitorStateChanges: return monitorStateChanges(&state)
      case .shiftKeyboardDownButtonTapped: return shiftKeyboardDownButtonTapped(&state)
      case .shiftKeyboardUpButtonTapped: return shiftKeyboardUpButtonTapped(&state)
      case .presetsVisibilityButtonTapped: return editPresetVisibility(&state)
      case .settingsButtonTapped: return settingsButtonTapped(&state)
      case let .setVisibleKeyRange(lowest, highest): return setVisibleKeyRange(&state, lowest: lowest, highest: highest)
      case .showMoreButtonTapped: return toggleShowMoreButtons(&state)
      case .slidingKeyboardButtonTapped: return slidingKeyboardButtonTapped(&state)
      case .tagVisibilityButtonTapped: return toggleTagsVisibility(&state)
      }
    }.ifLet(\.$destination, action: \.destination)
  }

  public init() {}
}

extension ToolBar {

  public func monitorStateChanges(_ state: inout State) -> Effect<Action> {
    return .none
  }

  public static func setTagsListVisible(_ state: inout State, value: Bool) {
    state.tagsListVisible = value
  }

  private func setVisibleKeyRange(_ state: inout State, lowest: Note, highest: Note) -> Effect<Action> {
    state.lowestKey = lowest
    state.highestKey = highest
    $firstVisibleKey.withLock { $0 = lowest }
    return .none
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

  private func shiftKeyboardDownButtonTapped(_ state: inout State) -> Effect<Action> {
    let span = state.highestKey.midiNoteValue - state.lowestKey.midiNoteValue
    var newLow = Note(midiNoteValue: max(Note.midiRange.lowerBound, state.lowestKey.midiNoteValue - span))
    if newLow.accented {
      newLow = Note(midiNoteValue: newLow.midiNoteValue - 1)
    }
    let newHigh = Note(midiNoteValue: min(Note.midiRange.upperBound, newLow.midiNoteValue + span))
    $firstVisibleKey.withLock { $0 = newLow }
    state.lowestKey = newLow
    state.highestKey = newHigh
    return .send(.delegate(.visibleKeyRangeChanged(lowest: newLow, highest: newHigh)))
  }

  private func shiftKeyboardUpButtonTapped(_ state: inout State) -> Effect<Action> {
    let span = state.highestKey.midiNoteValue - state.lowestKey.midiNoteValue
    let newHigh = Note(midiNoteValue: min(Note.midiRange.upperBound, state.highestKey.midiNoteValue + span))
    var newLow = Note(midiNoteValue: max(Note.midiRange.lowerBound, newHigh.midiNoteValue - span))
    if newLow.accented {
      newLow = Note(midiNoteValue: newLow.midiNoteValue - 1)
    }
    $firstVisibleKey.withLock { $0 = newLow }
    state.lowestKey = newLow
    state.highestKey = newHigh
    return .send(.delegate(.visibleKeyRangeChanged(lowest: newLow, highest: newHigh)))
  }

  private func hideMoreButtons(_ state: inout State) -> Effect<Action> {
    state.showMoreButtons = false
    return .none
  }

  private func editPresetVisibility(_ state: inout State) -> Effect<Action> {
    state.editingPresetVisibility.toggle()
    return .send(.delegate(.editingPresetVisibility(state.editingPresetVisibility)))
  }

  private func settingsButtonTapped(_ state: inout State) -> Effect<Action> {
    state.showMoreButtons = false
    return .send(.delegate(.settingsButtonTapped))
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
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  public init(store: StoreOf<ToolBar>) {
    self.store = store
  }

  public var body: some View {
    HStack(alignment: .center, spacing: 12) {
      addSoundFontButton
      toggleTagsButton
      toggleEffectsButton
      if horizontalSizeClass == .compact {
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
      } else {
        presetTitle
        moreButtons
      }
    }
    .onAppear {
      store.send(.monitorStateChanges)
    }
    .background(Color.black)
    .padding(.init(top: 8, leading: 8, bottom: 8, trailing: 0))
    .frame(height: 40)
    .animation(.smooth, value: store.showMoreButtons)
  }

  private var presetTitle: some View {
    HStack {
      Spacer()
      PresetNameView(preset: Preset.active)
        .font(.status)
        .indicator(.none)
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
        store.send(.shiftKeyboardDownButtonTapped)
      } label: {
        Text("❰" + store.lowestKey.label)
      }
      .disabled(self.store.lowestKey.midiNoteValue == Note.midiRange.lowerBound)
      Button {
        store.send(.slidingKeyboardButtonTapped)
      } label: {
        Image(
          systemName: store.keyboardSlides
          ? "arrowtriangle.left.and.line.vertical.and.arrowtriangle.right.fill"
          : "arrowtriangle.left.and.line.vertical.and.arrowtriangle.right"
        )
        .tint(store.keyboardSlides ? Color.indigo : Color.blue)
      }
      Button {
        store.send(.shiftKeyboardUpButtonTapped)
      } label: {
        Text(store.highestKey.label + "❱")
      }
      .disabled(self.store.highestKey.midiNoteValue == Note.midiRange.upperBound)
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
    return VStack {
      ToolBarView(store: Store(initialState: .init(tagsListVisible: true, effectsVisible: false)) { ToolBar() })
      KeyboardView(store: Store(initialState: .init()) { KeyboardFeature() })
    }
  }
}

#Preview {
  ToolBarView.preview
}
