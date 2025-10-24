// Copyright © 2025 Brad Howes. All rights reserved.

import Engine
import FeatureSupport
import Keyboard
import FileImporter
import MIDITrafficIndicator
import Settings

private let log = Logger(category: "ToolBar")

@Reducer
public struct ToolBar {

  @ObservableState
  public struct State: Equatable {
    var lowestKey: Note
    var highestKey: Note

    var keyboardSlides: Bool
    var effectsPanelVisible: Bool
    var tagsListVisible: Bool

    var editingPresetVisibility: Bool = false
    var showMoreButtons: Bool
    var preset: Preset?
    var lastPlayedKey: Note?
    var midiTrafficIndicator: MIDITrafficIndicator.State = .init(tag: "ToolBar")
    var fileImporter: FileImporter.State = .init()
    var activeVoiceCount: Int = 0

    public init(showMoreButtons: Bool = false) {
      @Shared(.firstVisibleKey) var firstVisibleKey: Note
      @Shared(.keyboardSlides) var keyboardSlides: Bool
      @Shared(.effectsPanelVisible) var effectsPanelVisible: Bool
      @Shared(.tagsListVisible) var tagsListVisible: Bool

      self.showMoreButtons = showMoreButtons
      self.lowestKey = firstVisibleKey
      self.highestKey = .C4
      self.keyboardSlides = keyboardSlides
      self.effectsPanelVisible = effectsPanelVisible
      self.tagsListVisible = tagsListVisible
    }

    public mutating func setTagsListVisible(_ state: Bool) {
      self.tagsListVisible = state
    }
  }

  public enum Action {
    case activePresetIdChanged(Preset.ID?)
    case activeVoiceCountChanged(Int)
    case addSoundFontButtonTapped
    case deinitialize
    case delegate(Delegate)
    case effectsVisibilityButtonTapped
    case fileImporter(FileImporter.Action)
    case helpButtonTapped
    case initialize
    case midiTrafficIndicator(MIDITrafficIndicator.Action)
    case monitorActiveVoiceCount
    case presetsVisibilityButtonTapped
    case settingsButtonTapped
    case setVisibleKeyRange(lowest: Note, highest: Note)
    case shiftKeyboardUpButtonTapped
    case shiftKeyboardDownButtonTapped
    case lastPlayedKeyChanged(Note?)
    case showMoreButtonTapped
    case slidingKeyboardButtonTapped
    case tagsListVisibilityButtonTapped

    @CasePathable
    public enum Delegate: Equatable {
      case editingPresetVisibilityChanged(Bool)
      case effectsVisibilityChanged(Bool)
      case presetNameTapped
      case tagsListVisibilityChanged(Bool)
      case settingsButtonTapped
      case visibleKeyRangeChanged(lowest: Note, highest: Note)
    }
  }

  public init() {}

  public var body: some ReducerOf<Self> {

    Scope(state: \.fileImporter, action: \.fileImporter) { FileImporter() }
    Scope(state: \.midiTrafficIndicator, action: \.midiTrafficIndicator) { MIDITrafficIndicator() }

    Reduce<State, Action> { state, action in
      switch action {

      case .activePresetIdChanged(let presetId):
        return activePresetIdChanged(&state, presetId: presetId)

      case .activeVoiceCountChanged(let count):
        state.activeVoiceCount = count
        return .none

      case .addSoundFontButtonTapped:
        return reduce(into: &state, action: .fileImporter(.showFileImporter))

      case .deinitialize:
        return .merge(CancelId.allCases.map({ .cancel(id: $0) }))

      case .effectsVisibilityButtonTapped:
        return toggleEffectsVisibility(&state)

      case .helpButtonTapped:
        return showHelp(&state)

      case .initialize:
        return initialize(&state)

      case .monitorActiveVoiceCount:
        return monitorActiveVoiceCount(&state)

      case .lastPlayedKeyChanged(let key):
        return lastPlayedKeyChanged(&state, key: key)

      case .shiftKeyboardDownButtonTapped:
        return shiftKeyboardDownButtonTapped(&state)

      case .shiftKeyboardUpButtonTapped:
        return shiftKeyboardUpButtonTapped(&state)

      case .presetsVisibilityButtonTapped:
        return editPresetVisibility(&state)

      case .settingsButtonTapped:
        return settingsButtonTapped(&state)

      case let .setVisibleKeyRange(lowest, highest):
        return setVisibleKeyRange(&state, lowest: lowest, highest: highest)

      case .showMoreButtonTapped:
        return toggleShowMoreButtons(&state)

      case .slidingKeyboardButtonTapped:
        return slidingKeyboardButtonTapped(&state)

      case .tagsListVisibilityButtonTapped:
        return toggleTagsListVisibility(&state)

      default:
        return .none
      }
    }
  }

  @Shared(.firstVisibleKey) private var firstVisibleKey: Note
  @Shared(.activeState) private var activeState
  @Shared(.showKeyNotes) private var showKeyNotes
  @Shared(.showSolfegeTags) private var showSolfegeTags

