// Copyright © 2025 Brad Howes. All rights reserved.

import AudioUnit.AUParameters
import AVFoundation
import AUv3Controls
import BRHSplitView
import ComposableArchitecture
import SF2LibAU
import SharingGRDB
import Sharing
import SwiftUI
import UniformTypeIdentifiers

private let log = Logger(category: "AppFeature")

@Reducer
struct AppFeature {
  private let volumeMonitor: VolumeMonitor = .init()

  @Reducer(state: .equatable)
  enum Destination {
    case presetEditor(PresetEditor)
    case settings(SettingsFeature)
    case soundFontEditor(SoundFontEditor)
    case tagsEditor(TagsEditor)
  }

  @ObservableState
  struct State: Equatable {
    @Presents var destination: Destination.State?
    @ObservationStateIgnored
    @FetchAll var soundFontInfos: [SoundFontInfo]

    var soundFontsList: SoundFontsList.State = .init()
    var presetsList: PresetsList.State = .init()
    var tagsList: TagsList.State = .init()
    var toolBar: ToolBarFeature.State = .init()
    var tagsSplit: SplitViewReducer.State
    var presetsSplit: SplitViewReducer.State
    var keyboard: KeyboardFeature.State = .init()
    var synth: SynthFeature.State = .init()
    var delay: DelayFeature.State = .init()
    var reverb: ReverbFeature.State = .init()

    init() {
      _soundFontInfos = FetchAll(SoundFontInfo.taggedQuery, animation: .default)

      @Shared(.fontsAndTagsSplitPosition) var fontsAndTagsPosition
      @Shared(.tagsListVisible) var tagsListVisible
      self.tagsSplit = .init(panesVisible: tagsListVisible ? .both : .primary, initialPosition: fontsAndTagsPosition)

      @Shared(.fontsAndPresetsSplitPosition) var fontsAndPresetsPosition
      self.presetsSplit = .init(panesVisible: .both, initialPosition: fontsAndPresetsPosition)

      // destination = .settings(SettingsFeature.State(midi: midi, midiMonitor: midiMonitor))
    }
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case delay(DelayFeature.Action)
    case destination(PresentationAction<Destination.Action>)
    case initialize
    case keyboard(KeyboardFeature.Action)
    case presetsList(PresetsList.Action)
    case presetsSplit(SplitViewReducer.Action)
    case reverb(ReverbFeature.Action)
    case scenePhaseChanged(ScenePhase)
    case soundFontsList(SoundFontsList.Action)
    case synth(SynthFeature.Action)
    case tagsList(TagsList.Action)
    case tagsSplit(SplitViewReducer.Action)
    case toolBar(ToolBarFeature.Action)
  }

  var body: some ReducerOf<Self> {
    BindingReducer()

    Scope(state: \.delay, action: \.delay) { DelayFeature() }
    Scope(state: \.keyboard, action: \.keyboard) { KeyboardFeature() }
    Scope(state: \.presetsList, action: \.presetsList) { PresetsList() }
    Scope(state: \.presetsSplit, action: \.presetsSplit) { SplitViewReducer() }
    Scope(state: \.reverb, action: \.reverb) { ReverbFeature() }
    Scope(state: \.soundFontsList, action: \.soundFontsList) { SoundFontsList() }
    Scope(state: \.synth, action: \.synth) { SynthFeature() }
    Scope(state: \.tagsList, action: \.tagsList) { TagsList() }
    Scope(state: \.tagsSplit, action: \.tagsSplit) { SplitViewReducer() }
    Scope(state: \.toolBar, action: \.toolBar) { ToolBarFeature() }

    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case .delay:
        return .none

      case .destination(.dismiss):
        return destinationDismissed(&state)

      case .destination:
        return .none

      case .initialize:
        volumeMonitor.start()
        return reduce(into: &state, action: .synth(.initialize))

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
      }
    }.ifLet(\.$destination, action: \.destination)
  }

  @Shared(.firstVisibleKey) var firstVisibleKey
}

private extension AppFeature {

  func destinationDismissed(_ state: inout State) -> Effect<Action> {
    switch state.destination {
    case let .presetEditor(editor): return editorDismissed(&state, editor: editor)
    case .settings: return reduce(into: &state, action: .presetsList(.fetchPresets))
    default: return .none
    }
  }

