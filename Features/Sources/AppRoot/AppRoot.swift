// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Controls
import AVFoundation
import AppReview
import AudioUnit.AUParameters
import BRHSplitView
import Changes
import DelayEffect
import Engine
import FeatureSupport
import Keyboard
import MorkAndMIDI
import Presets
import ReverbEffect
import SF2LibAU
import SQLiteData
import Settings
import SoundFonts
import SwiftToasts
import Synth
import Tags
import ToolBar
import Tutorial
import VolumeMonitor

/**
 The top-level feature of the application.
 */
@Reducer
// swift lint:disable:next type_body_length
public struct AppRoot {

  /**
   The various editors and presenters that appear when created and presented.
   */
  @Reducer
  @frozen
  public enum Destination {
    /// General informational alert. Includes confirmation dialogs.
    case alert(AlertState<Alert>)
    /// Panel that shows the change log for the app.
    case changes(Changes)
    /// Panel that shows the preset editor.
    case presetEditor(PresetEditor)
    /// Panel that edits the settings for the app.
    case settings(Settings)
    /// Panel that shows the soundfont metadata editor.
    case soundFontEditor(SoundFontEditor)
    /// Panel that shows the tags editor
    case tagsEditor(TagsEditor)
    /// Panel that shows the tutorial screens for the app.
    case tutorial(Tutorial)

    @CasePathable
    @frozen
    public enum Alert {
      /// Confirm request to reinitialize the database, removing all customizations.
      case reinitializeConfirmed
    }
  }

  fileprivate struct HelpInfoRestoration: Equatable {
    let effectsPanelVisible: Bool
    let tagsListVisible: Bool
    let moreButtonsVisible: Bool
  }

  @ObservableState
  public struct State: Equatable {
    public var appReview: AppReview.State
    public var delayEffect: DelayEffect.State
    @Presents public var destination: Destination.State?
    public var fontsAndPresetsSplit: SplitViewReducer.State
    public var fontsAndTagsSplit: SplitViewReducer.State
    public var keyboard: Keyboard.State
    public var presetsList: PresetsList.State
    public var reverbEffect: ReverbEffect.State
    public var soundFontsList: SoundFontsList.State
    public var synth: Synth.State
    public var tagsList: TagsList.State
    public var toolBar: ToolBar.State
    public var volumeMonitor: VolumeMonitor.State
    // Set to true when synth is created and audio state is active. Once set, does not change.
    public var readyForUse = false
    public var audioUnitCrashed = false
    public var toastState: VolumeMonitor.Reason?
    public var avAudioUnit: AVAudioUnit?
    @Shared(.effectsPanelVisible) public var effectsPanelVisible
    public var helpInfoSelection: RootHelpInfo?
    @ObservationStateIgnored
    fileprivate var helpInfoRestorations: HelpInfoRestoration?