  private enum CancelId: CaseIterable {
    case lastPlayedKeyChanged
    case monitorActiveVoiceCount
  }
}

extension ToolBar {

  private func activePresetIdChanged(_ state: inout State, presetId: Preset.ID?) -> Effect<Action> {
    if let presetId = presetId,
       let preset = Preset.with(id: presetId) {
      state.preset = preset
    } else {
      state.preset = nil
    }
    return .none
  }

  private func editPresetVisibility(_ state: inout State) -> Effect<Action> {
    state.editingPresetVisibility.toggle()
    return .send(.delegate(.editingPresetVisibilityChanged(state.editingPresetVisibility)))
  }

//  private func hideMoreButtons(_ state: inout State) -> Effect<Action> {
//    state.showMoreButtons = false
//    return .none.animation(.smooth)
//  }

  private func initialize(_ state: inout State) -> Effect<Action> {
    reduce(into: &state, action: .midiTrafficIndicator(.initialize))
  }

  private func monitorActiveVoiceCount(_ state: inout State) -> Effect<Action> {
    @Shared(.synthAudioUnit) var synthAudioUnit
    guard let parameterTree = synthAudioUnit?.auAudioUnit.parameterTree else {
      fatalError("unexpected nil parameterTree chain")
    }

    guard
      let node = parameterTree.parameter(withAddress: SF2.Render.Engine.ParameterAddress.activeVoiceCount.rawValue)
    else {
      fatalError("did not find activeVoiceCount parameter")
    }

    return .publisher {
      node.publisher(for: \.value)
        .buffer(size: 1, prefetch: .byRequest, whenFull: .dropOldest)
        .removeDuplicates()
        .map {
          .activeVoiceCountChanged(Int($0))
        }
    }.cancellable(id: CancelId.monitorActiveVoiceCount)
  }

  private func settingsButtonTapped(_ state: inout State) -> Effect<Action> {
    state.showMoreButtons = false
    return .send(.delegate(.settingsButtonTapped))
  }

  private func setVisibleKeyRange(_ state: inout State, lowest: Note, highest: Note) -> Effect<Action> {
    state.lowestKey = lowest
    state.highestKey = highest
    return .none
  }

  private func shiftKeyboardDownButtonTapped(_ state: inout State) -> Effect<Action> {
    let span = state.highestKey.midiNoteValue - state.lowestKey.midiNoteValue
    var newLow = Note(midiNoteValue: max(Note.midiRange.lowerBound, state.lowestKey.midiNoteValue - span))
    if newLow.accented {
      newLow = Note(midiNoteValue: newLow.midiNoteValue - 1)
    }
    let newHigh = Note(midiNoteValue: min(Note.midiRange.upperBound, newLow.midiNoteValue + span))
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
    state.lowestKey = newLow
    state.highestKey = newHigh
    return .send(.delegate(.visibleKeyRangeChanged(lowest: newLow, highest: newHigh)))
  }

  private func showHelp(_ state: inout State) -> Effect<Action> {
    return .none
  }

  private func lastPlayedKeyChanged(_ state: inout State, key: Note?) -> Effect<Action> {
    guard showKeyNotes || showSolfegeTags else { return .none }

    guard let key else {
      log.info("cleared lastPlayedKey")
      state.lastPlayedKey = nil
      return .none.animation(.smooth)
    }

    state.lastPlayedKey = key
    log.info("lastPlayedKey - \(key.label)")

    return .run { send in
      @Dependency(\.continuousClock) var clock
      try await clock.sleep(for: .seconds(1.8))
      log.info("clearing lastPlayedKey")
      await send(.lastPlayedKeyChanged(nil))
    }
    .cancellable(id: CancelId.lastPlayedKeyChanged, cancelInFlight: true)
    .animation(.smooth)
  }

  private func slidingKeyboardButtonTapped(_ state: inout State) -> Effect<Action> {
    state.keyboardSlides.toggle()
    @Shared(.keyboardSlides) var keyboardSlides
    $keyboardSlides.withLock { $0 = state.keyboardSlides }
    return .none
  }

  private func toggleEffectsVisibility(_ state: inout State) -> Effect<Action> {
    state.effectsPanelVisible.toggle()
    @Shared(.effectsPanelVisible) var effectsPanelVisible
    $effectsPanelVisible.withLock { $0 = state.effectsPanelVisible }
    state.showMoreButtons = false
    return .send(.delegate(.effectsVisibilityChanged(state.effectsPanelVisible)))
  }

  private func toggleShowMoreButtons(_ state: inout State) -> Effect<Action> {
    state.showMoreButtons.toggle()
    if !state.showMoreButtons && state.editingPresetVisibility {
      state.editingPresetVisibility = false
      return .send(.delegate(.editingPresetVisibilityChanged(false)))
    }
    return .none.animation(.smooth)
  }

