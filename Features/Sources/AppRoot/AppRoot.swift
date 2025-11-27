// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Controls
import AVFoundation
import AppReview
import AudioUnit.AUParameters
import BRHSplitView
import Changes
import DelayEffect
import Dependencies
import FeatureSupport
import Keyboard
import Presets
import ReverbEffect
import SQLiteData
import Settings
import SoundFonts
import Synth
import Tags
import ToolBar
import Tutorial
import UniformTypeIdentifiers
import VolumeMonitor

/**
 The top-level feature of the application.
 */
@Reducer
public struct AppRoot {

  public static func prepareDependencies() {
    Dependencies.prepareDependencies {
      @Shared(.isAUv3) var isAUv3 = false

      $0.audioGraph = .liveValue
      $0.audioSession = .liveValue

      // swiftlint:disable:next force_try
      $0.defaultDatabase = try! appDatabase()
      $0.defaultFileStorage = .fileSystem

      $0.synthAUv3ComponentDescription = SynthAUv3ComponentDescription.liveValue

      let delay = AVAudioUnitDelay()
      $0.delayDevice = .init(setConfig: { delay.setConfig($0) })
      @Shared(.delayEffect) var delayEffect = delay

      let reverb = AVAudioUnitReverb()
      $0.reverbDevice = .init( setConfig: { reverb.setConfig($0) })
      @Shared(.reverbEffect) var reverbEffect = reverb

      let engine = AVAudioEngine()
      @Shared(.audioEngine) var audioEngine = engine
    }
  }

  /**
   The various editors and presenters that appear in a modal way when created and presented.
   */
  @Reducer
  public enum Destination {
    case changes(Changes)
    case presetEditor(PresetEditor)
    case settings(Settings)
    case soundFontEditor(SoundFontEditor)
    case tagsEditor(TagsEditor)
    case tutorial(Tutorial)
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
    public var volumeMonitor: VolumeMonitor.State

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
      volumeMonitor: VolumeMonitor.State? = nil
    ) {
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
      self.volumeMonitor = volumeMonitor ?? .init()

      #if ALWAYS_SHOW_TUTORIAL

        showTutorial()

      #elseif ALWAYS_SHOW_CHANGES

        showChanges()

      #elseif !(DEBUG && targetEnvironment(simulator))

        if Tutorial.shouldShow {
          showTutorial()
        } else if Changes.shouldShow {
          showChanges()
        }

      #endif

      // Deep-linking to a destination at start up for dev/testing
      //
      // destination = .settings(SettingsFeature.State(midi: midi, midiMonitor: midiMonitor))
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

  public enum Action: BindableAction {
    case activePresetIdChanged(Preset.ID?)
    case appReview(AppReview.Action)
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
    case volumeMonitor(VolumeMonitor.Action)
  }

  public init() {}

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
    Scope(state: \.keyboard, action: \.keyboard) { Keyboard() }
    Scope(state: \.presetsList, action: \.presetsList) { PresetsList() }
    Scope(state: \.reverb, action: \.reverb) { ReverbEffect() }
    Scope(state: \.soundFontsList, action: \.soundFontsList) { SoundFontsList() }
    Scope(state: \.synth, action: \.synth) { Synth() }
    Scope(state: \.tagsList, action: \.tagsList) { TagsList() }
    Scope(state: \.toolBar, action: \.toolBar) { ToolBar() }
    Scope(state: \.volumeMonitor, action: \.volumeMonitor) { VolumeMonitor() }

    Scope(state: \.fontsAndPresetsSplit, action: \.fontsAndPresetsSplit) { SplitViewReducer() }
    Scope(state: \.fontsAndTagsSplit, action: \.fontsAndTagsSplit) { SplitViewReducer() }

    Reduce { state, action in
      log.info("reduce \(action)")
      switch action {

      case .activePresetIdChanged(let presetId):
        return .merge(
          reduce(into: &state, action: .appReview(.ask)),
          reduce(into: &state, action: .toolBar(.activePresetIdChanged(presetId))),
          reduce(into: &state, action: .volumeMonitor(.activePresetIdChanged(presetId)))
        )

      case .deinitialize:
        return .merge(
          .merge(CancelId.allCases.map { .cancel(id: $0) }),
          reduce(into: &state, action: .synth(.deinitialize)),
          reduce(into: &state, action: .toolBar(.deinitialize)),
          reduce(into: &state, action: .volumeMonitor(.stop))
        )

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

      case .synth(.delegate(.running)):
        return audioChainActive(&state)

      case .synth(.delegate(.stopped)):
        return audioChainInactive(&state)

      case .tagsList(.delegate(.edit(let focused))):
        state.destination = .tagsEditor(TagsEditor.State(mode: .tagEditing, focused: focused))
        return .none

      case .toolBar(.delegate(let action)):
        return processToolBarAction(&state, action: action)

      case .volumeMonitor(.delegate(.reasonChanged(let reason))):
        log.info("volumeMonitor reasonChanged: \(reason.debugDescription)")
        return reduce(
          into: &state,
          action: .keyboard(.outputVolumeStateChanged(reason != nil ? .muted : .unmuted))
        )

      default:
        return .none
      }
    }.ifLet(\.$destination, action: \.destination)
  }

