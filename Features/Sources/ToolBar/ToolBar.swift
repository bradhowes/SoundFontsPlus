// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Controls
import Engine
import FeatureSupport
import Keyboard
import FileImporter
import MIDITrafficIndicator
import Settings

private let log: Logger = .init(category: "ToolBar")

/**
 The ToolBar feature manages a strip above the keyboard that hosts control buttons and a status display. For horizontally compact
 displays, there is a "more" button on the right-hand side that, when touched, reveals additional controls.
 */
@Reducer
public struct ToolBar {
  public static let temporaryStatusDisplayDuration: Duration = .seconds(1.8)

  public enum TemporaryStatus: Equatable {

    case lastPlayedKey(String)
    case panic
    case startup

    var text: String {
      switch self {
      case .lastPlayedKey(let status): return status
      case .panic: return "😱 PANIC - all notes off"
      case .startup: return "Initializing…"
      }
    }
  }

  @ObservableState
  public struct State: Equatable {
    public var activeVoiceCount: Int
    public var editingPresetVisibility: Bool
    @Shared(.effectsPanelVisible) public var effectsPanelVisible: Bool
    public var fileImporter: FileImporter.State
    public var highestKey: Note
    @ObservationStateIgnored
    @Shared(.keyboardSlides) public var keyboardSlides
    public var temporaryStatus: TemporaryStatus?
    public var lowestKey: Note
    public var midiTrafficIndicator: MIDITrafficIndicator.State
    public var preset: Preset?
    public var showMoreButtons: Bool
    @Shared(.tagsListVisible) public var tagsListVisible

    public init(
      activeVoiceCount: Int = 0,
      editingPresetVisibility: Bool = false,
      effectsPanelVisible: Bool? = nil,
      fileImporter: FileImporter.State? = nil,
      highestKey: Note? = nil,
      temporaryStatus: TemporaryStatus? = nil,
      lowestKey: Note? = nil,
      midiTrafficIndicator: MIDITrafficIndicator.State? = nil,
      preset: Preset? = nil,
      showMoreButtons: Bool = false,
      tagsListVisible: Bool? = nil
    ) {
      @Shared(.firstVisibleKey) var savedLowestKey

      self.activeVoiceCount = activeVoiceCount
      self.editingPresetVisibility = editingPresetVisibility
      self.fileImporter = fileImporter ?? .init()
      self.highestKey = highestKey ?? .C4
      self.temporaryStatus = temporaryStatus
      self.lowestKey = lowestKey ?? savedLowestKey
      self.midiTrafficIndicator = midiTrafficIndicator ?? .init(tag: "ToolBar")
      self.preset = preset
      self.showMoreButtons = showMoreButtons
      self.temporaryStatus = .startup

      if let effectsPanelVisible {
        self.$effectsPanelVisible.withLock { $0 = effectsPanelVisible }
      }

      if let tagsListVisible {
        self.$tagsListVisible.withLock { $0 = tagsListVisible }
      }
    }
  }

  public enum Action {
    case activePresetIdChanged(Preset.ID?)
    case activeVoiceCountChanged(Int)
    case addSoundFontButtonTapped
    case audioUnitCreated(AVAudioUnit)
    case clearTemporaryStatus
    case deinitialize
    case delegate(Delegate)
    case effectsVisibilityButtonTapped
    case fileImporter(FileImporter.Action)
    case helpButtonTapped
    case midiTrafficIndicator(MIDITrafficIndicator.Action)
    case presetsVisibilityButtonTapped
    case settingsButtonTapped
    case setVisibleKeyRange(lowest: Note, highest: Note)
    case shiftKeyboardUpButtonTapped
    case shiftKeyboardDownButtonTapped
    case statusTextTapped(count: Int)
    case lastPlayedKeyChanged(Note)
    case showMoreButtonTapped
    case slidingKeyboardButtonTapped
    case tagsListVisibilityButtonTapped

    @CasePathable
    public enum Delegate: Equatable {
      case editingPresetVisibilityChanged(Bool)
      case effectsVisibilityChanged(Bool)
      case importFinished
      case panic
      case presetNameTapped
      case tagsListVisibilityChanged(Bool)
      case settingsButtonTapped
      case visibleKeyRangeChanged(lowest: Note, highest: Note)
    }
  }

  @Dependency(\.continuousClock) var clock
  @Shared(.showKeyNotes) private var showKeyNotes
  @Shared(.showSolfegeTags) private var showSolfegeTags

  public init() {}

