// Copyright © 2025 Brad Howes. All rights reserved.

import AVFoundation
import AudioUnit.AUParameters
import BRHSplitView
import Engine
import FeatureSupport
import Presets
import SF2LibAU
import SQLiteData
import Settings
import SoundFonts
import Tags
import ToolBar

/**
 The top-level feature of the AUv3 interface.
 */
@Reducer
public struct AUv3Root {

  /**
   The various editors and presenters that appear when created and presented.
   */
  @Reducer
  @frozen
  public enum Destination {
    case presetEditor(PresetEditor)
    case settings(Settings)
    case soundFontEditor(SoundFontEditor)
    case tagsEditor(TagsEditor)
  }

  @ObservableState
  public struct State: Equatable {
    public let audioUnit: SF2LibAU
    @Presents public var destination: Destination.State?
    public var fontsAndPresetsSplit: SplitViewReducer.State
    public var fontsAndTagsSplit: SplitViewReducer.State
    public var presetsList: PresetsList.State
    public var soundFontsList: SoundFontsList.State
    public var tagsList: TagsList.State
    public var toolBar: ToolBar.State

    /**
     Constructor for AUv3 component state.
     */
    public init(
      audioUnit: SF2LibAU,
      destination: Destination.State? = nil,
      fontsAndPresetsSplit: SplitViewReducer.State? = nil,
      fontsAndTagsSplit: SplitViewReducer.State? = nil,
      presetsList: PresetsList.State? = nil,
      soundFontsList: SoundFontsList.State? = nil,
      tagsList: TagsList.State? = nil,
      toolBar: ToolBar.State? = nil,
    ) {
      self.audioUnit = audioUnit
      self.fontsAndPresetsSplit = fontsAndPresetsSplit ?? Self.makeFontsAndPresetsSplitState()
      self.fontsAndTagsSplit = fontsAndTagsSplit ?? Self.makeFontsAndTagsSplitState()
      self.presetsList = presetsList ?? .init()
      self.soundFontsList = soundFontsList ?? .init()
      self.tagsList = tagsList ?? .init()
      self.toolBar = toolBar ?? .init()
    }

    static public func makeFontsAndPresetsSplitState() -> SplitViewReducer.State {
      @Shared(.auv3FontsAndPresetsSplitPosition) var fontsAndPresetsSplitPosition
      return .init(
        panesVisible: .both,
        initialPosition: fontsAndPresetsSplitPosition
      )
    }

    static public func makeFontsAndTagsSplitState() -> SplitViewReducer.State {
      @Shared(.auv3FontsAndTagsSplitPosition) var fontsAndTagsSplitPosition
      @Shared(.auv3TagsListVisible) var tagsListVisible
      return .init(
        panesVisible: tagsListVisible ? .both : .primary,
        initialPosition: fontsAndTagsSplitPosition
      )
    }
  }

  @frozen
  public enum Action: BindableAction {
    case activePresetIdChanged(Preset.ID?)
    case binding(BindingAction<State>)
    case currentPresetChanged
    case deinitialize
    case destination(PresentationAction<Destination.Action>)
    case fontsAndPresetsSplit(SplitViewReducer.Action)
    case fontsAndTagsSplit(SplitViewReducer.Action)
    case fullStateChanged
    case initialize
    case lastPresetLoadFinished
    case presetsList(PresetsList.Action)
    case soundFontsList(SoundFontsList.Action)
    case tagsList(TagsList.Action)
    case toolBar(ToolBar.Action)
  }

  public init() {}

  @Dependency(\.fileManager) private var fileManager

  @Shared(.auv3FontsAndPresetsSplitPosition) private var fontsAndPresetsSplitPosition
  @Shared(.auv3FontsAndTagsSplitPosition) private var fontsAndTagsSplitPosition
  @Shared(.auv3TagsListVisible) private var tagsListVisible