    /**
     Constructor for main app.
     */
    public init(
      appReview: AppReview.State? = nil,
      delayEffect: DelayEffect.State? = nil,
      destination: Destination.State? = nil,
      fontsAndPresetsSplit: SplitViewReducer.State? = nil,
      fontsAndTagsSplit: SplitViewReducer.State? = nil,
      keyboard: Keyboard.State? = nil,
      presetsList: PresetsList.State? = nil,
      reverbEffect: ReverbEffect.State? = nil,
      soundFontsList: SoundFontsList.State? = nil,
      synth: Synth.State? = nil,
      tagsList: TagsList.State? = nil,
      toolBar: ToolBar.State? = nil,
      toastState: VolumeMonitor.Reason? = nil
    ) {
      @Dependency(\.appActiveState) var appActiveState
      @Shared(.isAUv3) var isAUv3 = false

      let activePresetSource: PresetSource? =  .makeActive(appActiveState.getActiveSoundFontId())

      self.appReview = appReview ?? .init()
      self.delayEffect = delayEffect ?? .init()
      self.fontsAndPresetsSplit = fontsAndPresetsSplit ?? Self.makeFontsAndPresetsSplitState()
      self.fontsAndTagsSplit = fontsAndTagsSplit ?? Self.makeFontsAndTagsSplitState()
      self.keyboard = keyboard ?? .init()
      self.presetsList = presetsList ?? .init(
        presetSource: activePresetSource,
        activePresetId: appActiveState.getActivePresetId()
      )
      self.reverbEffect = reverbEffect ?? .init()
      self.soundFontsList = soundFontsList ?? .init(
        activeTagId: appActiveState.getActiveTagId(),
        activePresetSource: activePresetSource,
        selectedPresetSource: nil
      )
      self.synth = synth ?? .init()
      self.tagsList = tagsList ?? .init(activeTagId: appActiveState.getActiveTagId())
      self.toolBar = toolBar ?? .init()
      self.toastState = toastState
      self.volumeMonitor = .init()

      if Tutorial.shouldShow {
        showTutorial()
      } else if Changes.shouldShow {
        showChanges()
      }
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

    mutating func showChanges() {
      destination = .changes(Changes.State(Bundle.main.changeLog))
      @Shared(.lastShowedChangesVersion) var lastShowedChangesVersion
      $lastShowedChangesVersion.withLock { $0 = Bundle.main.releaseVersionNumber }
    }

    mutating func showTutorial() {
      destination = .tutorial(Tutorial.State())
      @Shared(.showedTutorial) var showedTutorial
      $showedTutorial.withLock { $0 = true }
    }
  }

  @frozen
  public enum Action: BindableAction {
    case activePresetIdChanged(Preset.ID?)
    case appReview(AppReview.Action)
    case audioUnitCrashed
    case beginHelpSpotlight
    case binding(BindingAction<State>)
    case deinitialize
    case delayEffect(DelayEffect.Action)
    case destination(PresentationAction<Destination.Action>)
    case fontsAndPresetsSplit(SplitViewReducer.Action)
    case fontsAndTagsSplit(SplitViewReducer.Action)
    case initialize
    case keyboard(Keyboard.Action)
    case presetsList(PresetsList.Action)
    case reverbEffect(ReverbEffect.Action)
    case scenePhaseChanged(ScenePhase)
    case soundFontsList(SoundFontsList.Action)
    case synth(Synth.Action)
    case tagsList(TagsList.Action)
    case toolBar(ToolBar.Action)
    case volumeMonitor(VolumeMonitor.Action)
  }

  public init() {}

  @Dependency(\.fileManager) private var fileManager
  @Dependency(\.appActiveState) private var appActiveState

  @Shared(.firstVisibleKey) private var firstVisibleKey
  @Shared(.fontsAndPresetsSplitPosition) private var fontsAndPresetsSplitPosition
  @Shared(.fontsAndTagsSplitPosition) private var fontsAndTagsSplitPosition
  @Shared(.tagsListVisible) private var tagsListVisible

