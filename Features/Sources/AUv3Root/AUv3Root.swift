// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Controls
import AVFoundation
import AudioUnit.AUParameters
import BRHSplitView
import FeatureSupport
import Presets
import SQLiteData
import Settings
import SoundFonts
import Tags
import ToolBar
import UniformTypeIdentifiers

/**
 The top-level feature of the application.
 */
@Reducer
public struct AUv3Root {

  /**
   The various editors and presenters that appear in a modal way when created and presented.
   */
  @Reducer
  public enum Destination {
    case presetEditor(PresetEditor)
    case settings(Settings)
    case soundFontEditor(SoundFontEditor)
    case tagsEditor(TagsEditor)
  }

  @ObservableState
  public struct State: Equatable {
    @Presents public var destination: Destination.State?
    public var fontsAndPresetsSplit: SplitViewReducer.State
    public var fontsAndTagsSplit: SplitViewReducer.State
    public var presetsList: PresetsList.State
    public var soundFontsList: SoundFontsList.State
    public var tagsList: TagsList.State
    public var toolBar: ToolBar.State

    public init(
      destination: Destination.State? = nil,
      fontsAndPresetsSplit: SplitViewReducer.State? = nil,
      fontsAndTagsSplit: SplitViewReducer.State? = nil,
      presetsList: PresetsList.State? = nil,
      soundFontsList: SoundFontsList.State? = nil,
      tagsList: TagsList.State? = nil,
      toolBar: ToolBar.State? = nil
    ) {
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

  @Shared(.activeState) private var activeState
  @Shared(.fontsAndPresetsSplitPosition) private var fontsAndPresetsSplitPosition
  @Shared(.fontsAndTagsSplitPosition) private var fontsAndTagsSplitPosition
  @Shared(.tagsListVisible) private var tagsListVisible

  public var body: some ReducerOf<Self> {
    BindingReducer()

    Scope(state: \.presetsList, action: \.presetsList) { PresetsList() }
    Scope(state: \.soundFontsList, action: \.soundFontsList) { SoundFontsList() }
    Scope(state: \.tagsList, action: \.tagsList) { TagsList() }
    Scope(state: \.toolBar, action: \.toolBar) { ToolBar() }

    Scope(state: \.fontsAndPresetsSplit, action: \.fontsAndPresetsSplit) { SplitViewReducer() }
    Scope(state: \.fontsAndTagsSplit, action: \.fontsAndTagsSplit) { SplitViewReducer() }

    Reduce { state, action in
      log.info("reduce \(action)")
      switch action {

      case .activePresetIdChanged(let presetId):
        return reduce(into: &state, action: .toolBar(.activePresetIdChanged(presetId)))

      case .deinitialize:
        return .merge(
          .merge(CancelId.allCases.map { .cancel(id: $0) }),
          reduce(into: &state, action: .toolBar(.deinitialize)),
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

      case .tagsList(.delegate(.edit(let focused))):
        state.destination = .tagsEditor(TagsEditor.State(mode: .tagEditing, focused: focused))
        return .none

      case .toolBar(.delegate(let action)):
        return processToolBarAction(&state, action: action)

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

extension AUv3Root {

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
    return monitorActivePresetId()
  }

  fileprivate func monitorActivePresetId() -> Effect<Action> {
    .publisher {
      $activeState.activePresetId
        .publisher
        .removeDuplicates()
        .map { .activePresetIdChanged($0) }
    }.cancellable(id: CancelId.monitorActivePresetId, cancelInFlight: true)
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
    return .none
  }

  fileprivate func processToolBarAction(_ state: inout State, action: ToolBar.Action.Delegate) -> Effect<Action> {
    switch action {

    case .editingPresetVisibilityChanged(let active):
      return reduce(into: &state, action: .presetsList(.visibilityEditModeChanged(active)))

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

    case .effectsVisibilityChanged:
      fatalError("misconfiguration for AUv3Root")

    case .visibleKeyRangeChanged:
      fatalError("misconfiguration for AUv3Root")
    }
  }
}

extension AUv3Root.Destination.State: Equatable {}

public struct AUv3RootView: View {
  @Bindable private var store: StoreOf<AUv3Root>
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

  public init(store: StoreOf<AUv3Root>) {
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
    .task {
      await store.send(.initialize).finish()
    }
    .sheets(
      store: $store,
      horizontalSizeClass: horizontalSizeClass,
      verticalSizeClass: verticalSizeClass
    )
  }
}

extension AUv3RootView {

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
      ToolBarView(store: store.scope(state: \.toolBar, action: \.toolBar))
    }
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
    store: Bindable<StoreOf<AUv3Root>>,
    horizontalSizeClass: UserInterfaceSizeClass?,
    verticalSizeClass: UserInterfaceSizeClass?
  ) -> some View {
    self
      .presetEditorSheet(store)
      .settingsSheet(store, showFakeKeyboard: horizontalSizeClass == .compact || verticalSizeClass == .compact)
      .soundFontEditorSheet(store)
      .tagsEditorSheet(store)
  }

  fileprivate func presetEditorSheet(_ store: Bindable<StoreOf<AUv3Root>>) -> some View {
    self
      .sheet(item: store.scope(state: \.destination?.presetEditor, action: \.destination.presetEditor)) {
        PresetEditorView(store: $0)
          .preferredColorScheme(.dark)
          .environment(\.colorScheme, .dark)
      }
  }

  fileprivate func settingsSheet(_ store: Bindable<StoreOf<AUv3Root>>, showFakeKeyboard: Bool) -> some View {
    self
      .sheet(item: store.scope(state: \.destination?.settings, action: \.destination.settings)) {
        SettingsView(store: $0, showFakeKeyboard: showFakeKeyboard)
          .preferredColorScheme(.dark)
          .environment(\.colorScheme, .dark)
      }
  }

  fileprivate func soundFontEditorSheet(_ store: Bindable<StoreOf<AUv3Root>>) -> some View {
    self
      .sheet(item: store.scope(state: \.destination?.soundFontEditor, action: \.destination.soundFontEditor)) {
        SoundFontEditorView(store: $0)
          .preferredColorScheme(.dark)
          .environment(\.colorScheme, .dark)
      }
  }

  fileprivate func tagsEditorSheet(_ store: Bindable<StoreOf<AUv3Root>>) -> some View {
    self
      .sheet(item: store.scope(state: \.destination?.tagsEditor, action: \.destination.tagsEditor)) { child in
        NavigationStack {
          TagsEditorView(store: child)
            .preferredColorScheme(.dark)
            .environment(\.colorScheme, .dark)
        }
      }
  }
}

extension AUv3RootView {

  static var preview: some View {
    prepareDependencies {
      $0.defaultDatabase = previewDatabase()
      @Shared(.tagsListVisible) var tagsListVisible
      $tagsListVisible.withLock { $0 = false }
    }

    return ZStack {
      Color.black
        .ignoresSafeArea(edges: .all)
      AUv3RootView(store: Store(initialState: .init()) { AUv3Root() })
        // .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)
    }
  }
}

#Preview {
  AUv3RootView.preview
}

private let log = Logger(category: "AUv3Root")
