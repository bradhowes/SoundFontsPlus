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
// swiftlint:disable type_body_length
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
    @Presents public var destination: Destination.State?

    public let audioUnit: SF2LibAU
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
      @Shared(.fontsAndPresetsSplitPosition) var fontsAndPresetsSplitPosition
      return .init(
        panesVisible: .both,
        initialPosition: fontsAndPresetsSplitPosition
      )
    }

    static public func makeFontsAndTagsSplitState() -> SplitViewReducer.State {
      @Shared(.fontsAndTagsSplitPosition) var fontsAndTagsSplitPosition
      @Shared(.tagsListVisible) var tagsListVisible
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
    case deinitialize
    case destination(PresentationAction<Destination.Action>)
    case fontsAndPresetsSplit(SplitViewReducer.Action)
    case fontsAndTagsSplit(SplitViewReducer.Action)
    case initialize
    case presetsList(PresetsList.Action)
    case soundFontsList(SoundFontsList.Action)
    case tagsList(TagsList.Action)
    case toolBar(ToolBar.Action)
  }

  public init() {}

  @Dependency(\.fileManager) private var fileManager

  @Shared(.activeState) private var activeState
  @Shared(.fontsAndPresetsSplitPosition) private var fontsAndPresetsSplitPosition
  @Shared(.fontsAndTagsSplitPosition) private var fontsAndTagsSplitPosition
  @Shared(.tagsListVisible) private var tagsListVisible

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

      case .deinitialize:
        return .merge(
          .merge(CancelId.allCases.map { .cancel(id: $0) }),
          reduce(into: &state, action: .presetsList(.deinitialize)),
          reduce(into: &state, action: .soundFontsList(.deinitialize)),
          reduce(into: &state, action: .tagsList(.deinitialize)),
          reduce(into: &state, action: .toolBar(.deinitialize))
        )

      case .destination(.presented(.soundFontEditor(.delegate(.refreshPresets)))):
        return reduce(into: &state, action: .presetsList(.fetchPresets))

      case .destination(.presented(.settings(.delegate(let action)))):
        return processSettingsAction(&state, action: action)

      case .destination(.dismiss):
        return destinationDismissed(&state)

      case .fontsAndPresetsSplit(.delegate(let action)):
        return processFontsAndPresetsSplitAction(&state, action: action)

      case .fontsAndTagsSplit(.delegate(let action)):
        return processFontsAndTagsSplitAction(&state, action: action)

      case .initialize:
        return initialize(&state)

      case .presetsList(.delegate(.edit(let sectionId, let preset))):
        state.destination = .presetEditor(PresetEditor.State(sectionId: sectionId, preset: preset))
        return .none

      case .soundFontsList(.delegate(.edit(let soundFont))):
        state.destination = .soundFontEditor(SoundFontEditor.State(soundFont: soundFont))
        return .none

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
    // ._printChanges()
  }

  private enum CancelId: String, CaseIterable {
    case auv3RootCreateCloudDocumentsDirectory
    case auv3RootMonitorActivePresetId
    case auv3RootMonitorInvalidationNotification
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

      // swiftlint:disable:next force_try
      $0.defaultDatabase = try! appDatabase()
      try? $0.fileManager.createDirectory($0.fileManager.fontFilesDirectory())

      return StoreOf<AUv3Root>(initialState: AUv3Root.State(audioUnit: audioUnit)) { AUv3Root() }
    }
  }

  private func activePresetIdChanged(_ state: inout State, presetId: Preset.ID?) -> Effect<Action> {
    reduce(into: &state, action: .toolBar(.activePresetIdChanged(presetId)))
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

  private func destinationDismissed(_ state: inout State) -> Effect<Action> {
    switch state.destination {

    case .presetEditor(let editor):
      return presetEditorDismissed(&state, editor: editor)

    case .settings:
      return reduce(into: &state, action: .presetsList(.fetchPresets))

    default:
      return .none
    }
  }

  private func presetEditorDismissed(_ state: inout State, editor: PresetEditor.State) -> Effect<Action> {
    if editor.visible {
      // Preset is (still) visible -- update its entry in case there were changes.
      state.presetsList.updateSection(editor.sectionId, presetId: editor.preset.id, displayName: editor.displayName)
      return .none
    }
    return reduce(into: &state, action: .presetsList(.fetchPresets))
  }

  private func initialize(_ state: inout State) -> Effect<Action> {
    return .merge(
      createCloudDocumentsDirectory(),
      monitorActivePresetId()
    )
  }

  private func monitorActivePresetId() -> Effect<Action> {
    .run { [$activeState] send in
      for await value in UncheckedSendable($activeState.activePresetId.publisher.values.removeDuplicates()) {
        await send(.activePresetIdChanged(value))
      }
    }.cancellable(id: CancelId.auv3RootMonitorActivePresetId, cancelInFlight: true)
  }

  private func processFontsAndPresetsSplitAction(
    _ state: inout State,
    action: SplitViewReducer.Action.Delegate
  ) -> Effect<Action> {
    if case .stateChanged(_, let position) = action {
      if position != fontsAndPresetsSplitPosition {
        $fontsAndPresetsSplitPosition.withLock { $0 = position }
      }
    }
    return .none
  }

  private func processFontsAndTagsSplitAction(
    _ state: inout State,
    action: SplitViewReducer.Action.Delegate
  ) -> Effect<Action> {
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
      return .merge(
        reduce(into: &state, action: .presetsList(.showActivePreset)),
        reduce(into: &state, action: .soundFontsList(.showActiveSoundFont))
      )

    case .settingsButtonTapped:
      state.destination = .settings(Settings.State())
      return .none

    case .tagsListVisibilityChanged(let visible):
      $tagsListVisible.withLock { $0 = visible }
      let panes: SplitViewPanes = visible ? .both : .primary
      return reduce(into: &state, action: .fontsAndTagsSplit(.updatePanesVisibility(panes)))

    default:
      return .none
    }
  }
}

// swiftlint:enable type_body_length

extension AUv3Root.Destination.State: Equatable {}

private let log: Logger = .init(category: "AUv3Root")
