// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Controls
import AVFoundation
import AudioUnit.AUParameters
import BRHSplitView
import FeatureSupport
import Presets
import SF2LibAU
import SQLiteData
import Settings
import SoundFonts
import SwiftUI
import Tags
import ToolBar
import UniformTypeIdentifiers

/**
 The top-level feature of the AUv3 extension.
 */
@Reducer
public struct AUv3Root {

  public static func prepareDependencies() {
    Dependencies.prepareDependencies {
      @Shared(.isAUv3) var isAUv3 = true
      @Shared(.activeState) var activeState
      $activeState.withLock { $0 = .none }

      // swiftlint:disable:next force_try
      $0.defaultDatabase = try! appDatabase()
      $0.defaultFileStorage = .fileSystem
      $0.synthAUv3ComponentDescription = SynthAUv3ComponentDescription.liveValue
    }
  }

  /**
   The various editors and presenters that appear in a modal way when created and presented.
   */
  @Reducer
  public enum Destination {
    case presetEditor(PresetEditor)
    case settings(AppSettings)
    case soundFontEditor(SoundFontEditor)
    case tagsEditor(TagsEditor)
  }

  @ObservableState
  public struct State: Equatable {
    @Presents public var destination: Destination.State?
    public var loadedSoundFontId: SoundFont.ID?
    public var loadedPresetIndex: Int?

    public var fontsAndPresetsSplit: SplitViewReducer.State
    public var fontsAndTagsSplit: SplitViewReducer.State
    public var presetsList: PresetsList.State
    public var soundFontsList: SoundFontsList.State
    public var tagsList: TagsList.State
    public var toolBar: ToolBar.State
    public var audioUnit: SF2LibAU
    public var crashed: Bool = false

    public init(
      audioUnit: SF2LibAU,
      destination: Destination.State? = nil,
      fontsAndPresetsSplit: SplitViewReducer.State? = nil,
      fontsAndTagsSplit: SplitViewReducer.State? = nil,
      presetsList: PresetsList.State? = nil,
      soundFontsList: SoundFontsList.State? = nil,
      tagsList: TagsList.State? = nil,
      toolBar: ToolBar.State? = nil
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
      return .init(
        panesVisible: .both,
        initialPosition: 0.5
      )
    }

    static public func makeFontsAndTagsSplitState() -> SplitViewReducer.State {
      return .init(
        panesVisible: .primary,
        initialPosition: 0.4
      )
    }
  }

  public enum Action: BindableAction {
    case activePresetIdChanged(Preset.ID?)
    case binding(BindingAction<State>)
    case crashNotificationReceived
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

  public var body: some ReducerOf<Self> {
    BindingReducer()

    Scope(state: \.fontsAndPresetsSplit, action: \.fontsAndPresetsSplit) { SplitViewReducer() }
    Scope(state: \.fontsAndTagsSplit, action: \.fontsAndTagsSplit) { SplitViewReducer() }
    Scope(state: \.presetsList, action: \.presetsList) { PresetsList() }
    Scope(state: \.soundFontsList, action: \.soundFontsList) { SoundFontsList() }
    Scope(state: \.tagsList, action: \.tagsList) { TagsList() }
    Scope(state: \.toolBar, action: \.toolBar) { ToolBar() }

    Reduce { state, action in
      log.debug("reduce \(action)")

      switch action {

      case .activePresetIdChanged(let presetId):
        return useActivePreset(&state, presetId: presetId)

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
    }
    .ifLet(\.$destination, action: \.destination)
  }

  private enum CancelId: String, CaseIterable {
    case auV3RootCreateCloudDocumentsDirectory
    case auV3RootMonitorActivePresetId
  }
}

extension AUv3Root {

  private func destinationDismissed(_ state: inout State) -> Effect<Action> {
    switch state.destination {

    case .presetEditor(let editor):
      return editorDismissed(&state, editor: editor)

    case .settings:
      return reduce(into: &state, action: .presetsList(.fetchPresets))

    default:
      return .none
    }
  }

  private func editorDismissed(_ state: inout State, editor: PresetEditor.State) -> Effect<Action> {
    if editor.visible {
      state.presetsList.updateSection(editor.sectionId, presetId: editor.preset.id, displayName: editor.displayName)
      return .none
    }
    return reduce(into: &state, action: .presetsList(.fetchPresets))
  }

  private func initialize(_ state: inout State) -> Effect<Action> {
    return .none // monitorActivePresetId()
  }

//  private func monitorActivePresetId() -> Effect<Action> {
//    .publisher {
//      $activeState.activePresetId
//        .publisher
//        .removeDuplicates()
//        .map { .activePresetIdChanged($0) }
//    }.cancellable(id: CancelId.monitorActivePresetId, cancelInFlight: true)
//  }