  public var body: some ReducerOf<Self> {

    Scope(state: \.fileImporter, action: \.fileImporter) { FileImporter() }
    Scope(state: \.midiTrafficIndicator, action: \.midiTrafficIndicator) { MIDITrafficIndicator() }

    Reduce<State, Action> { state, action in

      log.action("ToolBar", action)

      switch action {

      case .activePresetIdChanged(let presetId):
        return activePresetIdChanged(&state, presetId: presetId)

      case .activeVoiceCountChanged(let count):
        state.activeVoiceCount = count
        return .none

      case .addSoundFontButtonTapped:
        return .send(.fileImporter(.showFileImporter))

      case .audioUnitCreated(let audioUnit):
        return audioUnitCreated(&state, audioUnit: audioUnit)

      case .clearTemporaryStatus:
        return clearTemporaryStatus(&state)

      case .deinitialize:
        return .merge(
          .send(.midiTrafficIndicator(.deinitialize)),
          .merge(CancelId.allCases.map({ .cancel(id: $0) }))
        )

      case .effectsVisibilityButtonTapped:
        return toggleEffectsVisibility(&state)

      case .fileImporter(.delegate(.importFinished)):
        return .send(.delegate(.importFinished))

      case .helpButtonTapped:
        return showHelp(&state)

      case .lastPlayedKeyChanged(let key):
        return lastPlayedKeyChanged(&state, key: key)

      case .presetsVisibilityButtonTapped:
        return editPresetVisibility(&state)

      case .shiftKeyboardDownButtonTapped:
        return shiftKeyboardDownButtonTapped(&state)

      case .shiftKeyboardUpButtonTapped:
        return shiftKeyboardUpButtonTapped(&state)

      case .settingsButtonTapped:
        return settingsButtonTapped(&state)

      case let .setVisibleKeyRange(lowest, highest):
        return setVisibleKeyRange(&state, lowest: lowest, highest: highest)

      case .showMoreButtonTapped:
        return toggleShowMoreButtons(&state)

      case .slidingKeyboardButtonTapped:
        return slidingKeyboardButtonTapped(&state)

      case .statusTextTapped(let count):
        return statusTextTapped(&state, count: count)

      case .tagsListVisibilityButtonTapped:
        return toggleTagsListVisibility(&state)

      default:
        return .none
      }
    }
  }

  private enum CancelId: String, CaseIterable {
    case toolBarClearTemporaryStatus
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
    return clearTemporaryStatus(&state)
  }

  private func audioUnitCreated(_ state: inout State, audioUnit: AVAudioUnit) -> Effect<Action> {
    .merge(
      monitorActiveVoiceCount(&state, audioUnit: audioUnit),
      .send(.midiTrafficIndicator(.initialize)),
      clearTemporaryStatusTask(&state)
    )
  }

  private func clearTemporaryStatus(_ state: inout State) -> Effect<Action> {
    state.temporaryStatus = nil
    return .none
  }

  private func clearTemporaryStatusTask(_ state: inout State) -> Effect<Action> {
    .run { [clock] send in
      try await clock.sleep(for: Self.temporaryStatusDisplayDuration)
      if Task.isCancelled { return }
      await send(.clearTemporaryStatus, animation: .smooth)
    }.cancellable(id: CancelId.toolBarClearTemporaryStatus, cancelInFlight: true)
  }

  private func editPresetVisibility(_ state: inout State) -> Effect<Action> {
    state.editingPresetVisibility.toggle()
    return .send(.delegate(.editingPresetVisibilityChanged(state.editingPresetVisibility)))
  }

  private func lastPlayedKeyChanged(_ state: inout State, key: Note) -> Effect<Action> {
    if showKeyNotes || showSolfegeTags {
      state.temporaryStatus = .lastPlayedKey(showKeyNotes ? key.fullLabel(withSolfege: showSolfegeTags) : key.solfege)
    }
    return clearTemporaryStatusTask(&state)
  }

  private func monitorActiveVoiceCount(_ state: inout State, audioUnit: AVAudioUnit) -> Effect<Action> {
    guard
      let parameterTree = audioUnit.parameterTree,
      let parameter = parameterTree.parameter(withAddress: SF2.Render.Engine.ParameterAddress.activeVoiceCount.rawValue)
    else {
      log.info("no parameter tree to monitor")
      return .none
    }

    return .run(priority: .utility, name: "monitorActiveVoiceCount") { send in
      let stream: AsyncStream<AUValue>
      let observerToken: AUParameterObserverToken
      unsafe (observerToken, stream) = parameter.startObserving()

      defer {
        unsafe parameter.removeParameterObserver(observerToken)
        log.info("monitorActiveVoiceCount - END")
      }
      for await value in stream.removeDuplicates() {
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

  private func showPanicStatus(_ state: inout State) -> Effect<Action> {
    state.temporaryStatus = .panic
    return clearTemporaryStatusTask(&state)
  }

  private func slidingKeyboardButtonTapped(_ state: inout State) -> Effect<Action> {
    state.$keyboardSlides.withLock { $0 = !state.keyboardSlides }
    return .none
  }

  private func statusTextTapped(_ state: inout State, count: Int) -> Effect<Action> {
    if count == 2 {
      return .merge(
        showPanicStatus(&state),
        .send(.delegate(.panic))
      )
    } else if count == 1 {
      return .send(.delegate(.presetNameTapped))
    }
    return .none
  }

  private func toggleEffectsVisibility(_ state: inout State) -> Effect<Action> {
    state.$effectsPanelVisible.withLock { $0.toggle() }
    state.showMoreButtons = false
    return .send(.delegate(.effectsVisibilityChanged(state.effectsPanelVisible)))
  }

  private func toggleShowMoreButtons(_ state: inout State) -> Effect<Action> {
    withAnimation(.smooth) {
      state.showMoreButtons.toggle()
    }
    if !state.showMoreButtons && state.editingPresetVisibility {
      withAnimation(.smooth) {
        state.editingPresetVisibility = false
      }
      return .send(.delegate(.editingPresetVisibilityChanged(false)))
    }
    return .none
  }

  private func toggleTagsListVisibility(_ state: inout State) -> Effect<Action> {
    state.$tagsListVisible.withLock { $0.toggle() }
    state.showMoreButtons = false
    return .send(.delegate(.tagsListVisibilityChanged(state.tagsListVisible)))
  }
}
