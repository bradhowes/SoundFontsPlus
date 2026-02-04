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
// swiftlint:disable type_body_length
public struct AppRoot {

  /**
   The various editors and presenters that appear when created and presented.
   */
  @Reducer
  @frozen
  public enum Destination {
    case alert(AlertState<Alert>)
    case changes(Changes)
    case presetEditor(PresetEditor)
    case settings(Settings)
    case soundFontEditor(SoundFontEditor)
    case tagsEditor(TagsEditor)
    #if os(iOS)
    case tutorial(Tutorial)
    #endif

    @CasePathable
    @frozen
    public enum Alert {
      case reinitializeConfirmed
    }
  }

  @ObservableState
  public struct State: Equatable {
    public var appReview: AppReview.State
    public var delay: DelayEffect.State
    @Presents public var destination: Destination.State?
    public var fontsAndPresetsSplit: SplitViewReducer.State
    public var fontsAndTagsSplit: SplitViewReducer.State
    public var keyboard: Keyboard.State
    public var presetsList: PresetsList.State
    public var reverb: ReverbEffect.State
    public var soundFontsList: SoundFontsList.State
    public var synth: Synth.State
    public var tagsList: TagsList.State
    public var toolBar: ToolBar.State
    #if os(iOS)
    public var volumeMonitor: VolumeMonitor.State
    #endif
    // Set to true when synth is created and audio state is active. Once set, does not change.
    public var readyForUse = false
    public var audioUnitCrashed = false
    public var toastState: VolumeMonitor.Reason?

    /**
     Constructur for main app.
     */
    public init(
      appReview: AppReview.State? = nil,
      delay: DelayEffect.State? = nil,
      destination: Destination.State? = nil,
      fontsAndPresetsSplit: SplitViewReducer.State? = nil,
      fontsAndTagsSplit: SplitViewReducer.State? = nil,
      keyboard: Keyboard.State? = nil,
      presetsList: PresetsList.State? = nil,
      reverb: ReverbEffect.State? = nil,
      soundFontsList: SoundFontsList.State? = nil,
      synth: Synth.State? = nil,
      tagsList: TagsList.State? = nil,
      toolBar: ToolBar.State? = nil,
      toastState: VolumeMonitor.Reason? = nil
    ) {
      @Shared(.isAUv3) var isAUv3 = false

#if false
      @Shared(.activeState) var activeState
      $activeState.withLock {
        $0.activePresetId = nil
        $0.activeSoundFontId = nil
      }
#endif // false

      self.appReview = appReview ?? .init()
      self.delay = delay ?? .init()
      self.fontsAndPresetsSplit = fontsAndPresetsSplit ?? Self.makeFontsAndPresetsSplitState()
      self.fontsAndTagsSplit = fontsAndTagsSplit ?? Self.makeFontsAndTagsSplitState()
      self.keyboard = keyboard ?? .init()
      self.presetsList = presetsList ?? .init()
      self.reverb = reverb ?? .init()
      self.soundFontsList = soundFontsList ?? .init()
      self.synth = synth ?? .init()
      self.tagsList = tagsList ?? .init()
      self.toolBar = toolBar ?? .init()
      self.toastState = toastState

#if os(iOS)
      self.volumeMonitor = .init()

#if !DEBUG || !targetEnvironment(simulator)

      if Tutorial.shouldShow {
        showTutorial()
      } else if Changes.shouldShow {
        showChanges()
      }

#endif // !DEBUG || !targetEnvironment(simulator)
#endif // os(iOS)

      // Deep-linking to a destination at start up for dev/testing
      //
      // destination = .settings(SettingsFeature.State(midi: midi, midiMonitor: midiMonitor))
    }