  private func processFontsAndTagsSplitAction(
    _ state: inout State,
    action: SplitViewReducer.Action.Delegate
  ) -> Effect<Action> {
    if case .stateChanged(let panesVisible, _) = action {
      let visible = panesVisible.contains(.bottom)
      state.toolBar.setTagsListVisible(visible)
    }
    return .none
  }

  private func processSettingsAction(_ state: inout State, action: AppSettings.Action.Delegate) -> Effect<Action> {
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
      state.destination = .settings(AppSettings.State())
      return .none

    case .tagsListVisibilityChanged(let visible):
      let panes: SplitViewPanes = visible ? .both : .primary
      return reduce(into: &state, action: .fontsAndTagsSplit(.updatePanesVisibility(panes)))

    case .effectsVisibilityChanged:
      fatalError("misconfiguration for AUv3Root")

    case .visibleKeyRangeChanged:
      fatalError("misconfiguration for AUv3Root")
    }
  }

  private func useActivePreset(_ state: inout State, presetId: Preset.ID?) -> Effect<Action> {
    log.info("useActivePreset BEGIN - presetId: \(presetId ?? -1)")

    guard let presetInfo = Operations.presetLoadingInfo(id: presetId) else {
      log.info("useActivePreset END - no presetInfo")
      return .none
    }

    guard state.loadedPresetIndex != presetInfo.presetIndex || state.loadedSoundFontId != presetInfo.soundFontId else {
      log.info("useActivePreset END - already loaded")
      return .none
    }

    var result: Bool = false
    if presetInfo.soundFontId == state.loadedSoundFontId {
      log.info("useActivePreset - loading preset \(presetInfo.presetIndex) \(presetInfo.presetName)")
      // result = state.audioUnit.sendUsePreset(preset: presetInfo.presetIndex, gain: 0.0, pan: 0.0)
    } else {
      guard let location = try? SoundFontKind(
        kind: presetInfo.kind,
        location: presetInfo.location,
        displayName: presetInfo.soundFontName
      )
      else {
        log.error("useActivePreset END - unexpected nil location for \(presetInfo)")
        return .none
      }
      let path = location.path.path(percentEncoded: false)
      log.info("useActivePreset - loading \(path) -- preset \(presetInfo.presetIndex) \(presetInfo.presetName)")
//      result = state.audioUnit.sendLoadFileUsePreset(
//        path: path,
//        preset: presetInfo.presetIndex,
//        gain: presetInfo.gain,
//        pan: presetInfo.pan
//      )
    }

    state.audioUnit.audioUnitShortName = presetInfo.presetName

    state.loadedPresetIndex = presetInfo.presetIndex
    state.loadedSoundFontId = presetInfo.soundFontId

    log.info("useActivePreset END - \(result)")

    return reduce(into: &state, action: .toolBar(.activePresetIdChanged(presetId)))
  }
}

extension AUv3Root.Destination.State: Equatable {}

public struct AUv3RootView: View {
  @Bindable private var store: StoreOf<AUv3Root>
  private let theme: Theme
  private let appPanelBackground = Color.black
  private let dividerBorderColor: Color = Color.gray.mix(with: .black, by: 0.7)
  private let dividerSpan: CGFloat = 4

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
    .environment(\.auv3ControlsTheme, theme)
    .environment(\.appPanelBackground, appPanelBackground)
    .task {
      await store.send(.initialize).finish()
    }
    .sheets(store: $store)
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
   - returns: modified view
   */
  fileprivate func sheets(store: Bindable<StoreOf<AUv3Root>>) -> some View {
    self
      .presetEditorSheet(store)
      .settingsSheet(store)
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

  fileprivate func settingsSheet(_ store: Bindable<StoreOf<AUv3Root>>) -> some View {
    self
      .sheet(item: store.scope(state: \.destination?.settings, action: \.destination.settings)) {
        AppSettingsView(store: $0, showFakeKeyboard: false)
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
      $0.synthAUv3ComponentDescription = SynthAUv3ComponentDescription.previewValue
      @Shared(.tagsListVisible) var tagsListVisible
      $tagsListVisible.withLock { $0 = false }
    }

    // swiftlint:disable:next force_try
    let audioUnit = try! SF2LibAU(componentDescription: SynthAUv3ComponentDescription.previewValue)

    return ZStack {
      Color.black
        .ignoresSafeArea(edges: .all)
      AUv3RootView(store: Store(initialState: .init(audioUnit: audioUnit)) { AUv3Root() })
        // .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)
    }
  }
}

#Preview {
  AUv3RootView.preview
}

private let log = Logger(category: "AUv3Root")