  public var body: some ReducerOf<Self> {
    BindingReducer()

    Scope(state: \.fontsAndPresetsSplit, action: \.fontsAndPresetsSplit) { SplitViewReducer() }
    Scope(state: \.fontsAndTagsSplit, action: \.fontsAndTagsSplit) { SplitViewReducer() }
    Scope(state: \.presetsList, action: \.presetsList) { PresetsList() }
    Scope(state: \.soundFontsList, action: \.soundFontsList) { SoundFontsList() }
    Scope(state: \.tagsList, action: \.tagsList) { TagsList() }
    Scope(state: \.toolBar, action: \.toolBar) { ToolBar() }

    Reduce { state, action in

      log.action("AUv3Root", action)

      switch action {

      case .activePresetIdChanged(let presetId):
        return activePresetIdChanged(&state, presetId: presetId)

      case .currentPresetChanged:
        return currentPresetChanged(&state)

      case .deinitialize:
        return deinitialize(&state)

      case .destination(.presented(.settings(.delegate(let action)))):
        return processSettingsAction(&state, action: action)

      case .destination(.dismiss):
        return destinationDismissed(&state)

      case .fontsAndPresetsSplit(.delegate(let action)):
        return processFontsAndPresetsSplitAction(&state, action: action)

      case .fontsAndTagsSplit(.delegate(let action)):
        return processFontsAndTagsSplitAction(&state, action: action)

      case .fullStateChanged:
        return fullStateChanged(&state)

      case .initialize:
        return initialize(&state)

      case .lastPresetLoadFinished:
        return .none

      case .presetsList(.delegate(.activePresetIdChanged(let presetId))):
        return activePresetIdChanged(&state, presetId: presetId)

      case .presetsList(.delegate(.edit(let sectionId, let preset))):
        return editPreset(&state, sectionId: sectionId, preset: preset)

      case .presetsList(.delegate(.missingSoundFontDetected(let soundFontId))):
        return .send(.soundFontsList(.missingSoundFontDetected(soundFontId)))

      case .soundFontsList(.delegate(.presetSourceChanged(let presetSource))):
        return presetSourceChanged(&state, presetSource: presetSource)

      case .soundFontsList(.delegate(.edit(let soundFont))):
        state.destination = .soundFontEditor(SoundFontEditor.State(soundFont: soundFont))
        return .none

      case .tagsList(.delegate(.activeTagIdChanged(let tagId))):
        return .send(.soundFontsList(.activeTagIdChanged(tagId)))

      case .tagsList(.delegate(.edit(focus: let ordering))):
        state.destination = .tagsEditor(TagsEditor.State(focused: ordering))
        return .none

      case .toolBar(.delegate(let action)):
        return processToolBarAction(&state, action: action)

      default:
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }

  private enum CancelId: String, CaseIterable {
    case auv3RootCreateCloudDocumentsDirectory
    case auv3RootMonitorCurrentPreset
    case auv3RootMonitorFullState
    case auv3RootMonitorLastLoadFinished
  }
}

extension AUv3Root {

  /**
   Create and return new instance of AppRoot store after first establishing runtime dependencies.

   - returns: new `AppRoot` store ready to use in ``AUv3RootView``
   */
  @MainActor
  public static func make(audioUnit: SF2LibAU) -> StoreOf<AUv3Root> {
    return StoreOf<AUv3Root>(initialState: AUv3Root.State(audioUnit: audioUnit)) { AUv3Root() }
  }

  private func activePresetIdChanged(_ state: inout State, presetId: Preset.ID?) -> Effect<Action> {
    log.info("activePresetIdChanged BEGIN - presetId: \(presetId ?? -1)")
    refreshFullState(state)
    return .merge(
      .send(.soundFontsList(.selectedIsNowActivated)),
      .send(.toolBar(.activePresetIdChanged(presetId)))
    )
  }

  private func createCloudDocumentsDirectory() -> Effect<Action> {
    .run(priority: .utility, name: "createCloudDocumentsDirectory") { [fileManager] _ in
      if let url = fileManager.cloudDocumentsDirectory() {
        log.info("iCloud documents directory: \(url)")
      } else {
        log.error("iCloud documents directory is not available")
      }
    }.cancellable(id: CancelId.auv3RootCreateCloudDocumentsDirectory, cancelInFlight: true)
  }

  private func currentPresetChanged(_ state: inout State) -> Effect<Action> {
    log.info("currentPresetChanged")
    return .none
  }

  private func deinitialize(_ state: inout State) -> Effect<Action> {
    .merge(
      .merge(CancelId.allCases.map { .cancel(id: $0) }),
      .send(.presetsList(.deinitialize)),
      .send(.soundFontsList(.deinitialize)),
      .send(.tagsList(.deinitialize)),
      .send(.toolBar(.deinitialize))
    )
  }

  private func destinationDismissed(_ state: inout State) -> Effect<Action> {
    switch state.destination {
    case .presetEditor(let editor): presetEditorDismissed(&state, editor: editor)
    case .settings: .send(.presetsList(.updateFetchAllQuery))
    case .soundFontEditor(let editor): soundFontEditorDismissed(&state, editor: editor)
    default: .none
    }
  }

  private func editPreset(_ state: inout State, sectionId: PresetsListSection.State.ID, preset: Preset) -> Effect<Action> {
    state.destination = .presetEditor(
      .init(
        sectionId: sectionId,
        preset: preset,
        isActive: preset.id == state.presetsList.activePresetId
      )
    )
    return .none
  }

  private func fullStateChanged(_ state: inout State) -> Effect<Action> {
    log.info("fullStateChanged BEGIN")
    var effects: [Effect<Action>] = []
    if let activeState = state.audioUnit.auv3ActiveState, let presetLoadingInfo = activeState.presetLoadingInfo {
      if activeState.tagName != state.tagsList.activeTagName {
        effects.append(.send(.tagsList(.activeTagNameChanged(activeState.tagName))))
      }
      if presetLoadingInfo.soundFontId != state.soundFontsList.activePresetSource?.id {
        effects.append(.send(.soundFontsList(.activeSoundFontIdChanged(presetLoadingInfo.soundFontId))))
      }
      if presetLoadingInfo.presetIndex != state.presetsList.activePresetIndex {
        effects.append(.send(.presetsList(.activePresetChanged(presetId: presetLoadingInfo.presetId, info: presetLoadingInfo))))
      }
      if activeState.fontsAndTagsSplitPosition != state.fontsAndTagsSplit.position {
        state.fontsAndTagsSplit.position = activeState.fontsAndTagsSplitPosition
      }
      if activeState.fontsAndPresetsSplitPosition != state.fontsAndPresetsSplit.position {
        state.fontsAndPresetsSplit.position = activeState.fontsAndPresetsSplitPosition
      }
      if tagsListVisible != activeState.tagsListVisible {
        $tagsListVisible.withLock { $0 = activeState.tagsListVisible }
        let panes: SplitViewVisiblePanes = activeState.tagsListVisible ? .both : .primary
        effects.append(.send(.fontsAndTagsSplit(.updatePanesVisibility(panes))))
      }
    }
    return .merge(effects)
  }

  private func initialize(_ state: inout State) -> Effect<Action> {
    .merge(
      createCloudDocumentsDirectory(),
      monitorFullState(&state),
      monitorCurrentPreset(&state),
      monitorLastLoadFinished(&state)
    )
  }

  private func monitorCurrentPreset(_ state: inout State) -> Effect<Action> {
    let (stream, continuation) = AsyncStream<Bool>.makeStream()
    let observerToken = state.audioUnit.observe(\.currentPreset, options: [.initial, .new]) { _, _ in continuation.yield(false) }
    let silenceWarning: (NSKeyValueObservation) -> Void = { _ in }
    silenceWarning(observerToken)
    return .run { send in
      for await _ in stream {
        if Task.isCancelled { break }
        await send(.currentPresetChanged)
      }
    }.cancellable(id: CancelId.auv3RootMonitorCurrentPreset, cancelInFlight: true)
  }

  private func monitorFullState(_ state: inout State) -> Effect<Action> {
    let (stream, continuation) = AsyncStream<Bool>.makeStream()
    let observerToken = state.audioUnit.observe(\.fullState, options: [.initial, .new]) { _, _ in continuation.yield(false) }
    let silenceWarning: (NSKeyValueObservation) -> Void = { _ in }
    silenceWarning(observerToken)
    return .run { send in
      for await _ in stream {
        if Task.isCancelled { break }
        await send(.fullStateChanged)
      }
    }.cancellable(id: CancelId.auv3RootMonitorFullState, cancelInFlight: true)
  }

  private func monitorLastLoadFinished(_ state: inout State) -> Effect<Action> {
    log.info("monitorLastLoadFinished BEGIN")
    guard let parameterTree = state.audioUnit.parameterTree else {
      fatalError("monitorLastLoadFinished - unexpected nil parameterTree chain")
    }

    guard
      let parameter = parameterTree.parameter(withAddress: SF2.Render.Engine.ParameterAddress.lastLoadFinished.rawValue)
    else {
      fatalError("monitorLastLoadFinished - did not find lastLoadFinished parameter")
    }

    return .run(priority: .utility, name: "monitorLastLoadFinished") { send in
      let stream: AsyncStream<AUValue>
      let observerToken: AUParameterObserverToken
      unsafe (observerToken, stream) = parameter.startObserving()

      defer {
        unsafe parameter.removeParameterObserver(observerToken)
        log.debug("monitorLastLoadFinished - stopped task")
      }
      if Task.isCancelled { return }
      for await _ in stream {
        if Task.isCancelled { break }
        log.info("monitorLastLoadFinished - detected")
        await send(.lastPresetLoadFinished)
      }
    }.cancellable(id: CancelId.auv3RootMonitorLastLoadFinished, cancelInFlight: true)
  }

  private func presetEditorDismissed(_ state: inout State, editor: PresetEditor.State) -> Effect<Action> {
    if editor.preset.id == state.presetsList.activePresetId {
      refreshFullState(state)
    }
    return .send(.presetsList(.updateFetchAllQuery))
  }

  private func presetSourceChanged(_ state: inout State, presetSource: PresetSource?) -> Effect<Action> {
    return .send(.presetsList(.presetSourceChanged(presetSource)))
  }

  private func processFontsAndPresetsSplitAction(_ state: inout State, action: SplitViewReducer.Action.Delegate) -> Effect<Action> {
    if case .stateChanged(_, let position) = action {
      if position != fontsAndPresetsSplitPosition {
        $fontsAndPresetsSplitPosition.withLock { $0 = position }
      }
    }
    return .none
  }

  private func processFontsAndTagsSplitAction(_ state: inout State, action: SplitViewReducer.Action.Delegate) -> Effect<Action> {
    if case .stateChanged(let panesVisible, let position) = action {
      let visible = panesVisible.contains(.bottom)
      if visible != tagsListVisible {
        $tagsListVisible.withLock { $0 = visible }
      }
      if position != fontsAndTagsSplitPosition {
        $fontsAndTagsSplitPosition.withLock { $0 = position }
      }
    }
    return .none
  }

  private func processSettingsAction(_ state: inout State, action: Settings.Action.Delegate) -> Effect<Action> {
    return .none
  }

  private func processToolBarAction(_ state: inout State, action: ToolBar.Action.Delegate) -> Effect<Action> {
    switch action {

    case .editingPresetVisibilityChanged(let active):
      return .send(.presetsList(.editingVisibilityChanged(active)))

    case .presetNameTapped:
      return .send(.soundFontsList(.showActiveSoundFont))

    case .settingsButtonTapped:
      state.destination = .settings(Settings.State())
      return .none

    case .tagsListVisibilityChanged(let visible):
      $tagsListVisible.withLock { $0 = visible }
      let panes: SplitViewVisiblePanes = visible ? .both : .primary
      return .send(.fontsAndTagsSplit(.updatePanesVisibility(panes)))

    default:
      return .none
    }
  }

  private func refreshFullState(_ state: State) {
    log.info("refreshFullState BEGIN")
    guard
      let presetId = state.presetsList.activePresetId,
      let preset = Preset.with(id: presetId)
    else {
      log.info("refreshFullState END")
      return
    }

    let activeState: AUv3ActiveState = .init(
      soundFontName: preset.soundFontName,
      presetIndex: preset.index,
      tagName: state.tagsList.activeTagName ?? "",
    )
    log.info("refreshFullState - setting fullState with \(activeState, privacy: .public)")
    do {
      state.audioUnit.fullState = try FullState(activeState: activeState).state
    } catch {
      log.error("refreshFullState - failed to make fullState: \(error.localizedDescription, privacy: .public)")
    }
    log.info("refreshFullState BEGIN")
  }

  private func soundFontEditorDismissed(_ state: inout State, editor: SoundFontEditor.State) -> Effect<Action> {
    if editor.soundFont.id == state.presetsList.presetSource?.id {
      refreshFullState(state)
    }
    return .none
  }
}

extension AUv3Root.Destination.State: Equatable {}

private let log: Logger = .init(category: "AUv3Root")