    /**
     Constructor for AUv3 component.
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

      self.appReview = .init()
      self.delay = .init()
      self.fontsAndPresetsSplit = fontsAndPresetsSplit ?? Self.makeFontsAndPresetsSplitState()
      self.fontsAndTagsSplit = fontsAndTagsSplit ?? Self.makeFontsAndTagsSplitState()
      self.keyboard = .init()
      self.presetsList = presetsList ?? .init()
      self.reverb = .init()
      self.soundFontsList = soundFontsList ?? .init()
      self.synth = .init()
      self.tagsList = tagsList ?? .init()
      self.toolBar = toolBar ?? .init()
      self.toastState = nil

#if os(iOS)
      self.volumeMonitor = .init()
#endif // os(iOS)
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
    case binding(BindingAction<State>)
    case deinitialize
    case delay(DelayEffect.Action)
    case destination(PresentationAction<Destination.Action>)
    case fontsAndPresetsSplit(SplitViewReducer.Action)
    case fontsAndTagsSplit(SplitViewReducer.Action)
    case initialize
    case keyboard(Keyboard.Action)
    case presetsList(PresetsList.Action)
    case reverb(ReverbEffect.Action)
    case scenePhaseChanged(ScenePhase)
    case soundFontsList(SoundFontsList.Action)
    case synth(Synth.Action)
    case tagsList(TagsList.Action)
    case toolBar(ToolBar.Action)
#if os(iOS)
    case volumeMonitor(VolumeMonitor.Action)
#endif
  }

  public init() {}

  @Dependency(\.fileManager) private var fileManager

  @Shared(.activeState) private var activeState
  @Shared(.effectsPanelVisible) private var effectsPanelVisible
  @Shared(.firstVisibleKey) private var firstVisibleKey
  @Shared(.fontsAndPresetsSplitPosition) private var fontsAndPresetsSplitPosition
  @Shared(.fontsAndTagsSplitPosition) private var fontsAndTagsSplitPosition
  @Shared(.tagsListVisible) private var tagsListVisible

  public var body: some ReducerOf<Self> {
    BindingReducer()

    Scope(state: \.appReview, action: \.appReview) { AppReview() }
    Scope(state: \.delay, action: \.delay) { DelayEffect() }
    Scope(state: \.fontsAndPresetsSplit, action: \.fontsAndPresetsSplit) { SplitViewReducer() }
    Scope(state: \.fontsAndTagsSplit, action: \.fontsAndTagsSplit) { SplitViewReducer() }
    Scope(state: \.keyboard, action: \.keyboard) { Keyboard() }
    Scope(state: \.presetsList, action: \.presetsList) { PresetsList() }
    Scope(state: \.reverb, action: \.reverb) { ReverbEffect() }
    Scope(state: \.soundFontsList, action: \.soundFontsList) { SoundFontsList() }
    Scope(state: \.synth, action: \.synth) { Synth() }
    Scope(state: \.tagsList, action: \.tagsList) { TagsList() }
    Scope(state: \.toolBar, action: \.toolBar) { ToolBar() }
#if os(iOS)
    Scope(state: \.volumeMonitor, action: \.volumeMonitor) { VolumeMonitor() }
#endif

    Reduce { state, action in

      log.action("AppRoot", action)

      switch action {

      case .activePresetIdChanged(let presetId):
        return activePresetIdChanged(&state, presetId: presetId)

      case .audioUnitCrashed:
        log.error("*** audioUnit crashed")
        return .none

      case .deinitialize:

        // By design MIDI does not have a complete 'stop' function, so there could be messages coming over after we are
        // deinitialized. Remove any installed MIDIMonitor so that it will no longer try to access the database.
        @Shared(.midi) var midi
        if let midi {
          midi.monitor = nil
          midi.receiver = nil
          midi.stop()
        }

        var actions = [
          .merge(CancelId.allCases.map { .cancel(id: $0) }),
          reduce(into: &state, action: .delay(.deinitialize)),
          reduce(into: &state, action: .keyboard(.deinitialize)),
          reduce(into: &state, action: .presetsList(.deinitialize)),
          reduce(into: &state, action: .reverb(.deinitialize)),
          reduce(into: &state, action: .soundFontsList(.deinitialize)),
          reduce(into: &state, action: .synth(.deinitialize)),
          reduce(into: &state, action: .tagsList(.deinitialize)),
          reduce(into: &state, action: .toolBar(.deinitialize))
        ]

#if os(iOS)
        actions.append(reduce(into: &state, action: .volumeMonitor(.stop)))
#endif
        return .merge(actions)

      case .destination(.presented(.alert(.reinitializeConfirmed))):
        return reinitializeConfirmed(&state)

      case .destination(.presented(.soundFontEditor(.delegate(.refreshPresets)))):
        return reduce(into: &state, action: .presetsList(.fetchPresets))

      case .destination(.presented(.settings(.delegate(let action)))):
        return processSettingsAction(&state, action: action)

      case .destination(.dismiss):
        return .merge(
          reduce(into: &state, action: .appReview(.ask)),
          destinationDismissed(&state)
        )

      case .fontsAndPresetsSplit(.delegate(let action)):
        return processFontsAndPresetsSplitAction(&state, action: action)

      case .fontsAndTagsSplit(.delegate(let action)):
        return processFontsAndTagsSplitAction(&state, action: action)

      case .initialize:
        return initialize(&state)

      case .keyboard(.delegate(let action)):
        return processKeyboardAction(&state, action: action)

      case .presetsList(.delegate(.edit(let sectionId, let preset))):
        state.destination = .presetEditor(PresetEditor.State(sectionId: sectionId, preset: preset))
        return .none

      case .scenePhaseChanged(let phase):
        return scenePhaseChanged(&state, phase: phase)

      case .soundFontsList(.delegate(.edit(let soundFont))):
        state.destination = .soundFontEditor(SoundFontEditor.State(soundFont: soundFont))
        return .none

      case .synth(.delegate(.audioUnitCreated(let avAudioUnit))):
        return audioUnitCreated(&state, avAudioUnit: avAudioUnit)

      case .synth(.delegate(.running)):
        return audioChainActive(&state)

      case .synth(.delegate(.stopped)):
        return audioChainInactive(&state)

      case .tagsList(.delegate(.edit(focus: let ordering))):
        state.destination = .tagsEditor(TagsEditor.State(focused: ordering))
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
    // ._printChanges()
  }

  private enum CancelId: String, CaseIterable {
    case appRootCreateCloudDocumentsDirectory
    case appRootMonitorActivePresetId
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
      if ProcessInfo.processInfo.environment["UITesting"] == "true" {
        $0.defaultFileStorage = .inMemory
      } else {
        $0.defaultFileStorage = .fileSystem
      }

      installApplicationFont()

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
    var actions = [
      reduce(into: &state, action: .appReview(.ask)),
      reduce(into: &state, action: .keyboard(.activePresetIdChanged(presetId))),
      reduce(into: &state, action: .synth(.activePresetIdChanged(presetId))),
      reduce(into: &state, action: .toolBar(.activePresetIdChanged(presetId)))
    ]
#if os(iOS)
    actions.append(reduce(into: &state, action: .volumeMonitor(.activePresetIdChanged(presetId))))
#endif
    return .merge(actions)
  }

  private func audioUnitCreated(_ state: inout State, avAudioUnit: AVAudioUnit) -> Effect<Action> {
    if let midiInstrument = avAudioUnit.midiInstrument {
      installMIDIMonitor(midiInstrument: midiInstrument)
    }

    return .merge(
      reduce(into: &state, action: .toolBar(.audioUnitCreated(avAudioUnit))),
      reduce(into: &state, action: .keyboard(.midiInstrumentCreated(avAudioUnit)))
    )
  }

  private func audioChainActive(_ state: inout State) -> Effect<Action> {
    // The synth is up and running with an active audio session. Safe to monitor its state now.
    var actions = [Effect<Action>]()

#if os(iOS)
    actions.append(reduce(into: &state, action: .volumeMonitor(.start)))
#endif

    if !state.readyForUse {
      state.readyForUse = true
      actions.append(activePresetIdChanged(&state, presetId: activeState.activePresetId))
    }

    return .merge(actions)
  }

  private func audioChainInactive(_ state: inout State) -> Effect<Action> {
#if os(iOS)
    return reduce(into: &state, action: .volumeMonitor(.stop))
#else
    return .none
#endif
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

  private func destinationDismissed(_ state: inout State) -> Effect<Action> {
    switch state.destination {

    case .presetEditor(let editor):
      return presetEditorDismissed(&state, editor: editor)

    case .alert, .settings:
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
//    log.info("sharedDocumentsDirectory dump: \(FileManager.default.sharedDocumentsDirectory.path())")
//    let found = try? FileManager.default.contentsOfDirectory(atPath: FileManager.default.sharedDocumentsDirectory.path())
//    for each in (found ?? []) {
//      log.info("found: \(each)")
//    }
    return .merge(
      createCloudDocumentsDirectory(),
      monitorActivePresetId(),
      monitorInvalidationNotification(&state),
      reduce(into: &state, action: .synth(.initialize)),
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

  private func monitorActivePresetId() -> Effect<Action> {
    .run { [$activeState] send in
      for await value in UncheckedSendable($activeState.activePresetId.publisher.values.removeDuplicates()) {
        await send(.activePresetIdChanged(value))
      }
    }.cancellable(id: CancelId.appRootMonitorActivePresetId, cancelInFlight: true)
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

  private func processKeyboardAction(_ state: inout State, action: Keyboard.Action.Delegate) -> Effect<Action> {
    switch action {
    case .noteOn(let key):
      return reduce(into: &state, action: .toolBar(.lastPlayedKeyChanged(key)))
        .animation(.smooth)

    case .visibleKeyRangeChanged(let lowest, let highest):
      $firstVisibleKey.withLock { $0 = lowest }
      return reduce(into: &state, action: .toolBar(.setVisibleKeyRange(lowest: lowest, highest: highest)))
    }
  }

  private func processSettingsAction(_ state: inout State, action: Settings.Action.Delegate) -> Effect<Action> {
    switch action {

    case .reinitialize:
      state.destination = .alert(.confirmReinitialize(action: .reinitializeConfirmed))

    case .showChanges:
      state.showChanges()

    case .showTutorial:
#if os(iOS)
      state.showTutorial()
#endif
    }

    return .none
  }

  private func processToolBarAction(_ state: inout State, action: ToolBar.Action.Delegate) -> Effect<Action> {
    switch action {

    case .editingPresetVisibilityChanged(let active):
      return reduce(into: &state, action: .presetsList(.editingVisibilityChanged(active)))

    case .effectsVisibilityChanged(let visible):
      $effectsPanelVisible.withLock { $0 = visible }
      return .none.animation(.smooth)

    case .importFinished:
      return reduce(into: &state, action: .soundFontsList(.updateFetchAllQuery))

    case .presetNameTapped:
      return .merge(
        reduce(into: &state, action: .appReview(.ask)),
        reduce(into: &state, action: .presetsList(.showActivePreset)),
        reduce(into: &state, action: .soundFontsList(.showActiveSoundFont))
      )

    case .panic:
      _ = state.synth.avAudioUnit?.sendReset()
      return reduce(into: &state, action: .keyboard(.allOff))

    case .settingsButtonTapped:
      state.destination = .settings(Settings.State())
      return .none

    case .tagsListVisibilityChanged(let visible):
      $tagsListVisible.withLock { $0 = visible }
      let panes: SplitViewPanes = visible ? .both : .primary
      return reduce(into: &state, action: .fontsAndTagsSplit(.updatePanesVisibility(panes)))

    case .visibleKeyRangeChanged(let lowest, _):
      $firstVisibleKey.withLock { $0 = lowest }
      return reduce(into: &state, action: .keyboard(.scrollTo(lowest)))
    }
  }

  private func reinitializeConfirmed(_ state: inout State) -> Effect<Action> {
    BackupManager.reinitialize()
    state.destination = .alert(.reinitialized())
    return .none.animation(.smooth)
  }

  private func scenePhaseChanged(_ state: inout State, phase: ScenePhase) -> Effect<Action> {
    switch phase {

    case .active:
      log.info("scene becoming active - resuming DB")
      NotificationCenter.default.post(name: Database.resumeNotification, object: self)
      return reduce(into: &state, action: .synth(.acquireAudioSession))

    case .background, .inactive:
      log.info("scene becoming inactive - suspending DB")
      NotificationCenter.default.post(name: Database.suspendNotification, object: self)
      return reduce(into: &state, action: .synth(.releaseAudioSession))

    @unknown default:
      fatalError("Unhandled ScenePhase \(phase):")
    }
  }

  private func volumeMonitorReasonChanged(_ state: inout State, reason: VolumeMonitor.Reason?) -> Effect<Action> {
#if os(iOS)
    log.info("volumeMonitor reasonChanged: \(reason.debugDescription)")
    if let reason {
      if state.toastState == nil {
        state.toastState = reason
      }
    } else {
      state.toastState = nil
    }

    return reduce(
      into: &state,
      action: .keyboard(.outputVolumeStateChanged(reason != nil ? .muted : .unmuted))
    )
#else
    return .none
#endif
  }
}

// swiftlint:enable type_body_length

extension AppRoot.Destination.State: Equatable {}
extension AppRoot.Destination.Alert: Equatable {}

private let log: Logger = .init(category: "AppRoot")
