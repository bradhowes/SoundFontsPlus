// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Controls
import BRHSplitView
import ComposableArchitecture
import Sharing
import SwiftUI

@Reducer
public struct RootApp {

  @Reducer(state: .equatable, .sendable, action: .equatable)
  public enum Destination {
    case settings(SettingsFeature)
  }

  @ObservableState
  public struct State: Equatable {
    @Presents var destination: Destination.State?
    public var soundFontsList: SoundFontsList.State = .init()
    public var presetsList: PresetsList.State = .init()
    public var tagsList: TagsList.State = .init()
    public var toolBar: ToolBar.State
    public var tagsSplit: SplitViewReducer.State
    public var presetsSplit: SplitViewReducer.State
    public var delay: DelayFeature.State = .init()
    public var reverb: ReverbFeature.State = .init()
    public var keyboard: KeyboardFeature.State = .init()

    public init() {
      @Shared(.fontsAndPresetsSplitPosition) var fontsAndPresetsPosition
      @Shared(.fontsAndTagsSplitPosition) var fontsAndTagsPosition
      @Shared(.tagsListVisible) var tagsListVisible
      @Shared(.effectsVisible) var effectsVisible

      self.tagsSplit = .init(panesVisible: tagsListVisible ? .both : .primary, initialPosition: fontsAndTagsPosition)
      self.presetsSplit = .init(panesVisible: .both, initialPosition: fontsAndPresetsPosition)
      self.toolBar = ToolBar.State(tagsListVisible: tagsListVisible, effectsVisible: effectsVisible)
    }
  }

  public enum Action {
    case presetsList(PresetsList.Action)
    case soundFontsList(SoundFontsList.Action)
    case tagsList(TagsList.Action)
    case toolBar(ToolBar.Action)
    case tagsSplit(SplitViewReducer.Action)
    case presetsSplit(SplitViewReducer.Action)
    case delay(DelayFeature.Action)
    case reverb(ReverbFeature.Action)
    case keyboard(KeyboardFeature.Action)
  }

  public var body: some ReducerOf<Self> {
    Scope(state: \.soundFontsList, action: \.soundFontsList) { SoundFontsList() }
    Scope(state: \.presetsList, action: \.presetsList) { PresetsList() }
    Scope(state: \.tagsList, action: \.tagsList) { TagsList() }
    Scope(state: \.toolBar, action: \.toolBar) { ToolBar() }
    Scope(state: \.tagsSplit, action: \.tagsSplit) { SplitViewReducer() }
    Scope(state: \.presetsSplit, action: \.presetsSplit) { SplitViewReducer() }
    Scope(state: \.delay, action: \.delay) { DelayFeature() }
    Scope(state: \.reverb, action: \.reverb) { ReverbFeature() }
    Scope(state: \.keyboard, action: \.keyboard) { KeyboardFeature() }

    Reduce { state, action in
      switch action {

//      case let .keyboard(.delegate(.visibleKeyRangeChanged(lowest, highest))):
//        print("keyboard delegate:", lowest, highest)
//        return reduce(into: &state, action: .toolBar(.setVisibleKeyRange(lowest: lowest, highest: highest)))
//
      case let .tagsSplit(.delegate(.stateChanged(panesVisible, position))):
        let visible = panesVisible.contains(.bottom)
        ToolBar.setTagsListVisible(&state.toolBar, value: visible)
        @Shared(.tagsListVisible) var tagsListVisible
        $tagsListVisible.withLock { $0 = panesVisible.contains(.bottom) }
        @Shared(.fontsAndTagsSplitPosition) var fontsAndTagsSplitPosition
        $tagsListVisible.withLock { $0 = visible }
        $fontsAndTagsSplitPosition.withLock { $0 = position }
        return .none

      case let .presetsSplit(.delegate(.stateChanged(_, position))):
        @Shared(.fontsAndPresetsSplitPosition) var fontsAndPresetsSplitPosition
        $fontsAndPresetsSplitPosition.withLock { $0 = position }
        return .none

      case .toolBar(.tagVisibilityButtonTapped):
        @Shared(.tagsListVisible) var tagsListVisible
        let panes: SplitViewPanes = tagsListVisible ? .both : .primary
        return reduce(into: &state, action: .tagsSplit(.updatePanesVisibility(panes)))

      case let .toolBar(.delegate(action)): return toolBarDelegation(&state, action: action)

      default: return .none
      }
    }
    ._printChanges()
  }

