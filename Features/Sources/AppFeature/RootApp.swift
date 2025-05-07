import AUv3Controls
import BRHSplitView
import ComposableArchitecture
import DelayFeature
import Extensions
import KeyboardFeature
import Models
import PresetsFeature
import ReverbFeature
import Sharing
import SoundFontsFeature
import SwiftUI
import TagsFeature
import ToolBarFeature

@Reducer
public struct RootApp {

  @ObservableState
  public struct State: Equatable {
    public var soundFontsList: SoundFontsList.State
    public var presetsList: PresetsList.State
    public var tagsList: TagsList.State
    public var toolBar: ToolBar.State
    public var tagsSplit: SplitViewReducer.State
    public var presetsSplit: SplitViewReducer.State
    public var delay: DelayFeature.State
    public var reverb: ReverbFeature.State
    public var keyboard: KeyboardFeature.State

    public init(
      soundFontsList: SoundFontsList.State,
      presetsList: PresetsList.State,
      tagsList: TagsList.State,
      toolBar: ToolBar.State,
      tagsSplit: SplitViewReducer.State,
      presetsSplit: SplitViewReducer.State,
      delay: DelayFeature.State,
      reverb: ReverbFeature.State,
      keyboard: KeyboardFeature.State
    ) {
      self.soundFontsList = soundFontsList
      self.presetsList = presetsList
      self.tagsList = tagsList
      self.toolBar = toolBar
      self.tagsSplit = tagsSplit
      self.presetsSplit = presetsSplit
      self.delay = delay
      self.reverb = reverb
      self.keyboard = keyboard
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
      case .tagsSplit(.delegate(.panesVisibilityChanged(let panes))):
        state.toolBar.tagsListVisible = panes.contains(.bottom)
        return .none

      case .toolBar(.tagVisibilityButtonTapped):
        let panes: SplitViewPanes = state.toolBar.tagsListVisible ? .both : .primary
        return reduce(into: &state, action: .tagsSplit(.updatePanesVisibility(panes)))

      case .toolBar(.delegate(.editingPresetVisibility)):
        return reduce(into: &state, action: .presetsList(.visibilityEditMode(state.toolBar.editingPresetVisibility)))

      default:
        return .none
      }
    }
    // ._printChanges()
  }

  public init() {}
}

public struct RootAppView: View {
  private let store: StoreOf<RootApp>
  private let theme: Theme
  private let appPanelBackground = Color.black
  private let dividerBorderColor: Color = Color.gray.opacity(0.15)

  @Environment(\.keyboardKeyHeight) var keyboardKeyHeight

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
    .animation(.smooth, value: store.toolBar.effectsVisible)
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
    .frame(height: store.toolBar.effectsVisible ? viewHeight : padding)
    .offset(x: 0.0, y: store.toolBar.effectsVisible ? 0.0 : viewHeight / 2 - padding - 1)
    .clipped()
  }

  private var toolbarAndKeyboard: some View {
    VStack {
      ToolBarView(store: store.scope(state: \.toolBar, action: \.toolBar))
      keyboardView
    }
  }

  private var keyboardView: some View {
    ScrollView(.horizontal) {
      KeyboardView(store: store.scope(state: \.keyboard, action: \.keyboard))
    }
    .frame(height: keyboardKeyHeight)
  }
}

extension RootAppView {

  static var preview: some View {
    let _ = prepareDependencies {
      $0.defaultDatabase = try!.appDatabase()
    }
    return RootAppView(store: Store(initialState: .init(
      soundFontsList: SoundFontsList.State(),
      presetsList: PresetsList.State(),
      tagsList: TagsList.State(),
      toolBar: ToolBar.State(),
      tagsSplit: SplitViewReducer.State(
        panesVisible: .primary,
        initialPosition: 0.5
      ),
      presetsSplit: SplitViewReducer.State(
        panesVisible: .both,
        initialPosition: 0.5
      ),
      delay: DelayFeature.State(),
      reverb: ReverbFeature.State(),
      keyboard: KeyboardFeature.State()
    )) { RootApp() })
  }
}

#Preview {
  RootAppView.preview
}
