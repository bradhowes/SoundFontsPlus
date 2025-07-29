// Copyright © 2025 Brad Howes. All rights reserved.

import AudioUnit.AUParameters
import AUv3Controls
import BRHSplitView
import ComposableArchitecture
import SharingGRDB
import Sharing
import SwiftUI
import UniformTypeIdentifiers

@Reducer
public struct AppFeature {
  @Dependency(\.parameters) private var parameters
  private let volumeMonitor: VolumeMonitor = .init()

  var state: State { .init(parameters: parameters) }

  @Reducer(state: .equatable, .sendable, action: .equatable)
  public enum Destination {
    case presetEditor(PresetEditor)
    case settings(SettingsFeature)
    case soundFontEditor(SoundFontEditor)
    case tagsEditor(TagsEditor)
  }

  @ObservableState
  public struct State: Equatable {
    @Presents var destination: Destination.State?

    @ObservationStateIgnored
    @FetchAll var soundFontInfos: [SoundFontInfo]

    public var soundFontsList: SoundFontsList.State = .init()
    public var presetsList: PresetsList.State = .init()
    public var tagsList: TagsList.State = .init()
    public var toolBar: ToolBar.State
    public var tagsSplit: SplitViewReducer.State
    public var presetsSplit: SplitViewReducer.State
    public var delay: DelayFeature.State
    public var reverb: ReverbFeature.State
    public var keyboard: KeyboardFeature.State = .init()

    public var addSoundFonts: Bool = false
    public var addedSummary: String?

    public init(parameters: AUParameterTree) {
      _soundFontInfos = FetchAll(SoundFontInfo.taggedQuery, animation: .default)

      @Shared(.fontsAndPresetsSplitPosition) var fontsAndPresetsPosition
      @Shared(.fontsAndTagsSplitPosition) var fontsAndTagsPosition
      @Shared(.tagsListVisible) var tagsListVisible
      @Shared(.effectsVisible) var effectsVisible

      self.tagsSplit = .init(panesVisible: tagsListVisible ? .both : .primary, initialPosition: fontsAndTagsPosition)
      self.presetsSplit = .init(panesVisible: .both, initialPosition: fontsAndPresetsPosition)
      self.toolBar = ToolBar.State(tagsListVisible: tagsListVisible, effectsVisible: effectsVisible)

      self.delay = DelayFeature.State(parameters: parameters)
      self.reverb = ReverbFeature.State(parameters: parameters)
    }
  }

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case delay(DelayFeature.Action)
    case destination(PresentationAction<Destination.Action>)
    case importFile(Result<URL, Error>)
    case keyboard(KeyboardFeature.Action)
    case phaseChange(ScenePhase)
    case presetsList(PresetsList.Action)
    case presetsSplit(SplitViewReducer.Action)
    case reverb(ReverbFeature.Action)
    case soundFontsList(SoundFontsList.Action)
    case tagsList(TagsList.Action)
    case tagsSplit(SplitViewReducer.Action)
    case toolBar(ToolBar.Action)
  }

  public var body: some ReducerOf<Self> {

    BindingReducer()

    Scope(state: \.delay, action: \.delay) { DelayFeature(parameters: parameters) }
    Scope(state: \.keyboard, action: \.keyboard) { KeyboardFeature() }
    Scope(state: \.presetsList, action: \.presetsList) { PresetsList() }
    Scope(state: \.presetsSplit, action: \.presetsSplit) { SplitViewReducer() }
    Scope(state: \.reverb, action: \.reverb) { ReverbFeature(parameters: parameters) }
    Scope(state: \.soundFontsList, action: \.soundFontsList) { SoundFontsList() }
    Scope(state: \.tagsList, action: \.tagsList) { TagsList() }
    Scope(state: \.tagsSplit, action: \.tagsSplit) { SplitViewReducer() }
    Scope(state: \.toolBar, action: \.toolBar) { ToolBar() }

    Reduce { state, action in
      switch action {
      case .binding: return .none
      case .delay: return .none
      case .destination(.dismiss): return dismissingSheet(&state)
      case .destination: return .none
      case let .keyboard(.delegate(action)): return keyboardAction(&state, action: action)
      case .keyboard: return .none
      case let .importFile(result): return importFile(&state, result: result)
      case let .phaseChange(phase): return phaseChange(&state, phase: phase)
      case let .presetsList(.delegate(.edit(sectionId, preset))):
        return editPreset(&state, sectionId: sectionId, preset: preset)
      case .presetsList: return .none
      case let .presetsSplit(.delegate(action)): return presetsSplitAction(&state, action: action)
      case .presetsSplit: return .none
      case .reverb: return .none
      case let .soundFontsList(.delegate(.edit(soundFont))): return editFont(&state, soundFont: soundFont)
      case .soundFontsList: return .none
      case let .tagsList(.delegate(.edit(focused))): return editTags(&state, focused: focused)
      case .tagsList: return .none
      case let .tagsSplit(.delegate(action)): return tagsSplitAction(&state, action: action)
      case .tagsSplit: return .none
      case let .toolBar(.delegate(action)): return toolBarAction(&state, action: action)
      case .toolBar: return .none
      }
    }.ifLet(\.$destination, action: \.destination)
  }

  public init() {
    volumeMonitor.start()
  }

  @Shared(.firstVisibleKey) var firstVisibleKey
}

