// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Controls
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
    public var activeVoiceCount: Int
    public var editingPresetVisibility: Bool
    public var effectsPanelVisible: Bool
    public var fileImporter: FileImporter.State
    public var highestKey: Note
    @ObservationStateIgnored
    @Shared(.keyboardSlides) public var keyboardSlides
    public var lastPlayedKey: Note?
    public var lowestKey: Note
    public var midiTrafficIndicator: MIDITrafficIndicator.State
    public var preset: Preset?
    public var showMoreButtons: Bool
    public var tagsListVisible: Bool
    public var audioUnit: AUAudioUnit?

    public init(
      activeVoiceCount: Int = 0,
      editingPresetVisibility: Bool = false,
      effectsPanelVisible: Bool? = nil,
      fileImporter: FileImporter.State? = nil,
      highestKey: Note? = nil,
      lastPlayedKey: Note? = nil,
      lowestKey: Note? = nil,
      midiTrafficIndicator: MIDITrafficIndicator.State? = nil,
      preset: Preset? = nil,
      showMoreButtons: Bool = false,
      tagsListVisible: Bool? = nil
    ) {
      @Shared(.effectsPanelVisible) var savedEffectsPanelVisible
      @Shared(.firstVisibleKey) var savedLowestKey
      @Shared(.tagsListVisible) var savedTagsListVisible

      self.activeVoiceCount = activeVoiceCount
      self.editingPresetVisibility = editingPresetVisibility
      self.effectsPanelVisible = effectsPanelVisible ?? savedEffectsPanelVisible
      self.fileImporter = fileImporter ?? .init()
      self.highestKey = highestKey ?? .C4
      self.lastPlayedKey = lastPlayedKey
      self.lowestKey = lowestKey ?? savedLowestKey
      self.midiTrafficIndicator = midiTrafficIndicator ?? .init(tag: "ToolBar")
      self.preset = preset
      self.showMoreButtons = showMoreButtons
      self.tagsListVisible = tagsListVisible ?? savedTagsListVisible
    }

    public mutating func setTagsListVisible(_ state: Bool) {
      self.tagsListVisible = state
    }
  }

  public enum Action {
    case activePresetIdChanged(Preset.ID?)
    case activeVoiceCountChanged(Int)
    case addSoundFontButtonTapped
    case audioUnitCreated(AUAudioUnit)
    case deinitialize
    case delegate(Delegate)
    case effectsVisibilityButtonTapped
    case fileImporter(FileImporter.Action)
    case helpButtonTapped
    case initialize
    case midiTrafficIndicator(MIDITrafficIndicator.Action)
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

  @Shared(.showKeyNotes) private var showKeyNotes
  @Shared(.showSolfegeTags) private var showSolfegeTags

  public init() {}

  public var body: some ReducerOf<Self> {

    Scope(state: \.fileImporter, action: \.fileImporter) { FileImporter() }
    Scope(state: \.midiTrafficIndicator, action: \.midiTrafficIndicator) { MIDITrafficIndicator() }

    Reduce<State, Action> { state, action in
      log.info("action: \(action)")

      switch action {

      case .activePresetIdChanged(let presetId):
        return activePresetIdChanged(&state, presetId: presetId)

      case .activeVoiceCountChanged(let count):
        state.activeVoiceCount = count
        return .none

      case .addSoundFontButtonTapped:
        return reduce(into: &state, action: .fileImporter(.showFileImporter))

      case .audioUnitCreated(let audioUnit):
        state.audioUnit = audioUnit
        return monitorActiveVoiceCount(&state)

      case .deinitialize:
        return .merge(CancelId.allCases.map({ .cancel(id: $0) }))

      case .effectsVisibilityButtonTapped:
        return toggleEffectsVisibility(&state)

      case .helpButtonTapped:
        return showHelp(&state)

      case .initialize:
        return initialize(&state)

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

  private enum CancelId: String, CaseIterable {
    case toolBarLastPlayedKeyChanged
    case toolBarMonitorActiveVoiceCount
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

  private func initialize(_ state: inout State) -> Effect<Action> {
    reduce(into: &state, action: .midiTrafficIndicator(.initialize))
  }

  private func monitorActiveVoiceCount(_ state: inout State) -> Effect<Action> {
    guard
      let parameterTree = state.audioUnit?.parameterTree,
      let parameter = parameterTree.parameter(withAddress: SF2.Render.Engine.ParameterAddress.activeVoiceCount.rawValue)
    else {
      log.info("no parameter tree to monitor")
      return .none
    }

    let stream: AsyncStream<AUValue>
    let observerToken: AUParameterObserverToken
    unsafe (observerToken, stream) = parameter.startObserving()

    return .run { send in
      defer {
        unsafe parameter.removeParameterObserver(observerToken)
      }
      for await value in stream {
        if Task.isCancelled { break }
        await send(.activeVoiceCountChanged(Int(value)))
      }
    }.cancellable(id: CancelId.toolBarMonitorActiveVoiceCount, cancelInFlight: true)
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
    .cancellable(id: CancelId.toolBarLastPlayedKeyChanged, cancelInFlight: true)
    .animation(.smooth)
  }

  private func slidingKeyboardButtonTapped(_ state: inout State) -> Effect<Action> {
    state.$keyboardSlides.withLock { $0 = !state.keyboardSlides }
    return .none
  }

  private func toggleEffectsVisibility(_ state: inout State) -> Effect<Action> {
    state.effectsPanelVisible.toggle()
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
    state.showMoreButtons = false
    return .send(.delegate(.tagsListVisibilityChanged(state.tagsListVisible)))
  }
}

public struct ToolBarView: View {
  private var store: StoreOf<ToolBar>
  @Shared(.showActiveVoiceCount) private var showActiveVoiceCount
  @Shared(.showSolfegeTags) private var showSolfegeTags
  @Shared(.isAUv3) private var isAUv3
  @Environment(\.appPanelBackground) private var appPanelBackground
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  public init(store: StoreOf<ToolBar>) {
    self.store = store
  }

  public var body: some View {
    HStack(alignment: .center, spacing: 12) {
      addSoundFontButton
      toggleTagsButton
      if !isAUv3 {
        toggleEffectsButton
      }
      if horizontalSizeClass == .compact {
        ZStack(alignment: .trailing) {
          status
            .zIndex(0)
            .opacity(store.showMoreButtons ? 0.0 : 1.0)
          if store.showMoreButtons {
            moreButtons
              .offset(x: 12)
              .zIndex(1)
              .transition(.move(edge: .trailing))
          }
        }
        toggleMoreButton
          .zIndex(2)
          .offset(x: 4)
      } else {
        status
        moreButtons
          .padding(.trailing, 8)
      }
    }
    .imageScale(.large)
    .background(Color.black)
    .frame(height: 40)
    .frame(maxHeight: 40)
    .animation(.easeInOut, value: store.showMoreButtons)
    .animation(.smooth, value: store.activeVoiceCount)
    .fileImporterFeature(store.scope(state: \.fileImporter, action: \.fileImporter))
    .task {
      await store.send(.initialize).finish()
    }
  }

  private var status: some View {
    ZStack(alignment: .leading) {
      if !isAUv3 {
        MIDITrafficIndicatorView(store: store.scope(state: \.midiTrafficIndicator, action: \.midiTrafficIndicator))
          .zIndex(-99)
      }
      HStack {
        if showActiveVoiceCount {
          voiceCount
            .transition(.slide)
        }
        statusText
        Spacer()
      }
      .animation(.smooth, value: showActiveVoiceCount)
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
    Button {
      store.send(.showMoreButtonTapped)
    } label: {
      Image(systemName: .moreButtonImageName)
        .tint(if: store.showMoreButtons)
        .frame(width: 24)
    }
    .background(.black)
  }

  private var moreButtons: some View {
    HStack(alignment: .center, spacing: 12) {
      if !isAUv3 {
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
      }
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

#if DEBUG

extension ToolBarView {
  static var preview: some View {
    prepareDependencies {
      $0.defaultDatabase = previewDatabase()
    }

    struct Preview: View {
      @Shared(.showActiveVoiceCount) var showActiveVoiceCount
      @State var showMoreButtons: Bool = false

      var body: some View {
        VStack {
          Toggle(
            "Show active voice count",
            isOn: Binding(
              get: { showActiveVoiceCount },
              set: { newValue in $showActiveVoiceCount.withLock { $0 = newValue }}
            )
          )
          Toggle("Show more buttons", isOn: $showMoreButtons)

          ToolBarView(
            store: Store(
              initialState: .init(
                preset: Preset(
                  id: 0,
                  index: 0,
                  bank: 1,
                  program: 1,
                  originalName: "Foo",
                  soundFontId: 0,
                  displayName: "Foo"
                ),
                showMoreButtons: showMoreButtons
              )
            ) {
            ToolBar()
          })
          KeyboardView(store: Store(initialState: .init()) { Keyboard() })
        }
      }
    }

    return Preview()
  }
}

#Preview {
  ToolBarView.preview
}

#endif // DEBUG
