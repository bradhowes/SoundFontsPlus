import BRHSplitView
import ComposableArchitecture
import DelayFeature
import Extensions
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
    public var effectsVisible: Bool = false

    public init(
      soundFontsList: SoundFontsList.State,
      presetsList: PresetsList.State,
      tagsList: TagsList.State,
      toolBar: ToolBar.State,
      tagsSplit: SplitViewReducer.State,
      presetsSplit: SplitViewReducer.State,
      delay: DelayFeature.State,
      reverb: ReverbFeature.State
    ) {
      self.soundFontsList = soundFontsList
      self.presetsList = presetsList
      self.tagsList = tagsList
      self.toolBar = toolBar
      self.tagsSplit = tagsSplit
      self.presetsSplit = presetsSplit
      self.delay = delay
      self.reverb = reverb
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

    Reduce { state, action in
      switch action {
      case .tagsSplit(.delegate(.panesVisibilityChanged(let panes))):
        state.toolBar.tagsListVisible = panes.contains(.bottom)
        return .none

      case .toolBar(.effectsVisibilityButtonTapped):
        state.effectsVisible = state.toolBar.effectsVisible
        return .none

      case .toolBar(.tagVisibilityButtonTapped):
        let panes: SplitViewPanes = state.toolBar.tagsListVisible ? .both : .primary
        return reduce(into: &state, action: .tagsSplit(.updatePanesVisibility(panes)))

      default:
        return .none
      }
    }
  }

  public init() {}
}

public struct RootAppView: View {
  private let store: StoreOf<RootApp>
  @Environment(\.appPanelBackground) private var appPanelBackground

  public init(store: StoreOf<RootApp>) {
    self.store = store
  }

  public var body: some View {
    // let _ = Self._printChanges()
    VStack(spacing: 0) {
      listViews
      effectsView
      toolbarAndKeyboard
    }
    .animation(.smooth, value: store.effectsVisible)
  }

  private var listViews: some View {
    SplitView(
      store: store.scope(state: \.presetsSplit, action: \.presetsSplit),
      primary: {
        fontsAndTags
      },
      divider: {
        HandleDivider(
          dividerColor: appPanelBackground,
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
          dividerColor: appPanelBackground,
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

  private var toolbarAndKeyboard: some View {
    VStack {
      ToolBarView(
        store: store.scope(state: \.toolBar, action: \.toolBar)
      )
      keyboardView
    }
  }

  private var keyboardView: some View {
    appPanelBackground
      .frame(height: 280)
  }

  private var effectsView: some View {
    VStack {
      ScrollView(.horizontal) {
        HStack {
          DelayView(store: store.scope(state: \.delay, action: \.delay))
          ReverbView(store: store.scope(state: \.reverb, action: \.reverb))
        }
      }
      .padding(0)
      .background(appPanelBackground)
    }
    .padding([.top, .bottom], 8)
    .frame(width: nil, height: store.effectsVisible ? 200.0 : 8.0)
    .offset(x: 0.0, y: store.effectsVisible ? 0.0 : 200.0)
    .clipped()
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
      reverb: ReverbFeature.State()
    )) { RootApp() })
  }
}

#Preview {
  RootAppView.preview
}