extension AppFeature {

  func dismissingSheet(_ state: inout State) -> Effect<Action> {
    switch state.destination {
    case let .presetEditor(editor): return dismissingEditor(&state, editor: editor)
    case .settings: return reduce(into: &state, action: .presetsList(.fetchPresets))
    case .soundFontEditor: return .none
    case .tagsEditor: return .none
    case nil: return .none
    }
  }

  func dismissingEditor(_ state: inout State, editor: PresetEditor.State) -> Effect<Action> {
    guard let sectionIndex = state.presetsList.sections.index(id: editor.sectionId),
          let rowIndex = state.presetsList.sections[sectionIndex].rows.index(id: editor.preset.id)
    else {
      fatalError("unexpected indexing failure")
    }

    state.presetsList.sections[sectionIndex].rows[rowIndex].preset.displayName = editor.displayName
    return .none
  }

  func editPreset(_ state: inout State, sectionId: Int, preset: Preset) -> Effect<Action> {
    state.destination = .presetEditor(PresetEditor.State(sectionId: sectionId, preset: preset))
    return .none
  }

  func editFont(_ state: inout State, soundFont: SoundFont) -> Effect<Action> {
    state.destination = .soundFontEditor(SoundFontEditor.State(soundFont: soundFont))
    return .none
  }

  func editTags(_ state: inout State, focused: TagInfo.ID? = nil) -> Effect<Action> {
    state.destination = .tagsEditor(TagsEditor.State(mode: .tagEditing, focused: focused))
    return .none
  }

  private func importFile(_ state: inout State, result: Result<URL, Error>) -> Effect<Action> {
    switch result {
    case .success(let url):
      do {
        let displayName = try SoundFontsSupport.addSoundFont(url: url, copyFileWhenAdding: true)
        state.addedSummary = "Added sound font \(displayName)."
      } catch {
        state.addedSummary = "Failed to add sound font: \(error)"
      }
    case .failure(let error):
      state.addedSummary = "Failed to add sound font: \(error)"
    }

    return .none
  }

  private func keyboardAction(_ state: inout State, action: KeyboardFeature.Action.Delegate) -> Effect<Action> {
    switch action {
    case let .visibleKeyRangeChanged(lowest, highest):
      $firstVisibleKey.withLock { $0 = lowest }
      print("lowest:", lowest)
      return reduce(into: &state, action: .toolBar(.setVisibleKeyRange(lowest: lowest, highest: highest)))
    }
  }

  private func phaseChange(_ state: inout State, phase: ScenePhase) -> Effect<Action> {
    switch phase {
    case .active: return .none
    case .background: return .none
    case .inactive: return .none
    @unknown default: fatalError("Unhandled ScenePhase \(phase):")
    }
  }

  private func presetsSplitAction(_ state: inout State, action: SplitViewReducer.Action.Delegate) -> Effect<Action> {
    switch action {
    case let .stateChanged(_, position):
      @Shared(.fontsAndPresetsSplitPosition) var fontsAndPresetsSplitPosition
      $fontsAndPresetsSplitPosition.withLock { $0 = position }
      return .none
    }
  }

  private func tagsSplitAction(_ state: inout State, action: SplitViewReducer.Action.Delegate) -> Effect<Action> {
    switch action {
    case let .stateChanged(panesVisible, position):
      let visible = panesVisible.contains(.bottom)
      ToolBar.setTagsListVisible(&state.toolBar, value: visible)
      @Shared(.tagsListVisible) var tagsListVisible
      $tagsListVisible.withLock { $0 = panesVisible.contains(.bottom) }
      @Shared(.fontsAndTagsSplitPosition) var fontsAndTagsSplitPosition
      $tagsListVisible.withLock { $0 = visible }
      $fontsAndTagsSplitPosition.withLock { $0 = position }
      return .none
    }
  }