  private func toggleTagsListVisibility(_ state: inout State) -> Effect<Action> {
    state.tagsListVisible.toggle()
    @Shared(.tagsListVisible) var tagsListVisible
    $tagsListVisible.withLock { $0 = state.tagsListVisible }
    state.showMoreButtons = false
    return .send(.delegate(.tagsListVisibilityChanged(state.tagsListVisible)))
  }
}

public struct ToolBarView: View {
  private var store: StoreOf<ToolBar>
  @Shared(.showActiveVoiceCount) private var showActiveVoiceCount
  @Shared(.showSolfegeTags) private var showSolfegeTags
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
          status
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
        status
        moreButtons
          .padding(.trailing, 8)
      }
    }
    .imageScale(.large)
    .padding([.top, .bottom, .leading], 4)
    .background(Color.black)
    .frame(maxHeight: 40)
    .animation(.smooth, value: store.showMoreButtons)
    .animation(.smooth, value: store.activeVoiceCount)
    .fileImporterFeature(store.scope(state: \.fileImporter, action: \.fileImporter))
    .task {
      await store.send(.initialize).finish()
    }
  }

  private var status: some View {
    ZStack(alignment: .leading) {
      MIDITrafficIndicatorView(store: store.scope(state: \.midiTrafficIndicator, action: \.midiTrafficIndicator))
        .zIndex(-99)
      HStack {
        if showActiveVoiceCount {
          voiceCount
        }
        Spacer()
        statusText
        Spacer()
      }
    }
  }

  private var voiceCount: some View {
    Text(store.activeVoiceCount > 0 ? "\(store.activeVoiceCount)" : "")
      .font(.activeVoiceCount)
      .indicator(.activeNoIndicator)
      .contentTransition(.interpolate)
      .frame(width: 24, alignment: .center)
  }

  private var statusText: some View {
    Text(store.lastPlayedKey?.fullLabel(withSolfege: showSolfegeTags) ?? store.preset?.displayName ?? "—")
      .font(.status)
      .foregroundStyle(store.preset?.kind == .favorite ? Color.orange : Color.accentColor)
      .indicator(.activeNoIndicator)
      .contentTransition(.interpolate)
      .onTapGesture {
        store.send(.delegate(.presetNameTapped))
      }
  }

  private var addSoundFontButton: some View {
    Button {
      store.send(.addSoundFontButtonTapped)
    } label: {
      Image(systemName: .addSoundFontButtonImageName)
    }
  }

  private var toggleTagsButton: some View {
    Button {
      store.send(.tagsListVisibilityButtonTapped)
    } label: {
      Image(systemName: .tagsListButtonImageName)
        .tint(if: store.tagsListVisible)
    }
  }

  private var toggleEffectsButton: some View {
    Button {
      store.send(.effectsVisibilityButtonTapped)
    } label: {
      Image(systemName: .effectsButtonImageName)
        .tint(if: store.effectsPanelVisible)
    }
  }

  private var toggleMoreButton: some View {
    HStack(spacing: 0) {
      Button { store.send(.showMoreButtonTapped) } label: {
        Image(systemName: .moreButtonImageName).imageScale(.large)
          .tint(if: store.showMoreButtons)
      }
      Color.black
        .frame(width: 4)
    }
    .background(.black)
  }

  private var moreButtons: some View {
    HStack {
      Spacer()
      Button {
        store.send(.shiftKeyboardDownButtonTapped)
      } label: {
        Text(.shiftKeyboardLeftIndicator + store.lowestKey.label)
      }
      .disabled(self.store.lowestKey.midiNoteValue == Note.midiRange.lowerBound)
      Button {
        store.send(.slidingKeyboardButtonTapped)
      } label: {
        Image(
          systemName: store.keyboardSlides
          ? .slidingKeyboardButtonImageName
          : .fixedKeyboardButtonImageName
        )
        .tint(if: store.keyboardSlides)
      }
      Button {
        store.send(.shiftKeyboardUpButtonTapped)
      } label: {
        Text(store.highestKey.label + .shiftKeyboardRightIndicator)
      }
      .disabled(self.store.highestKey.midiNoteValue == Note.midiRange.upperBound)
      Button {
        store.send(.presetsVisibilityButtonTapped)
      } label: {
        Image(systemName: .presetsVisibilityButtonImageName)
          .tint(if: store.editingPresetVisibility)
      }
      Button {
        store.send(.settingsButtonTapped)
      } label: {
        Image(systemName: .settingsButtonImageName)
      }
      Button {
        store.send(.helpButtonTapped)
      } label: {
        Image(systemName: .helpButtonImageName)
      }
    }
    .background(.black)
  }
}

extension ToolBarView {
  static var preview: some View {
    prepareDependencies {
      // swiftlint:disable:next force_try
      $0.defaultDatabase = try! appDatabase()
    }
    return VStack {
      ToolBarView(store: Store(initialState: .init()) {
        ToolBar()
      })
      KeyboardView(store: Store(initialState: .init()) { Keyboard() })
      ToolBarView(store: Store(initialState: .init(showMoreButtons: true)) {
        ToolBar()
      })
    }
  }
}

#Preview {
  ToolBarView.preview
}
