// Copyright © 2025 Brad Howes. All rights reserved.

import AppReview
import AudioUnit.AUParameters
import AVFoundation
import AUv3Controls
import BaseSupport
import BRHSplitView
import Changes
import ComposableArchitecture
import DelayEffect
import FeatureSupport
import Keyboard
import Models
import Presets
import ReverbEffect
import Settings
import Sharing
import SoundFonts
import Synth
import SQLiteData
import SwiftUI
import Tags
import ToolBar
import Tutorial
import UniformTypeIdentifiers
import VolumeMonitor

private let log = Logger(category: "Root")

@Reducer
public struct Root {

  @Reducer(state: .equatable)
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
    @Presents var destination: Destination.State?
    @ObservationStateIgnored
    @FetchAll var soundFontInfos: [SoundFontInfo]

    var appReview: AppReview.State = .init()
    var delay: DelayEffect.State = .init()
    var keyboard: Keyboard.State = .init()
    var presetsList: PresetsList.State = .init()
    var presetsSplit: SplitViewReducer.State
    var reverb: ReverbEffect.State = .init()
    var soundFontsList: SoundFontsList.State = .init()
    var synth: Synth.State = .init()
    var tagsList: TagsList.State = .init()
    var tagsSplit: SplitViewReducer.State
    var toolBar: ToolBar.State = .init()
    var volumeMonitor: VolumeMonitor.State = .init()

    public init() {
      _soundFontInfos = FetchAll(SoundFontInfo.query(), animation: .default)

      @Shared(.fontsAndTagsSplitPosition) var fontsAndTagsPosition
      @Shared(.tagsListVisible) var tagsListVisible
      self.tagsSplit = .init(
        panesVisible: tagsListVisible ? .both : .primary,
        initialPosition: fontsAndTagsPosition
      )

      @Shared(.fontsAndPresetsSplitPosition) var fontsAndPresetsPosition
      self.presetsSplit = .init(
        panesVisible: .both,
        initialPosition: fontsAndPresetsPosition
      )

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
    case delay(DelayEffect.Action)
    case destination(PresentationAction<Destination.Action>)
    case initialize
    case keyboard(Keyboard.Action)
    case presetsList(PresetsList.Action)
    case presetsSplit(SplitViewReducer.Action)
    case reverb(ReverbEffect.Action)
    case scenePhaseChanged(ScenePhase)
    case soundFontsList(SoundFontsList.Action)
    case synth(Synth.Action)
    case tagsList(TagsList.Action)
    case tagsSplit(SplitViewReducer.Action)
    case toolBar(ToolBar.Action)
    case volumeMonitor(VolumeMonitor.Action)
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    BindingReducer()

    Scope(state: \.appReview, action: \.appReview) { AppReview() }
    Scope(state: \.delay, action: \.delay) { DelayEffect() }
    Scope(state: \.keyboard, action: \.keyboard) { Keyboard() }
    Scope(state: \.presetsList, action: \.presetsList) { PresetsList() }
    Scope(state: \.presetsSplit, action: \.presetsSplit) { SplitViewReducer() }
    Scope(state: \.reverb, action: \.reverb) { ReverbEffect() }
    Scope(state: \.soundFontsList, action: \.soundFontsList) { SoundFontsList() }
    Scope(state: \.synth, action: \.synth) { Synth() }
    Scope(state: \.tagsList, action: \.tagsList) { TagsList() }
    Scope(state: \.tagsSplit, action: \.tagsSplit) { SplitViewReducer() }
    Scope(state: \.toolBar, action: \.toolBar) { ToolBar() }
    Scope(state: \.volumeMonitor, action: \.volumeMonitor) { VolumeMonitor() }

    Reduce { state, action in
      switch action {

      case let .activePresetIdChanged(presetId):
        return .merge(
          reduce(into: &state, action: .appReview(.ask)),
          reduce(into: &state, action: .toolBar(.activePresetIdChanged(presetId))),
          reduce(into: &state, action: .volumeMonitor(.activePresetIdChanged(presetId)))
        )

      case .appReview:
        return .none

      case .binding:
        return .none

      case .delay:
        return .none

      case .destination(.presented(.soundFontEditor(.delegate(.refreshPresets)))):
        return reduce(into: &state, action: .presetsList(.fetchPresets))

      case let .destination(.presented(.settings(.delegate(action)))):
        switch action {
        case .showChanges:
          state.showChanges()
          return .none

        case .showTutorial:
          state.showTutorial()
          return .none
        }

      case .destination(.dismiss):
        return .merge(
          reduce(into: &state, action: .appReview(.ask)),
          destinationDismissed(&state)
        )

      case .destination:
        return .none

      case .initialize:
        return initialize(&state)

      case let .keyboard(.delegate(action)):
        return monitorKeyboardAction(&state, action: action)

      case .keyboard:
        return .none

      case let .presetsList(.delegate(.edit(sectionId, preset))):
        state.destination = .presetEditor(PresetEditor.State(sectionId: sectionId, preset: preset))
        return .none

      case .presetsList:
        return .none

      case let .presetsSplit(.delegate(action)):
        return monitorPresetsSplitAction(&state, action: action)

      case .presetsSplit:
        return .none

      case .reverb:
        return .none

      case let .scenePhaseChanged(phase):
        return scenePhaseChanged(&state, phase: phase)

      case let .soundFontsList(.delegate(.edit(soundFont))):
        state.destination = .soundFontEditor(SoundFontEditor.State(soundFont: soundFont))
        return .none

      case .soundFontsList:
        return .none

      case .synth(.synthCreated):
        return reduce(into: &state, action: .toolBar(.monitorActiveVoiceCount))

      case .synth:
        return .none

      case let .tagsList(.delegate(.edit(focused))):
        state.destination = .tagsEditor(TagsEditor.State(mode: .tagEditing, focused: focused))
        return .none

      case .tagsList:
        return .none

      case let .tagsSplit(.delegate(action)):
        return monitorTagsSplitAction(&state, action: action)

      case .tagsSplit:
        return .none

      case let .toolBar(.delegate(action)):
        return monitorToolBarAction(&state, action: action)

      case .toolBar:
        return .none

      case .volumeMonitor(.delegate(.mutedVolume(let reason))):
        return reduce(
          into: &state,
          action: .keyboard(.outputVolumeStateChanged(reason != nil ? .muted : .unmuted))
        )

      case .volumeMonitor:
        return .none
      }
    }.ifLet(\.$destination, action: \.destination)
  }