  private func toolBarAction(_ state: inout State, action: ToolBar.Action.Delegate) -> Effect<Action> {
    switch action {
    case .addSoundFontButtonTapped:
      state.addSoundFonts = true
      return .none
    case let .editingPresetVisibility(active): return setEditingVisibility(&state, active: active)
    case let .effectsVisibilityChanged(visible): return setEffectsVisibiliy(&state, visible: visible)
    case .presetNameTapped: return showActivePreset(&state)
    case .settingsDismissed: return dismissSettingsEditor(&state)
    case .settingsButtonTapped: return showSettingsEditor(&state)
    case let .tagsVisibilityChanged(visible): return setTagsVisibility(&state, visible: visible)
    case let .visibleKeyRangeChanged(lowest, _):
      print("lowest:", lowest)
      $firstVisibleKey.withLock { $0 = lowest }
      return reduce(into: &state, action: .keyboard(.scrollTo(lowest)))
    }
  }

  private func dismissSettingsEditor(_ state: inout State) -> Effect<Action> {
    state.destination = nil
    return fetchPresets(&state)
  }

  private func showSettingsEditor(_ state: inout State) -> Effect<Action> {
    state.destination = .settings(SettingsFeature.State())
    return .none
  }

  private func fetchPresets(_ state: inout State) -> Effect<Action> {
    return reduce(into: &state, action: .presetsList(.fetchPresets))
  }

  private func setEditingVisibility(_ state: inout State, active: Bool) -> Effect<Action> {
    return reduce(into: &state, action: .presetsList(.visibilityEditModeChanged(active)))
  }

  private func setTagsVisibility(_ state: inout State, visible: Bool) -> Effect<Action> {
    let panes: SplitViewPanes = visible ? .both : .primary
    return reduce(into: &state, action: .tagsSplit(.updatePanesVisibility(panes)))
  }

  private func setEffectsVisibiliy(_ state: inout State, visible: Bool) -> Effect<Action> {
    @Shared(.effectsVisible) var effectsVisible
    $effectsVisible.withLock { $0 = visible }
    return .none
  }

  private func showActivePreset(_ state: inout State) -> Effect<Action> {
    return .merge(
      reduce(into: &state, action: .presetsList(.showActivePreset)),
      reduce(into: &state, action: .soundFontsList(.showActiveSoundFont))
    )
  }
}

public struct RootAppView: View, KeyboardReadable {
  @Environment(\.scenePhase) var scenePhase
  @Bindable private var store: StoreOf<AppFeature>
  private let theme: Theme
  private let appPanelBackground = Color.black
  private let dividerBorderColor: Color = Color.gray.opacity(0.15)
  @State private var isInputKeyboardVisible = false

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

  public init(store: StoreOf<AppFeature>) {
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
    let types = ["com.braysoftware.sf2", "com.soundblaster.soundfont"].compactMap { UTType($0) }

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
    .onReceive(keyboardPublisher) {
      isInputKeyboardVisible = $0
    }
    .destinations(store: $store, horizontalSizeClass: horizontalSizeClass, verticalSizeClass: verticalSizeClass)
    .fileImporter(
      isPresented: $store.addSoundFonts,
      allowedContentTypes: types
    ) { result in
      store.send(.importFile(result))
    }
    .alert("Add Complete", isPresented: Binding<Bool>(
      get: { store.addedSummary != nil },
      set: { _ in store.addedSummary = nil }
    )) {
      Button("OK") {}
    } message: {
      Text(store.addedSummary ?? "")
    }
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
    }
    .frame(height: effectsVisible ? viewHeight : padding)
    .offset(x: 0.0, y: effectsVisible ? 0.0 : viewHeight / 2 - padding - 1)
    .clipped()
  }

  private var toolbarAndKeyboard: some View {
    VStack {
      ToolBarView(store: store.scope(state: \.toolBar, action: \.toolBar))
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

extension RootAppView {

  static var preview: some View {
    prepareDependencies {
      // swiftlint:disable:next force_try
      $0.defaultDatabase = try! appDatabase()
      $0.parameters = ParameterAddress.createParameterTree()
      $0.delayDevice = .init(getConfig: { DelayConfig.Draft() }, setConfig: { print("delayDevice.set: ", $0) })
      $0.reverbDevice = .init(getConfig: { ReverbConfig.Draft() }, setConfig: { print("reverbDevice.set: ", $0) })
      navigationBarTitleStyle()
    }

    let rootApp = AppFeature()
    return ZStack {
      Color.black
        .ignoresSafeArea(edges: .all)
      RootAppView(store: Store(initialState: rootApp.state) { rootApp })
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)
    }
  }
}

#Preview {
  RootAppView.preview
}