  private enum CancelId: CaseIterable {
    case createCloudDocumentsDirectory
    case monitorActivePresetId
  }
}

extension AppRoot {

  private func audioChainActive(_ state: inout State) -> Effect<Action> {
    // The synth is up and running with an active audio session. Safe to monitor its state now.
    .merge(
      reduce(into: &state, action: .volumeMonitor(.start)),
      reduce(into: &state, action: .toolBar(.monitorActiveVoiceCount))
    )
  }

  private func audioChainInactive(_ state: inout State) -> Effect<Action> {
    // We do not have the active audio session.
    .merge(
      reduce(into: &state, action: .volumeMonitor(.stop))
    )
  }

  fileprivate func createCloudDocumentsDirectory() -> Effect<Action> {
    .run { _ in
      Task.detached(priority: .medium) {
        if let url = FileManager.default.cloudDocumentsDirectory {
          log.info("iCloud documents directory: \(url)")
        } else {
          log.error("iCloud documents directory is not available")
        }
        await Self.disableIdleTimer()
      }
    }.cancellable(id: CancelId.createCloudDocumentsDirectory, cancelInFlight: true)
  }

  fileprivate func destinationDismissed(_ state: inout State) -> Effect<Action> {
    switch state.destination {

    case .presetEditor(let editor):
      return editorDismissed(&state, editor: editor)

    case .settings:
      return reduce(into: &state, action: .presetsList(.fetchPresets))

    default:
      return .none
    }
  }

  fileprivate func editorDismissed(_ state: inout State, editor: PresetEditor.State) -> Effect<Action> {
    if editor.visible {
      state.presetsList.updateSection(editor.sectionId, presetId: editor.preset.id, displayName: editor.displayName)
      return .none
    }
    return reduce(into: &state, action: .presetsList(.fetchPresets))
  }

  fileprivate func initialize(_ state: inout State) -> Effect<Action> {
    .merge(
      createCloudDocumentsDirectory(),
      monitorActivePresetId(),
      reduce(into: &state, action: .synth(.initialize)),
    )
  }

  fileprivate func monitorActivePresetId() -> Effect<Action> {
    .publisher {
      $activeState.activePresetId
        .publisher
        .removeDuplicates()
        .map { .activePresetIdChanged($0) }
    }.cancellable(id: CancelId.monitorActivePresetId, cancelInFlight: true)
  }

  fileprivate func processKeyboardAction(_ state: inout State, action: Keyboard.Action.Delegate) -> Effect<Action> {
    switch action {
    case .noteOn(let key):
      return reduce(into: &state, action: .toolBar(.lastPlayedKeyChanged(key)))
        .animation(.smooth)

    case .visibleKeyRangeChanged(let lowest, let highest):
      $firstVisibleKey.withLock { $0 = lowest }
      return reduce(into: &state, action: .toolBar(.setVisibleKeyRange(lowest: lowest, highest: highest)))
    }
  }