  @Shared(.activeState) private var activeState
  @Shared(.firstVisibleKey) private var firstVisibleKey

  private enum CancelId {
    case monitorActivePresetId
  }
}

private extension Root {

  func destinationDismissed(_ state: inout State) -> Effect<Action> {
    switch state.destination {

    case let .presetEditor(editor):
      return editorDismissed(&state, editor: editor)

    case .settings:
      return reduce(into: &state, action: .presetsList(.fetchPresets))

    default:
      return .none
    }
  }

  func editorDismissed(_ state: inout State, editor: PresetEditor.State) -> Effect<Action> {
    if editor.visible {
      state.presetsList.updateSection(editor.sectionId, presetId: editor.preset.id, displayName: editor.displayName)
      return .none
    }
    return reduce(into: &state, action: .presetsList(.fetchPresets))
  }

  func initialize(_ state: inout State) -> Effect<Action> {
    .merge(
      .concatenate(
        .run { _ in
          Task.detached(priority: .medium) {
            if let url = FileManager.default.cloudDocumentsDirectory {
              log.info("iCloud documents directory: \(url)")
            } else {
              log.error("iCloud documents directory is not available")
            }
            await Self.disableIdleTimer()
          }
        },
        monitorActivePresetId()
      ),
      reduce(into: &state, action: .synth(.initialize)),
      reduce(into: &state, action: .presetsList(.showActivePreset))
    )
  }

  func monitorActivePresetId() -> Effect<Action> {
    .publisher {
      $activeState.activePresetId
        .publisher
        .removeDuplicates()
        .map { .activePresetIdChanged($0) }
    }.cancellable(id: CancelId.monitorActivePresetId, cancelInFlight: true)
  }

  func monitorKeyboardAction(_ state: inout State, action: Keyboard.Action.Delegate) -> Effect<Action> {
    switch action {
    case .noteOn(let key):
      return reduce(into: &state, action: .toolBar(.lastPlayedKeyChanged(key)))
        .animation(.smooth)

    case let .visibleKeyRangeChanged(lowest, highest):
      $firstVisibleKey.withLock { $0 = lowest }
      return reduce(into: &state, action: .toolBar(.setVisibleKeyRange(lowest: lowest, highest: highest)))
    }
  }