  public init() {}

  private func toolBarDelegation(_ state: inout State, action: ToolBar.Action.Delegate) -> Effect<Action> {
    switch action {
    case let .editingPresetVisibility(active): return setEditingVisibility(&state, active: active)
    case .addSoundFont: return .none
    case .presetNameTapped: return showActivePreset(&state)
    case let .tagsVisibilityChanged(visible): return setTagsVisibility(&state, visible: visible)
    case let .effectsVisibilityChanged(visible): return setEffectsVisibiliy(&state, visible: visible)
    }
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

public struct RootAppView: View {
  private let store: StoreOf<RootApp>
  private let theme: Theme
  private let appPanelBackground = Color.black
  private let dividerBorderColor: Color = Color.gray.opacity(0.15)

  @Shared(.effectsVisible) private var effectsVisible
  @Environment(\.keyboardHeight) private var keyboardHeight
  @Environment(\.verticalSizeClass) private var verticalSizeClass

  public init(store: StoreOf<RootApp>) {
    self.store = store
    var theme = Theme()
    theme.controlForegroundColor = .indigo
    theme.textColor = .indigo
    theme.controlTrackStrokeStyle = StrokeStyle(lineWidth: 5, lineCap: .round)
    theme.controlValueStrokeStyle = StrokeStyle(lineWidth: 3, lineCap: .round)
    theme.toggleOnIndicatorSystemName = "arrowtriangle.down.fill"
    theme.toggleOffIndicatorSystemName = "arrowtriangle.down"
    self.theme = theme
  }

  public var body: some View {
    // let _ = Self._printChanges()
    VStack(spacing: 0) {
      listViews
      effectsView
      toolbarAndKeyboard
    }
    .animation(.smooth, value: effectsVisible)
    .environment(\.auv3ControlsTheme, theme)
    .environment(\.appPanelBackground, appPanelBackground)
  }

  private var listViews: some View {
    SplitView(
      store: store.scope(state: \.presetsSplit, action: \.presetsSplit),
      primary: {
        fontsAndTags
      },
      divider: {
        HandleDivider(
          dividerColor: dividerBorderColor,
          handleColor: .accentColor
        )
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
        HandleDivider(
          dividerColor: dividerBorderColor,
          handleColor: .accentColor
        )
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

  private var effectsView: some View {
    let effectsHeight = 110.0
    let padding = 4.0
    let viewHeight = effectsHeight + padding * 4
    return VStack {
      ScrollView(.horizontal) {
        HStack() {
          ReverbView(store: store.scope(state: \.reverb, action: \.reverb))
          dividerBorderColor
            .frame(width: padding)
          DelayView(store: store.scope(state: \.delay, action: \.delay))
        }
        .frame(height: effectsHeight)
        .background(Color.black)
        .padding(EdgeInsets.init(top: padding, leading: 0, bottom: padding, trailing: 0))
        .background(dividerBorderColor)
        .padding(EdgeInsets.init(top: 0, leading: padding, bottom: 0, trailing: padding))
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
      .frame(height: keyboardHeight * (verticalSizeClass == .compact ? 0.5 : 1.0))
  }
}

extension RootAppView {

  static var preview: some View {
    let _ = prepareDependencies {
      $0.defaultDatabase = try! appDatabase()
    }
    return RootAppView(store: Store(initialState: .init()) { RootApp() })
  }
}

#Preview {
  RootAppView.preview
}
