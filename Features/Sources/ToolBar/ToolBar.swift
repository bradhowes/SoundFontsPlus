// Copyright © 2025 Brad Howes. All rights reserved.

import AsyncAlgorithms
import AUv3Controls
public import CasePaths
public import ComposableArchitecture
public import Engine
public import FeatureSupport
import Keyboard
public import FileImporter
public import MIDITrafficIndicator
public import Models
import Settings
import SQLiteData
public import Tagged

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

  public struct HelpInfoRestoration: Equatable, Sendable {
    public let effectsPanelVisible: Bool
    public let tagsListVisible: Bool
    public let moreButtonsVisible: Bool

    public init(effectsPanelVisible: Bool, tagsListVisible: Bool, moreButtonsVisible: Bool) {
      self.effectsPanelVisible = effectsPanelVisible
      self.tagsListVisible = tagsListVisible
      self.moreButtonsVisible = moreButtonsVisible
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
    public var displayName: String
    public var isFavorite: Bool
    public var showMoreButtons: Bool
    public var hasMoreButton: Bool
    @ObservationStateIgnored
    public var helpInfoRestoration: HelpInfoRestoration?
    public let isAUv3: Bool

    @Shared(.starFavoriteNames) public var starFavoriteNames
    public var showingPresetSymbol: Bool { starFavoriteNames && isFavorite && temporaryStatus == nil }
    public var statusTextValue: String { temporaryStatus?.text ?? displayName }
    public var statusTextColor: Color { (isFavorite || temporaryStatus != nil) ? .alternateAccentColor : .mainAccentColor }

    public init(
      activeVoiceCount: Int = 0,
      hasMoreButton: Bool = false,
      editingPresetVisibility: Bool = false,
      effectsPanelVisible: Bool? = nil,
      fileImporter: FileImporter.State? = nil,
      highestKey: Note? = nil,
      temporaryStatus: TemporaryStatus? = nil,
      lowestKey: Note? = nil,
      midiTrafficIndicator: MIDITrafficIndicator.State? = nil,
      displayName: String = "",
      isFavorite: Bool = false,
      showMoreButtons: Bool = false,
      tagsListVisible: Bool? = nil,
    ) {
      @Shared(.firstVisibleKey) var savedLowestKey

      self.activeVoiceCount = activeVoiceCount
      self.hasMoreButton = hasMoreButton
      self.editingPresetVisibility = editingPresetVisibility
      self.fileImporter = fileImporter ?? .init()
      self.highestKey = highestKey ?? .C4
      self.temporaryStatus = temporaryStatus
      self.lowestKey = lowestKey ?? savedLowestKey
      self.midiTrafficIndicator = midiTrafficIndicator ?? .init(tag: "ToolBar")
      self.displayName = displayName
      self.isFavorite = isFavorite
      self.showMoreButtons = showMoreButtons
      self.temporaryStatus = .startup

      @Shared(.isAUv3) var isAUv3
      self.isAUv3 = isAUv3

      if let effectsPanelVisible {
        self.$effectsPanelVisible.withLock { $0 = effectsPanelVisible }
      }

      if let tagsListVisible {
        setTagsListVisible(tagsListVisible)
      }
    }

    public var tagsListVisible: Bool {
      if isAUv3 {
        @Shared(.auv3TagsListVisible) var auv3TagsListVisible
        return auv3TagsListVisible
      } else {
        @Shared(.tagsListVisible) var appTagsListVisible
        return appTagsListVisible
      }
    }

    public func setTagsListVisible(_ value: Bool) {
      if isAUv3 {
        @Shared(.auv3TagsListVisible) var auv3TagsListVisible
        $auv3TagsListVisible.withLock { $0 = value }
      } else {
        @Shared(.tagsListVisible) var appTagsListVisible
        $appTagsListVisible.withLock { $0 = value }
      }
    }

    public func tagsListVisibleToggle() {
      if isAUv3 {
        @Shared(.auv3TagsListVisible) var auv3TagsListVisible
        $auv3TagsListVisible.withLock { $0.toggle() }
      } else {
        @Shared(.tagsListVisible) var appTagsListVisible
        $appTagsListVisible.withLock { $0.toggle() }
      }
    }
  }

  public enum Action {
    case activePresetIdChanged(Preset.ID?)
    case activeVoiceCountChanged(Int)
    case addSoundFontButtonTapped
    case audioUnitCreated(AVAudioUnitMIDIInstrument)
    case clearTemporaryStatus
    case deinitialize
    case delegate(Delegate)
    case effectsVisibilityButtonTapped
    case fileImporter(FileImporter.Action)
    case helpInfoButtonTapped
    case helpInfoFinished
    case initialize(Bool)
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
      case helpInfoButtonTapped
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
      return switch action {
      case .activePresetIdChanged(let presetId): activePresetIdChanged(&state, presetId: presetId)
      case .activeVoiceCountChanged(let count): activeVoiceCountChanged(&state, count: count)
      case .addSoundFontButtonTapped: .send(.fileImporter(.showFileImporter))
      case .audioUnitCreated(let audioUnit): audioUnitCreated(&state, audioUnit: audioUnit)
      case .clearTemporaryStatus: clearTemporaryStatus(&state)
      case .deinitialize: deinitialize(&state)
      case .delegate: .none
      case .effectsVisibilityButtonTapped: toggleEffectsVisibility(&state)
      case .fileImporter(.delegate(.importFinished)): .send(.delegate(.importFinished))
      case .fileImporter: .none
      case .helpInfoButtonTapped: helpInfoButtonTapped(&state)
      case .helpInfoFinished: helpInfoFinished(&state)
      case .initialize(let hasMoreButton): initialize(&state, hasMoreButton: hasMoreButton)
      case .lastPlayedKeyChanged(let key): lastPlayedKeyChanged(&state, key: key)
      case .midiTrafficIndicator: .none
      case .presetsVisibilityButtonTapped: editPresetVisibility(&state)
      case .shiftKeyboardDownButtonTapped: shiftKeyboardDownButtonTapped(&state)
      case .shiftKeyboardUpButtonTapped: shiftKeyboardUpButtonTapped(&state)
      case .settingsButtonTapped: settingsButtonTapped(&state)
      case let .setVisibleKeyRange(lowest, highest): setVisibleKeyRange(&state, lowest: lowest, highest: highest)
      case .showMoreButtonTapped: state.hasMoreButton ? toggleShowMoreButtons(&state) : .none
      case .slidingKeyboardButtonTapped: slidingKeyboardButtonTapped(&state)
      case .statusTextTapped(let count): statusTextTapped(&state, count: count)
      case .tagsListVisibilityButtonTapped: toggleTagsListVisibility(&state)
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
       let presetInfo = PresetInfo.with(id: presetId) {
      state.displayName = presetInfo.displayName
      state.isFavorite = presetInfo.kind == .favorite
    } else {
      state.displayName = "-"
      state.isFavorite = false
    }
    return clearTemporaryStatus(&state)
  }

  private func activeVoiceCountChanged(_ state: inout State, count: Int) -> Effect<Action> {
    state.activeVoiceCount = count
    return .none
  }

  private func audioUnitCreated(_ state: inout State, audioUnit: AVAudioUnitMIDIInstrument) -> Effect<Action> {
    return .merge(
      clearTemporaryStatus(&state),
      monitorActiveVoiceCount(&state, audioUnit: audioUnit),
      .send(.midiTrafficIndicator(.initialize)),
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

  private func deinitialize(_ state: inout State) -> Effect<Action> {
    return .merge(
      .send(.midiTrafficIndicator(.deinitialize)),
      .merge(CancelId.allCases.map({ .cancel(id: $0) }))
    )
  }

  private func editPresetVisibility(_ state: inout State) -> Effect<Action> {
    state.editingPresetVisibility.toggle()
    return .send(.delegate(.editingPresetVisibilityChanged(state.editingPresetVisibility)))
  }

  private func helpInfoButtonTapped(_ state: inout State) -> Effect<Action> {
    let helpInfoRestoration: HelpInfoRestoration = .init(
      effectsPanelVisible: state.isAUv3 ? true : state.effectsPanelVisible,
      tagsListVisible: state.tagsListVisible,
      moreButtonsVisible: state.showMoreButtons
    )

    state.helpInfoRestoration = helpInfoRestoration

    return .run { [hasMoreButton = state.hasMoreButton] send in
      if hasMoreButton && !helpInfoRestoration.moreButtonsVisible {
        await send(.showMoreButtonTapped)
      }

      if !helpInfoRestoration.effectsPanelVisible {
        await send(.effectsVisibilityButtonTapped)
      }

      if !helpInfoRestoration.tagsListVisible {
        await send(.tagsListVisibilityButtonTapped)
      }

      try? await Task.sleep(nanoseconds: 400_000_000) // TODO: remove magic constant
      await send(.delegate(.helpInfoButtonTapped))
    }
  }

  private func helpInfoFinished(_ state: inout State) -> Effect<Action> {
    guard let helpInfoRestoration = state.helpInfoRestoration else { return .none }
    state.helpInfoRestoration = nil

    return .run { [hasMoreButton = state.hasMoreButton] send in
      if hasMoreButton && !helpInfoRestoration.moreButtonsVisible {
        await send(.showMoreButtonTapped)
      }

      if !helpInfoRestoration.effectsPanelVisible {
        await send(.effectsVisibilityButtonTapped)
      }

      if !helpInfoRestoration.tagsListVisible {
        await send(.tagsListVisibilityButtonTapped)
      }
    }
  }

  private func initialize(_ state: inout State, hasMoreButton: Bool) -> Effect<Action> {
    state.hasMoreButton = hasMoreButton
    state.showMoreButtons = false
    return .none
  }

  private func lastPlayedKeyChanged(_ state: inout State, key: Note) -> Effect<Action> {
    if showKeyNotes || showSolfegeTags {
      state.temporaryStatus = .lastPlayedKey(showKeyNotes ? key.fullLabel(withSolfege: showSolfegeTags) : key.solfege)
    }
    return clearTemporaryStatusTask(&state)
  }

  private func monitorActiveVoiceCount(_ state: inout State, audioUnit: AVAudioUnitMIDIInstrument) -> Effect<Action> {
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
    return .send(.delegate(.effectsVisibilityChanged(state.effectsPanelVisible)))
  }

  private func toggleShowMoreButtons(_ state: inout State) -> Effect<Action> {
    guard state.hasMoreButton else { return .none }
    state.showMoreButtons.toggle()
    if !state.showMoreButtons && state.editingPresetVisibility {
      state.editingPresetVisibility = false
      return .send(.delegate(.editingPresetVisibilityChanged(false)))
    }
    return .none
  }

  private func toggleTagsListVisibility(_ state: inout State) -> Effect<Action> {
    state.tagsListVisibleToggle()
    return .send(.delegate(.tagsListVisibilityChanged(state.tagsListVisible)))
  }
}

#if DEBUG

#Preview {
  ToolBarView.preview()
}

#endif // DEBUG