  func monitorPresetsSplitAction(_ state: inout State, action: SplitViewReducer.Action.Delegate) -> Effect<Action> {
    if case let .stateChanged(_, position) = action {
      @Shared(.fontsAndPresetsSplitPosition) var fontsAndPresetsSplitPosition
      $fontsAndPresetsSplitPosition.withLock { $0 = position }
    }
    return .none
  }

  func monitorTagsSplitAction(_ state: inout State, action: SplitViewReducer.Action.Delegate) -> Effect<Action> {
    if case let .stateChanged(panesVisible, position) = action {
      let visible = panesVisible.contains(.bottom)
      state.toolBar.setTagsListVisible(visible)
      @Shared(.tagsListVisible) var tagsListVisible
      $tagsListVisible.withLock { $0 = visible }
      @Shared(.fontsAndTagsSplitPosition) var fontsAndTagsSplitPosition
      $fontsAndTagsSplitPosition.withLock { $0 = position }
    }
    return .none
  }

  func monitorToolBarAction(_ state: inout State, action: ToolBar.Action.Delegate) -> Effect<Action> {
    switch action {

    case let .editingPresetVisibilityChanged(active):
      return reduce(into: &state, action: .presetsList(.visibilityEditModeChanged(active)))

    case let .effectsVisibilityChanged(visible):
      @Shared(.effectsPanelVisible) var effectsPanelVisible
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

    case .settingsDismissed:
      state.destination = nil
      return reduce(into: &state, action: .appReview(.ask))

    case let .tagsVisibilityChanged(visible):
      let panes: SplitViewPanes = visible ? .both : .primary
      return reduce(into: &state, action: .tagsSplit(.updatePanesVisibility(panes)))

    case let .visibleKeyRangeChanged(lowest, _):
      $firstVisibleKey.withLock { $0 = lowest }
      return reduce(into: &state, action: .keyboard(.scrollTo(lowest)))
    }
  }

  func scenePhaseChanged(_ state: inout State, phase: ScenePhase) -> Effect<Action> {
    switch phase {

    case .active:
      return reduce(into: &state, action: .synth(.acquireAudioSession))

    case .background, .inactive:
      return reduce(into: &state, action: .synth(.releaseAudioSession))

    @unknown default:
      fatalError("Unhandled ScenePhase \(phase):")
    }
  }
}

public struct RootView: View, KeyboardVisibilityPublisher {
  @Environment(\.scenePhase) var scenePhase
  @Bindable private var store: StoreOf<Root>
  private let theme: Theme
  private let appPanelBackground = Color.black
  private let dividerBorderColor: Color = Color.gray.opacity(0.15)
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