  func editorDismissed(_ state: inout State, editor: PresetEditor.State) -> Effect<Action> {
    guard let sectionIndex = state.presetsList.sections.index(id: editor.sectionId),
          let rowIndex = state.presetsList.sections[sectionIndex].rows.index(id: editor.preset.id)
    else {
      fatalError("unexpected indexing failure")
    }

    state.presetsList.sections[sectionIndex].rows[rowIndex].preset.displayName = editor.displayName
    return .none
  }

  func monitorKeyboardAction(_ state: inout State, action: KeyboardFeature.Action.Delegate) -> Effect<Action> {
    if case let .visibleKeyRangeChanged(lowest, highest) = action {
      $firstVisibleKey.withLock { $0 = lowest }
      return reduce(into: &state, action: .toolBar(.setVisibleKeyRange(lowest: lowest, highest: highest)))
    }
    return .none
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
      state.toolBar.$tagsListVisible.withLock { $0 = visible }
      @Shared(.tagsListVisible) var tagsListVisible
      $tagsListVisible.withLock { $0 = panesVisible.contains(.bottom) }
      @Shared(.fontsAndTagsSplitPosition) var fontsAndTagsSplitPosition
      $tagsListVisible.withLock { $0 = visible }
      $fontsAndTagsSplitPosition.withLock { $0 = position }
    }
    return .none
  }

  func monitorToolBarAction(_ state: inout State, action: ToolBarFeature.Action.Delegate) -> Effect<Action> {
    switch action {

    case let .editingPresetVisibilityChanged(active):
      return reduce(into: &state, action: .presetsList(.visibilityEditModeChanged(active)))

    case let .effectsVisibilityChanged(visible):
      @Shared(.effectsVisible) var effectsVisible
      $effectsVisible.withLock { $0 = visible }
      return .none

    case .presetNameTapped:
      return .merge(
        reduce(into: &state, action: .presetsList(.showActivePreset)),
        reduce(into: &state, action: .soundFontsList(.showActiveSoundFont))
      )

    case .settingsButtonTapped:
      state.destination = .settings(SettingsFeature.State())
      return .none

    case .settingsDismissed:
      state.destination = nil
      return .none

    case let .tagsVisibilityChanged(visible):
      let panes: SplitViewPanes = visible ? .both : .primary
      return reduce(into: &state, action: .tagsSplit(.updatePanesVisibility(panes)))

    case let .visibleKeyRangeChanged(lowest, _):
      $firstVisibleKey.withLock { $0 = lowest }
      return reduce(into: &state, action: .keyboard(.scrollTo(lowest)))
    }
  }

  func scenePhaseChanged(_ state: inout State, phase: ScenePhase) -> Effect<Action> {
    @Shared(.backgroundProcessing) var backgroundProcessing
    switch phase {
    case .active:
      guard !backgroundProcessing else { return .none }
      return reduce(into: &state, action: .synth(.becameActive))
    case .background, .inactive:
      guard !backgroundProcessing else { return .none }
      return reduce(into: &state, action: .synth(.becameInactive))
    @unknown default: fatalError("Unhandled ScenePhase \(phase):")
    }
  }
}

struct AppFeatureView: View, KeyboardReadable {
  @Environment(\.scenePhase) var scenePhase
  @Bindable private var store: StoreOf<AppFeature>
  private let theme: Theme
  private let appPanelBackground = Color.black
  private let dividerBorderColor: Color = Color.gray.opacity(0.15)
  @State private var isInputKeyboardVisible = false
  @State private var effectsOffset: CGFloat = 0.0

