// Copyright © 2025 Brad Howes. All rights reserved.

import AVFoundation
import AudioUnit.AUParameters
import BRHSplitView
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
     Constructor for AUv3
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
      @Shared(.isAUv3) var isAUv3 = true

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
  public enum Action: BindableAction, @unchecked Sendable {
    case activePresetIdChanged(Preset.ID?)
    case binding(BindingAction<State>)
    case currentPresetChanged
    case deinitialize
    case destination(PresentationAction<Destination.Action>)
    case fontsAndPresetsSplit(SplitViewReducer.Action)
    case fontsAndTagsSplit(SplitViewReducer.Action)
    case fullStateChanged
    case initialize
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

      case .presetsList(.delegate(.activePresetIdChanged(let presetId))):
        return activePresetIdChanged(&state, presetId: presetId)

      case .presetsList(.delegate(.edit(let sectionId, let preset))):
        return editPreset(&state, sectionId: sectionId, preset: preset)

      case .presetsList(.delegate(.missingSoundFontDetected(let soundFontId))):
        return reduce(into: &state, action: .soundFontsList(.missingSoundFontDetected(soundFontId)))

      case .soundFontsList(.delegate(.presetSourceChanged(let presetSource))):
        return presetSourceChanged(&state, presetSource: presetSource)

      case .soundFontsList(.delegate(.edit(let soundFont))):
        state.destination = .soundFontEditor(SoundFontEditor.State(soundFont: soundFont))
        return .none

      case .tagsList(.delegate(.activeTagIdChanged(let tagId))):
        return reduce(into: &state, action: .soundFontsList(.activeTagIdChanged(tagId)))

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
  }
}

extension AUv3Root {

  /**
   Create and return new instance of AppRoot store after first establishing runtime dependencies. See ``SoundFontsApp.swift`` for
   usage.

   - returns: new `AppRoot` store ready to use in ``AppRootView``
   */
  @MainActor
  public static func makeWithDependencies(audioUnit: SF2LibAU) -> StoreOf<AUv3Root> {
    prepareDependencies {
      if ProcessInfo.processInfo.environment["UITesting"] == "true" {
        $0.defaultFileStorage = .inMemory
      } else {
        $0.defaultFileStorage = .fileSystem
      }

      @Shared(.isAUv3) var isAUv3 = true

      // swiftlint:disable:next force_try
      $0.defaultDatabase = try! appDatabase()
      try? $0.fileManager.createDirectory($0.fileManager.fontFilesDirectory())

      return StoreOf<AUv3Root>(initialState: AUv3Root.State(audioUnit: audioUnit)) { AUv3Root() }
    }
  }

  private func activePresetIdChanged(_ state: inout State, presetId: Preset.ID?) -> Effect<Action> {
    log.info("activePresetIdChanged BEGIN - presetId: \(presetId ?? -1)")
    refreshFullState(state)
    return .merge(
      reduce(into: &state, action: .soundFontsList(.selectedIsNowActivated)),
      reduce(into: &state, action: .toolBar(.activePresetIdChanged(presetId)))
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
      reduce(into: &state, action: .presetsList(.deinitialize)),
      reduce(into: &state, action: .soundFontsList(.deinitialize)),
      reduce(into: &state, action: .tagsList(.deinitialize)),
      reduce(into: &state, action: .toolBar(.deinitialize))
    )
  }

  private func destinationDismissed(_ state: inout State) -> Effect<Action> {
    switch state.destination {
    case .presetEditor(let editor): presetEditorDismissed(&state, editor: editor)
    case .settings: reduce(into: &state, action: .presetsList(.updateFetchAllQuery))
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
    if let activeState = state.audioUnit.auv3ActiveState {
      if activeState.tagId != state.tagsList.activeTagId {
        effects.append(reduce(into: &state, action: .tagsList(.activeTagIdChanged(activeState.tagId))))
      }
      if activeState.soundFontId != state.soundFontsList.activePresetSource?.id {
        effects.append(reduce(into: &state, action: .soundFontsList(.activeSoundFontIdChanged(activeState.soundFontId))))
      }
      if activeState.presetId != state.presetsList.activePresetId {
        effects.append(reduce(into: &state, action: .activePresetIdChanged(activeState.presetId)))
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
        effects.append(reduce(into: &state, action: .fontsAndTagsSplit(.updatePanesVisibility(panes))))
      }
    }
    return .merge(effects)
  }

  private func initialize(_ state: inout State) -> Effect<Action> {
    .merge(
      createCloudDocumentsDirectory(),
      monitorFullState(&state)
    )
  }

  private func monitorCurrentPreset(_ state: inout State) -> Effect<Action> {
    .run { [audioUnit = state.audioUnit] send in
      await audioUnit.propertyValueStream(for: \.currentPreset) { await send(.currentPresetChanged) }
    }.cancellable(id: CancelId.auv3RootMonitorCurrentPreset, cancelInFlight: true)
  }

  private func monitorFullState(_ state: inout State) -> Effect<Action> {
    .run { [audioUnit = state.audioUnit] send in
      await audioUnit.propertyValueStream(for: \.fullState) { await send(.fullStateChanged) }
    }.cancellable(id: CancelId.auv3RootMonitorFullState, cancelInFlight: true)
  }

  private func presetEditorDismissed(_ state: inout State, editor: PresetEditor.State) -> Effect<Action> {
    if editor.preset.id == state.presetsList.activePresetId {
      refreshFullState(state)
    }
    return reduce(into: &state, action: .presetsList(.updateFetchAllQuery))
  }

  private func presetSourceChanged(_ state: inout State, presetSource: PresetSource?) -> Effect<Action> {
    return reduce(into: &state, action: .presetsList(.presetSourceChanged(presetSource)))
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
        state.toolBar.setTagsListVisible(visible)
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
      return reduce(into: &state, action: .presetsList(.editingVisibilityChanged(active)))

    case .presetNameTapped:
      return reduce(into: &state, action: .soundFontsList(.showActiveSoundFont))

    case .settingsButtonTapped:
      state.destination = .settings(Settings.State())
      return .none

    case .tagsListVisibilityChanged(let visible):
      $tagsListVisible.withLock { $0 = visible }
      let panes: SplitViewVisiblePanes = visible ? .both : .primary
      return reduce(into: &state, action: .fontsAndTagsSplit(.updatePanesVisibility(panes)))

    default:
      return .none
    }
  }

  private func refreshFullState(_ state: State) {
    log.info("refreshFullState BEGIN")
    if let presetId = state.presetsList.activePresetId,
       let preset = Preset.with(id: presetId) {
      let activeState: AUv3ActiveState = .init(
        soundFontId: preset.soundFontId,
        presetId: presetId,
        tagId: state.tagsList.activeTagId,
        source: .auv3
      )
      log.info("refreshFullState - setting fullState with \(activeState)")
      do {
        state.audioUnit.fullState = try FullState(activeState: activeState).state
      } catch {
        log.error("refreshFullState - failed to make fullState: \(error.localizedDescription)")
      }
    }
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