  public init(store: StoreOf<Root>) {
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
      effectsView
        .knobNativeValueEditorHost()
      toolbarAndKeyboard
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

private extension RootView {

  var listViews: some View {
    SplitView(
      store: store.scope(state: \.presetsSplit, action: \.presetsSplit),
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
        draggableRange: horizontalSizeClass == .compact ? 0.35...0.7 : 0.2...0.8
      )
    )
  }

  var fontsAndTags: some View {
    SplitView(
      store: store.scope(state: \.tagsSplit, action: \.tagsSplit),
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

  var handleDivider: some View {
    HandleDivider(
      dividerColor: dividerBorderColor,
      handleColor: .black,
      dotColor: .accentColor,
      handleLength: 48,
      handleWidth: 8.0,
      paddingInsets: 4.0
    )
  }

  var effectsView: some View {
    let effectsHeight = 110.0
    let padding = 4.0
    let viewHeight = effectsHeight + padding * 4

    return VStack {
      ScrollView(.horizontal) {
        HStack {
          ReverbEffectView(store: store.scope(state: \.reverb, action: \.reverb))
          dividerBorderColor
            .frame(width: padding)
          DelayEffectView(store: store.scope(state: \.delay, action: \.delay))
        }
        .frame(height: effectsHeight)
        .background(Color.black)
        .padding(.init(top: padding, leading: 0, bottom: padding, trailing: 0))
        .background(dividerBorderColor)
        .padding(.init(top: 0, leading: padding, bottom: 0, trailing: padding))
      }
      .onScrollGeometryChange(for: CGFloat.self) { geometry in
        max(0.0, (geometry.visibleRect.width - geometry.contentSize.width) / 2)
      } action: { _, newValue in
        effectsOffset = newValue
      }
      .scrollDisabled(effectsOffset > 0)
      .offset(x: effectsOffset)
      .opacity(effectsPanelVisible ? 1.0 : 0.0)
    }
    .frame(height: effectsPanelVisible ? viewHeight : padding)
    .offset(x: 0, y: effectsPanelVisible ? 0.0 : viewHeight / 2 - padding - 1)
  }

  var toolbarAndKeyboard: some View {
    VStack {
      ToolBarView(store: store.scope(state: \.toolBar, action: \.toolBar))
      keyboardView
    }
  }

  var keyboardView: some View {
    KeyboardView(store: store.scope(state: \.keyboard, action: \.keyboard))
      .frame(height: keyboardHeight)
      .opacity(isInputKeyboardVisible ? 0.0 : 1.0)
  }
}

private extension View {

  /// Swift compiler struggles to deal with too many `.sheet` definitions, hence the explosion of custom `View` methods
  /// to isolate each one in its own method.

  /**
   Custom `View` modifier that generates all of the optional sheets that can be created in the feature.

   - parameter store: the `Root` store which will be scoped to a child feature for displaying
   - parameter horizontalSizeClass: indicator of the horizontal size of the view
   - parameter verticalSizeClass: indicator of the vertical size of the view
   - returns: modified view
   */
  func sheets(
    store: Bindable<StoreOf<Root>>,
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

  func changesSheet(_ store: Bindable<StoreOf<Root>>) -> some View {
    self
      .sheet(item: store.scope(state: \.destination?.changes, action: \.destination.changes)) { child in
        NavigationStack {
          ChangesView(store: child)
            .preferredColorScheme(.dark)
            .environment(\.colorScheme, .dark)
        }
      }
  }

  func presetEditorSheet(_ store: Bindable<StoreOf<Root>>) -> some View {
    self
      .sheet(item: store.scope(state: \.destination?.presetEditor, action: \.destination.presetEditor)) {
        PresetEditorView(store: $0)
          .preferredColorScheme(.dark)
          .environment(\.colorScheme, .dark)
      }
  }

  func settingsSheet(_ store: Bindable<StoreOf<Root>>, showFakeKeyboard: Bool) -> some View {
    self
      .sheet(item: store.scope(state: \.destination?.settings, action: \.destination.settings)) {
        SettingsView(store: $0, showFakeKeyboard: showFakeKeyboard)
          .preferredColorScheme(.dark)
          .environment(\.colorScheme, .dark)
      }
  }

  func soundFontEditorSheet(_ store: Bindable<StoreOf<Root>>) -> some View {
    self
      .sheet(item: store.scope(state: \.destination?.soundFontEditor, action: \.destination.soundFontEditor)) {
        SoundFontEditorView(store: $0)
          .preferredColorScheme(.dark)
          .environment(\.colorScheme, .dark)
      }
  }

  func tagsEditorSheet(_ store: Bindable<StoreOf<Root>>) -> some View {
    self
      .sheet(item: store.scope(state: \.destination?.tagsEditor, action: \.destination.tagsEditor)) { child in
        NavigationStack {
          TagsEditorView(store: child)
            .preferredColorScheme(.dark)
            .environment(\.colorScheme, .dark)
        }
      }
  }

  func tutorialSheet(_ store: Bindable<StoreOf<Root>>) -> some View {
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

extension RootView {

  static var preview: some View {
    prepareDependencies {
      // swiftlint:disable:next force_try
      $0.defaultDatabase = try! appDatabase()
      $0.delayDevice = .init(setConfig: { print("delayDevice.set: ", $0) })
      $0.reverbDevice = .init(setConfig: { print("reverbDevice.set: ", $0) })
    }

    return ZStack {
      Color.black
        .ignoresSafeArea(edges: .all)
      RootView(store: Store(initialState: .init()) { Root() })
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)
    }
  }
}

#Preview {
  RootView.preview
}