  fileprivate func processFontsAndPresetsSplitAction(
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

  fileprivate func processFontsAndTagsSplitAction(
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

  fileprivate func processSettingsAction(_ state: inout State, action: Settings.Action.Delegate) -> Effect<Action> {
    switch action {
    case .showChanges:
      state.showChanges()

    case .showTutorial:
      state.showTutorial()
    }

    return .none
  }

  fileprivate func processToolBarAction(_ state: inout State, action: ToolBar.Action.Delegate) -> Effect<Action> {
    switch action {

    case .editingPresetVisibilityChanged(let active):
      return reduce(into: &state, action: .presetsList(.visibilityEditModeChanged(active)))

    case .effectsVisibilityChanged(let visible):
      $effectsPanelVisible.withLock { $0 = visible }
      return .none.animation(.smooth)

    case .presetNameTapped:
      return .merge(
        reduce(into: &state, action: .appReview(.ask)),
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

    case .visibleKeyRangeChanged(let lowest, _):
      $firstVisibleKey.withLock { $0 = lowest }
      return reduce(into: &state, action: .keyboard(.scrollTo(lowest)))
    }
  }

  fileprivate func scenePhaseChanged(_ state: inout State, phase: ScenePhase) -> Effect<Action> {
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
}

extension AppRoot.Destination.State: Equatable {}

public struct AppRootView: View {
  @Environment(\.scenePhase) var scenePhase
  @Bindable private var store: StoreOf<AppRoot>
  private let theme: Theme
  private let appPanelBackground = Color.black
  private let dividerBorderColor: Color = Color.gray.mix(with: .black, by: 0.7)
  private let dividerSpan: CGFloat = 4
  @State private var isInputKeyboardVisible = false
  @State private var effectsOffset: CGFloat = 0.0

  @Shared(.effectsPanelVisible) private var effectsPanelVisible
  @Environment(\.maxKeyboardPanelHeight) private var maxKeyboardPanelHeight
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.verticalSizeClass) private var verticalSizeClass

  private var showFakeKeyboard: Bool {
    horizontalSizeClass == .compact || verticalSizeClass == .compact
  }

  private var keyboardHeight: CGFloat {
    isInputKeyboardVisible
      ? 1.0
      : maxKeyboardPanelHeight * (verticalSizeClass == .compact ? 0.5 : 1.0)
  }

  public init(store: StoreOf<AppRoot>) {
    self.store = store
    var theme = Theme()
    theme.controlForegroundColor = .teal
    theme.textColor = .teal.mix(with: .black, by: 0.2)
    theme.controlTrackStrokeStyle = StrokeStyle(lineWidth: 5, lineCap: .round)
    theme.controlValueStrokeStyle = StrokeStyle(lineWidth: 3, lineCap: .round)
    theme.toggleOnIndicatorSystemName = "arrowtriangle.down.fill"
    theme.toggleOffIndicatorSystemName = "arrowtriangle.down"
    theme.font = .effectsControl

    navigationBarTitleStyle()

    self.theme = theme
  }

  public var body: some View {

    // let _ = Self._printChanges()
    VStack(spacing: 0) {
      listViews
      controlViews
    }
    .padding(0)
    .animation(.smooth, value: effectsPanelVisible)
    .animation(.smooth, value: isInputKeyboardVisible)
    .environment(\.auv3ControlsTheme, theme)
    .environment(\.appPanelBackground, appPanelBackground)
    .onChange(of: scenePhase) { _, newPhase in
      store.send(.scenePhaseChanged(newPhase))
    }
    .task {
      await store.send(.initialize).finish()
    }
    .onReceive(keyboardVisibilityPublisher) { state in
      isInputKeyboardVisible = state
      // If restoring display of the virtual music keyboard, scroll to the active preset
      // since it could become hidden by the keyboard.
      if !state {
        store.scope(state: \.presetsList, action: \.presetsList).send(.showActivePreset)
      }
    }
    .sheets(
      store: $store,
      horizontalSizeClass: horizontalSizeClass,
      verticalSizeClass: verticalSizeClass
    )
    .appReview(store: store.scope(state: \.appReview, action: \.appReview))
    .volumeMonitorHUD(store: store.scope(state: \.volumeMonitor, action: \.volumeMonitor))
  }
}

extension AppRootView: KeyboardVisibilityPublisher {}

extension AppRootView {

  fileprivate var listViews: some View {
    SplitView(
      store: store.scope(state: \.fontsAndPresetsSplit, action: \.fontsAndPresetsSplit),
      primary: {
        fontsAndTags
      },
      divider: {
        handleDivider
      },
      secondary: {
        PresetsListView(store: store.scope(state: \.presetsList, action: \.presetsList))
      }
    ).splitViewConfiguration(
      .init(
        orientation: .horizontal,
        draggableRange: 0.35...0.7
      )
    )
  }

  fileprivate var fontsAndTags: some View {
    SplitView(
      store: store.scope(state: \.fontsAndTagsSplit, action: \.fontsAndTagsSplit),
      primary: {
        SoundFontsListView(store: store.scope(state: \.soundFontsList, action: \.soundFontsList))
      },
      divider: {
        handleDivider
      },
      secondary: {
        TagsListView(store: store.scope(state: \.tagsList, action: \.tagsList))
      }
    ).splitViewConfiguration(
      .init(
        orientation: .vertical,
        draggableRange: 0.15...0.85,
        dragToHidePanes: .secondary,
        doubleClickToClose: .secondary
      )
    )
  }

  fileprivate var handleDivider: some View {
    HandleDivider(
      dividerColor: dividerBorderColor,
      handleColor: .black,
      dotColor: .accentColor,
      handleLength: 48,
      handleWidth: 8.0,
      paddingInsets: 4.0
    )
  }

  fileprivate var controlViews: some View {
    VStack(spacing: 0) {
      dividerBorderColor
        .frame(height: dividerSpan)
      effectsView
        .knobNativeValueEditorHost()
      ToolBarView(store: store.scope(state: \.toolBar, action: \.toolBar))
      dividerBorderColor
        .frame(height: dividerSpan)
      keyboardView
    }
  }

  fileprivate var effectsView: some View {
    let effectsHeight = 110.0
    let viewHeight = effectsHeight + dividerSpan * 4

    return VStack(alignment: .leading, spacing: 0) {
      ScrollView(.horizontal) {
        HStack(spacing: 0) {
          ReverbEffectView(store: store.scope(state: \.reverb, action: \.reverb))
          dividerBorderColor
            .frame(width: dividerSpan)
          DelayEffectView(store: store.scope(state: \.delay, action: \.delay))
        }
      }
      .onScrollGeometryChange(for: CGFloat.self) { geometry in
        max(0.0, (geometry.visibleRect.width - geometry.contentSize.width) / 2)
      } action: { _, newValue in
        effectsOffset = newValue
      }
      .scrollDisabled(effectsOffset > 0)
      .background(Color.black)
      dividerBorderColor
        .frame(height: dividerSpan)
    }
    .frame(height: effectsPanelVisible ? viewHeight : 0.0)
    .frame(maxWidth: .infinity)
    .offset(y: effectsPanelVisible ? 0.0 : viewHeight / 2 + dividerSpan * 2)
  }

  fileprivate var keyboardView: some View {
    KeyboardView(store: store.scope(state: \.keyboard, action: \.keyboard))
      .frame(height: keyboardHeight)
      .opacity(isInputKeyboardVisible ? 0.0 : 1.0)
  }
}

extension View {

  /// Swift compiler struggles to deal with too many `.sheet` definitions, hence the explosion of custom `View` methods
  /// to isolate each one in its own method.

  /**
   Custom `View` modifier that generates all of the optional sheets that can be created in the feature.
  
   - parameter store: the `Root` store which will be scoped to a child feature for displaying
   - parameter horizontalSizeClass: indicator of the horizontal size of the view
   - parameter verticalSizeClass: indicator of the vertical size of the view
   - returns: modified view
   */
  fileprivate func sheets(
    store: Bindable<StoreOf<AppRoot>>,
    horizontalSizeClass: UserInterfaceSizeClass?,
    verticalSizeClass: UserInterfaceSizeClass?
  ) -> some View {
    self
      .changesSheet(store)
      .presetEditorSheet(store)
      .settingsSheet(store, showFakeKeyboard: horizontalSizeClass == .compact || verticalSizeClass == .compact)
      .soundFontEditorSheet(store)
      .tagsEditorSheet(store)
      .tutorialSheet(store)
  }

  fileprivate func changesSheet(_ store: Bindable<StoreOf<AppRoot>>) -> some View {
    self
      .sheet(item: store.scope(state: \.destination?.changes, action: \.destination.changes)) { child in
        NavigationStack {
          ChangesView(store: child)
            .preferredColorScheme(.dark)
            .environment(\.colorScheme, .dark)
        }
      }
  }

  fileprivate func presetEditorSheet(_ store: Bindable<StoreOf<AppRoot>>) -> some View {
    self
      .sheet(item: store.scope(state: \.destination?.presetEditor, action: \.destination.presetEditor)) {
        PresetEditorView(store: $0)
          .preferredColorScheme(.dark)
          .environment(\.colorScheme, .dark)
      }
  }

  fileprivate func settingsSheet(_ store: Bindable<StoreOf<AppRoot>>, showFakeKeyboard: Bool) -> some View {
    self
      .sheet(item: store.scope(state: \.destination?.settings, action: \.destination.settings)) {
        SettingsView(store: $0, showFakeKeyboard: showFakeKeyboard)
          .preferredColorScheme(.dark)
          .environment(\.colorScheme, .dark)
      }
  }

  fileprivate func soundFontEditorSheet(_ store: Bindable<StoreOf<AppRoot>>) -> some View {
    self
      .sheet(item: store.scope(state: \.destination?.soundFontEditor, action: \.destination.soundFontEditor)) {
        SoundFontEditorView(store: $0)
          .preferredColorScheme(.dark)
          .environment(\.colorScheme, .dark)
      }
  }

  fileprivate func tagsEditorSheet(_ store: Bindable<StoreOf<AppRoot>>) -> some View {
    self
      .sheet(item: store.scope(state: \.destination?.tagsEditor, action: \.destination.tagsEditor)) { child in
        NavigationStack {
          TagsEditorView(store: child)
            .preferredColorScheme(.dark)
            .environment(\.colorScheme, .dark)
        }
      }
  }

  fileprivate func tutorialSheet(_ store: Bindable<StoreOf<AppRoot>>) -> some View {
    self
      .sheet(item: store.scope(state: \.destination?.tutorial, action: \.destination.tutorial)) { child in
        NavigationStack {
          TutorialView(store: child)
            .preferredColorScheme(.dark)
            .environment(\.colorScheme, .dark)
        }
      }
  }
}

extension AppRootView {

  static var preview: some View {
    prepareDependencies {
      $0.defaultDatabase = previewDatabase()
      $0.delayDevice = .init(setConfig: { print("delayDevice.set: ", $0) })
      $0.reverbDevice = .init(setConfig: { print("reverbDevice.set: ", $0) })
      @Shared(.tagsListVisible) var tagsListVisible
      $tagsListVisible.withLock { $0 = false }
      @Shared(.effectsPanelVisible) var effectsPanelVisible
      $effectsPanelVisible.withLock { $0 = true }
    }

    return ZStack {
      Color.black
        .ignoresSafeArea(edges: .all)
      AppRootView(store: Store(initialState: .init()) { AppRoot() })
        // .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)
    }
  }
}

#Preview {
  AppRootView.preview
}

private let log = Logger(category: "AppRoot")