  @Shared(.effectsVisible) private var effectsVisible
  @Environment(\.keyboardHeight) private var maxKeyboardHeight
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.verticalSizeClass) private var verticalSizeClass

  private var showFakeKeyboard: Bool {
    horizontalSizeClass == .compact || verticalSizeClass == .compact
  }

  private var keyboardHeight: CGFloat {
    isInputKeyboardVisible
    ? 1.0
    : maxKeyboardHeight * (verticalSizeClass == .compact ? 0.5 : 1.0)
  }

  init(store: StoreOf<AppFeature>) {
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

  var body: some View {

    // let _ = Self._printChanges()
    VStack(spacing: 0) {
      listViews
      effectsView
        .knobNativeValueEditorHost()
      toolbarAndKeyboard
    }
    .padding(0)
    .animation(.smooth, value: effectsVisible)
    .animation(.smooth, value: isInputKeyboardVisible)
    .environment(\.auv3ControlsTheme, theme)
    .environment(\.appPanelBackground, appPanelBackground)
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active {
        print("Active")
      } else if newPhase == .inactive {
        print("Inactive")
      } else if newPhase == .background {
        print("Background")
      }
    }
    .task {
      await store.send(.initialize).finish()
    }
    .onReceive(keyboardPublisher) {
      isInputKeyboardVisible = $0
    }
    .destinations(
      store: $store,
      horizontalSizeClass: horizontalSizeClass,
      verticalSizeClass: verticalSizeClass
    )
  }

  private var listViews: some View {
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
    ).splitViewConfiguration(.init(orientation: .horizontal, draggableRange: 0.35...0.7))
  }

  private var fontsAndTags: some View {
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
        draggableRange: 0.3...0.7,
        dragToHidePanes: .secondary,
        doubleClickToClose: .secondary
      )
    )
  }

  private var handleDivider: some View {
    HandleDivider(
      dividerColor: dividerBorderColor,
      handleColor: .black,
      dotColor: .accentColor,
      handleLength: 48,
      handleWidth: 8.0,
      paddingInsets: 4.0
    )
  }

  private var effectsView: some View {
    let effectsHeight = 110.0
    let padding = 4.0
    let viewHeight = effectsHeight + padding * 4

    return VStack {
      ScrollView(.horizontal) {
        HStack {
          ReverbView(store: store.scope(state: \.reverb, action: \.reverb))
          dividerBorderColor
            .frame(width: padding)
          DelayView(store: store.scope(state: \.delay, action: \.delay))
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
      .opacity(effectsVisible ? 1.0 : 0.0)
    }
    .frame(height: effectsVisible ? viewHeight : padding)
    .offset(x: 0, y: effectsVisible ? 0.0 : viewHeight / 2 - padding - 1)
  }

  private var toolbarAndKeyboard: some View {
    VStack {
      ToolBarFeatureView(store: store.scope(state: \.toolBar, action: \.toolBar))
      keyboardView
    }
  }

  private var keyboardView: some View {
    KeyboardView(store: store.scope(state: \.keyboard, action: \.keyboard))
      .frame(height: keyboardHeight)
      .opacity(isInputKeyboardVisible ? 0.0 : 1.0)
  }
}

extension View {
  func destinations(
    store: Bindable<StoreOf<AppFeature>>,
    horizontalSizeClass: UserInterfaceSizeClass?,
    verticalSizeClass: UserInterfaceSizeClass?
  ) -> some View {
    self
      .sheet(item: store.scope(state: \.destination?.presetEditor, action: \.destination.presetEditor)) {
        PresetEditorView(store: $0)
          .preferredColorScheme(.dark)
          .environment(\.colorScheme, .dark)
      }
      .sheet(item: store.scope(state: \.destination?.settings, action: \.destination.settings)) {
        SettingsView(store: $0, showFakeKeyboard: horizontalSizeClass == .compact || verticalSizeClass == .compact)
          .preferredColorScheme(.dark)
          .environment(\.colorScheme, .dark)
      }
      .sheet(item: store.scope(state: \.destination?.soundFontEditor, action: \.destination.soundFontEditor)) {
        SoundFontEditorView(store: $0)
          .preferredColorScheme(.dark)
          .environment(\.colorScheme, .dark)
      }
      .sheet(item: store.scope(state: \.destination?.tagsEditor, action: \.destination.tagsEditor)) {
        TagsEditorView(store: $0)
          .preferredColorScheme(.dark)
          .environment(\.colorScheme, .dark)
      }
  }
}

extension AppFeatureView {

  static var preview: some View {
    prepareDependencies {
      // swiftlint:disable:next force_try
      $0.defaultDatabase = try! appDatabase()
      $0.parameters = ParameterAddress.createParameterTree()
      $0.delayDevice = .init(setConfig: { print("delayDevice.set: ", $0) })
      $0.reverbDevice = .init(setConfig: { print("reverbDevice.set: ", $0) })
      navigationBarTitleStyle()
    }

    return ZStack {
      Color.black
        .ignoresSafeArea(edges: .all)
      AppFeatureView(store: Store(initialState: .init()) { AppFeature() })
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)
    }
  }
}

#Preview {
  AppFeatureView.preview
}