  public var body: some ReducerOf<Self> {
    BindingReducer()

    Scope(state: \.appReview, action: \.appReview) { AppReview() }
    Scope(state: \.delayEffect, action: \.delayEffect) { DelayEffect() }
    Scope(state: \.fontsAndPresetsSplit, action: \.fontsAndPresetsSplit) { SplitViewReducer() }
    Scope(state: \.fontsAndTagsSplit, action: \.fontsAndTagsSplit) { SplitViewReducer() }
    Scope(state: \.keyboard, action: \.keyboard) { Keyboard() }
    Scope(state: \.presetsList, action: \.presetsList) { PresetsList() }
    Scope(state: \.reverbEffect, action: \.reverbEffect) { ReverbEffect() }
    Scope(state: \.soundFontsList, action: \.soundFontsList) { SoundFontsList() }
    Scope(state: \.synth, action: \.synth) { Synth() }
    Scope(state: \.tagsList, action: \.tagsList) { TagsList() }
    Scope(state: \.toolBar, action: \.toolBar) { ToolBar() }
    Scope(state: \.volumeMonitor, action: \.volumeMonitor) { VolumeMonitor() }

    Reduce { state, action in

      log.action("AppRoot", action)

      switch action {

      case .activePresetIdChanged(let presetId):
        return activePresetIdChanged(&state, presetId: presetId)

      case .audioUnitCrashed:
        log.error("*** audioUnit crashed")
        return .none

      case .beginHelpSpotlight:
        state.helpInfoSelection = .fontsList
        return .none

      case .binding(\.helpInfoSelection):
        var effects = [Effect<Action>]()
        if state.helpInfoSelection == nil, let restorations = state.helpInfoRestorations {
          @Shared(.effectsPanelVisible) var effectsPanelVisible
          $effectsPanelVisible.withLock { $0 = restorations.effectsPanelVisible }
          if !restorations.tagsListVisible {
            effects.append(.send(.toolBar(.tagsListVisibilityButtonTapped)))
          }
          if !restorations.moreButtonsVisible {
            effects.append(.send(.toolBar(.showMoreButtonTapped)))
          }

          state.helpInfoRestorations = nil
        }
        return .merge(effects)

      case .deinitialize:
        return deinitialize(&state)

      case .destination(.presented(.alert(.reinitializeConfirmed))):
        return reinitializeConfirmed(&state)

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

      case .keyboard(.delegate(let action)):
        return processKeyboardAction(&state, action: action)

      case .presetsList(.delegate(.activePresetIdChanged(let presetId))):
        return activePresetIdChanged(&state, presetId: presetId)

      case let .presetsList(.delegate(.edit(sectionId, preset))):
        return editPreset(&state, sectionId: sectionId, preset: preset)

      case .presetsList(.delegate(.missingSoundFontDetected(let soundFontId))):
        return .send(.soundFontsList(.missingSoundFontDetected(soundFontId)))

      case .scenePhaseChanged(let phase):
        return scenePhaseChanged(&state, phase: phase)

      case .soundFontsList(.delegate(.presetSourceChanged(let presetSource))):
        return presetSourceChanged(&state, presetSource: presetSource)

      case .soundFontsList(.delegate(.edit(let soundFont))):
        state.destination = .soundFontEditor(.init(soundFont: soundFont))
        return .none

      case .synth(.delegate(.audioUnitCreated(let avAudioUnit))):
        return audioUnitCreated(&state, avAudioUnit: avAudioUnit)

      case .synth(.delegate(.running)):
        return audioChainActive(&state)

      case .synth(.delegate(.stopped)):
        return audioChainInactive(&state)

      case .tagsList(.delegate(.activeTagIdChanged(let tagId))):
        appActiveState.setActiveTagId(tagId)
        return .send(.soundFontsList(.activeTagIdChanged(tagId)))

      case .tagsList(.delegate(.edit(focus: let ordering))):
        state.destination = .tagsEditor(.init(focused: ordering))
        return .none

      case .toolBar(.delegate(let action)):
        return processToolBarAction(&state, action: action)

      case .volumeMonitor(.delegate(.reasonChanged(let reason))):
        return volumeMonitorReasonChanged(&state, reason: reason)

      default:
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }

  private enum CancelId: String, CaseIterable {
    case appRootCreateCloudDocumentsDirectory
    case appRootMonitorInvalidationNotification
  }
}

extension AppRoot {

  /**
   Create and return new instance of AppRoot store after first establishing runtime dependencies. See ``SoundFontsApp.swift`` for
   usage.

   - returns: new `AppRoot` store ready to use in ``AppRootView``
   */
  @MainActor
  public static func makeWithDependencies() -> StoreOf<AppRoot> {
    prepareDependencies {
      installApplicationFont()
      @Shared(.isAUv3) var isAUv3 = false

      // swiftlint:disable:next force_try
      $0.defaultDatabase = try! appDatabase()
      try? $0.fileManager.createDirectory($0.fileManager.fontFilesDirectory())

      @Shared(.midiInputPortId) var midiInputPortId
      @Shared(.midi) var midi = MIDI(clientName: "Test", uniqueId: Int32(midiInputPortId), midiProto: .v1_0)

      return StoreOf<AppRoot>(initialState: AppRoot.State()) { AppRoot() }
    }
  }

  private func activePresetIdChanged(_ state: inout State, presetId: Preset.ID?) -> Effect<Action> {
    guard state.readyForUse else { return .none }
    appActiveState.setActivePresetId(presetId)

    // Experiment with setting the active preset via AUAudioUnit.fullState attribute.
    if let presetId,
       let avAudioUnit = state.avAudioUnit,
       let preset = Preset.with(id: presetId) {
      let activeState: AUv3ActiveState = .init(
        source: .app,
        soundFontName: preset.soundFontName,
        presetIndex: preset.index,
        tagName: state.tagsList.activeTagName ?? "",
      )
      do {
        avAudioUnit.auAudioUnit.fullState = try FullState(activeState: activeState).state
      } catch {
        log.error("activePresetIdChanged - failed to make fullState: \(error.localizedDescription)")
      }
    }

    return .merge(
      .send(.appReview(.ask)),
      .send(.delayEffect(.activePresetIdChanged(presetId))),
      .send(.keyboard(.activePresetIdChanged(presetId))),
      .send(.reverbEffect(.activePresetIdChanged(presetId))),
      .send(.soundFontsList(.selectedIsNowActivated)),
      .send(.synth(.activePresetIdChanged(presetId))),
      .send(.toolBar(.activePresetIdChanged(presetId))),
      .send(.volumeMonitor(.activePresetIdChanged(presetId))))
  }

  private func audioUnitCreated(_ state: inout State, avAudioUnit: AVAudioUnit) -> Effect<Action> {
    state.avAudioUnit = avAudioUnit
    if let midiInstrument = avAudioUnit.midiInstrument {
      installMIDIMonitor(midiInstrument: midiInstrument)
    }

    return .merge(
      .send(.toolBar(.audioUnitCreated(avAudioUnit))),
      .send(.keyboard(.midiInstrumentCreated(avAudioUnit)))
    )
  }

  private func audioChainActive(_ state: inout State) -> Effect<Action> {
    // The synth is up and running with an active audio session. Safe to monitor its state now.
    var actions: [Effect<Action>] = [.send(.volumeMonitor(.start))]
    if !state.readyForUse {
      state.readyForUse = true
      actions.append(activePresetIdChanged(&state, presetId: state.presetsList.activePresetId))
    }

    return .merge(actions)
  }

  private func audioChainInactive(_ state: inout State) -> Effect<Action> {
    return .send(.volumeMonitor(.stop))
  }

  private func createCloudDocumentsDirectory() -> Effect<Action> {
    .run(priority: .utility, name: "createCloudDocumentsDirectory") { [fileManager] _ in
      if let url = fileManager.cloudDocumentsDirectory() {
        log.info("iCloud documents directory: \(url)")
      } else {
        log.error("iCloud documents directory is not available")
      }
      await Self.disableIdleTimer()
    }.cancellable(id: CancelId.appRootCreateCloudDocumentsDirectory, cancelInFlight: true)
  }

  private func deinitialize(_ state: inout State) -> Effect<Action> {

    // By design MIDI does not have a complete 'stop' function, so there could be messages coming over after we are
    // deinitialized. Remove any installed MIDIMonitor so that it will no longer try to access the database.
    @Shared(.midi) var midi
    if let midi {
      midi.monitor = nil
      midi.receiver = nil
      midi.stop()
    }

    return .merge(
      .merge(CancelId.allCases.map { .cancel(id: $0) }),
      .send(.delayEffect(.deinitialize)),
      .send(.keyboard(.deinitialize)),
      .send(.presetsList(.deinitialize)),
      .send(.reverbEffect(.deinitialize)),
      .send(.soundFontsList(.deinitialize)),
      .send(.synth(.deinitialize)),
      .send(.tagsList(.deinitialize)),
      .send(.toolBar(.deinitialize)),
      .send(.volumeMonitor(.stop))
    )
  }

  private func destinationDismissed(_ state: inout State) -> Effect<Action> {
    .merge(
      .send(.appReview(.ask)),
      {
        switch state.destination {
        case .presetEditor(let editor): presetEditorDismissed(&state, editor: editor)
        case .alert, .settings: .send(.presetsList(.updateFetchAllQuery))
        default: .none
        }
      }()
    )
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

  private func initialize(_ state: inout State) -> Effect<Action> {
    .merge(
      createCloudDocumentsDirectory(),
      monitorInvalidationNotification(&state),
      .send(.synth(.initialize)),
    )
  }

  private func installMIDIMonitor(midiInstrument: AVAudioUnitMIDIInstrument) {
    log.info("install MIDIMonitor")

    @Shared(.midi) var midi
    guard let midi else {
      log.info("no MIDI to use")
      return
    }

    @Shared(.midiMonitor) var midiMonitor
    guard midiMonitor == nil else { fatalError() }

    let monitor = MIDIMonitor(instrument: midiInstrument)
    $midiMonitor.withLock {
      $0 = monitor
    }

    midi.receiver = monitor
    midi.monitor = monitor

    log.info("starting MIDI service")
    midi.start()
  }

  private func monitorInvalidationNotification(_ state: inout State) -> Effect<Action> {
    let name = Notification.Name(String(kAudioComponentInstanceInvalidationNotification))
    return .run(priority: .utility, name: "monitorInvalidationNotification") { send in
      while !Task.isCancelled {
        for await _ in NotificationCenter.default.notifications(named: name) {
          await send(.audioUnitCrashed)
        }
      }
    }.cancellable(id: CancelId.appRootMonitorInvalidationNotification, cancelInFlight: true)
  }

  private func presetEditorDismissed(_ state: inout State, editor: PresetEditor.State) -> Effect<Action> {
    if editor.preset.id == state.presetsList.activePresetId {
      return .merge(
        .send(.presetsList(.updateFetchAllQuery)),
        .send(.toolBar(.activePresetIdChanged(state.presetsList.activePresetId)))
      )
    }
    return .send(.presetsList(.updateFetchAllQuery))
  }

  private func presetSourceChanged(_ state: inout State, presetSource: PresetSource?) -> Effect<Action> {
    if let presetSource {
      if presetSource.isActive {
        appActiveState.setActiveSoundFontId(presetSource.id)
      }
    }
    return .send(.presetsList(.presetSourceChanged(presetSource)))
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
      }
      if position != fontsAndTagsSplitPosition {
        $fontsAndTagsSplitPosition.withLock { $0 = position }
      }
    }
    return .none
  }

  private func processKeyboardAction(_ state: inout State, action: Keyboard.Action.Delegate) -> Effect<Action> {
    switch action {
    case .noteOn(let key):
      return .run { send in await send(.toolBar(.lastPlayedKeyChanged(key)), animation: .smooth) }
    case .visibleKeyRangeChanged(let lowest, let highest):
      $firstVisibleKey.withLock { $0 = lowest }
      return .send(.toolBar(.setVisibleKeyRange(lowest: lowest, highest: highest)))
    }
  }

  private func processSettingsAction(_ state: inout State, action: Settings.Action.Delegate) -> Effect<Action> {
    switch action {
    case .reinitialize: state.destination = .alert(.confirmReinitialize(action: .reinitializeConfirmed))
    case .showChanges: state.showChanges()
    case .showTutorial: state.showTutorial()
    }
    return .none
  }

  private func processToolBarAction(_ state: inout State, action: ToolBar.Action.Delegate) -> Effect<Action> {
    switch action {

    case .editingPresetVisibilityChanged(let active):
      return .send(.presetsList(.editingVisibilityChanged(active)))

    case .effectsVisibilityChanged(let visible):
      withAnimation(.smooth) {
        state.$effectsPanelVisible.withLock { $0 = visible }
      }
      return .none

    case .helpButtonTapped:
      return helpButtonTapped(&state)

    case .importFinished:
      return .send(.tagsList(.importFinished))

    case .presetNameTapped:
      return .merge(
        .send(.appReview(.ask)),
        .send(.soundFontsList(.showActiveSoundFont))
      )

    case .panic:
      _ = state.synth.avAudioUnit?.sendReset()
      return .send(.keyboard(.allOff))

    case .settingsButtonTapped:
      state.destination = .settings(Settings.State())
      return .none

    case .tagsListVisibilityChanged(let visible):
      $tagsListVisible.withLock { $0 = visible }
      let panes: SplitViewVisiblePanes = visible ? .both : .primary
      return .send(.fontsAndTagsSplit(.updatePanesVisibility(panes)))

    case .visibleKeyRangeChanged(let lowest, _):
      $firstVisibleKey.withLock { $0 = lowest }
      return .send(.keyboard(.scrollTo(lowest)))
    }
  }

  private func helpButtonTapped(_ state: inout State) -> Effect<Action> {
    @Shared(.effectsPanelVisible) var effectsPanelVisible
    state.helpInfoRestorations = .init(
      effectsPanelVisible: effectsPanelVisible,
      tagsListVisible: tagsListVisible,
      moreButtonsVisible: state.toolBar.showMoreButtons
    )

    state.$effectsPanelVisible.withLock { $0 = true }

    var effects = [Effect<Action>]()

    if !tagsListVisible {
      effects.append(.send(.toolBar(.tagsListVisibilityButtonTapped)))
    }

    if !state.toolBar.showMoreButtons {
      effects.append(.send(.toolBar(.showMoreButtonTapped)))
    }

    effects.append(
      .run {send in
        try await Task.sleep(for: .milliseconds(500))
        await send(.beginHelpSpotlight)
      }
    )

    return .merge(effects)

  }
  private func reinitializeConfirmed(_ state: inout State) -> Effect<Action> {
    BackupManager.reinitialize()
    withAnimation(.smooth) {
      state.destination = .alert(.reinitialized())
    }
    return .none
  }

  private func scenePhaseChanged(_ state: inout State, phase: ScenePhase) -> Effect<Action> {
    switch phase {

    case .active:
      log.info("scene becoming active - resuming DB")
      NotificationCenter.default.post(name: Database.resumeNotification, object: self)
      return .send(.synth(.acquireAudioSession))

    case .background, .inactive:
      log.info("scene becoming inactive - suspending DB")
      NotificationCenter.default.post(name: Database.suspendNotification, object: self)
      return .send(.synth(.releaseAudioSession))

    @unknown default:
      fatalError("Unhandled ScenePhase \(phase):")
    }
  }

  private func volumeMonitorReasonChanged(_ state: inout State, reason: VolumeMonitor.Reason?) -> Effect<Action> {
    log.info("volumeMonitor reasonChanged: \(reason.debugDescription)")
    if let reason {
      if state.toastState == nil {
        state.toastState = reason
      }
    } else {
      state.toastState = nil
    }

    return .send(.keyboard(.outputVolumeStateChanged(reason != nil ? .muted : .unmuted)))
  }
}

extension AppRoot.Destination.State: Equatable {}
extension AppRoot.Destination.Alert: Equatable {}

private let log: Logger = .init(category: "AppRoot")
