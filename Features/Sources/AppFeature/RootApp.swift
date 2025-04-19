import ComposableArchitecture
import Models
import PresetsFeature
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

    public init(
      soundFontsList: SoundFontsList.State,
      presetsList: PresetsList.State,
      tagsList: TagsList.State,
      toolBar: ToolBar.State,
      tagsSplit: SplitViewReducer.State,
      presetsSplit: SplitViewReducer.State
    ) {
      self.soundFontsList = soundFontsList
      self.presetsList = presetsList
      self.tagsList = tagsList
      self.toolBar = toolBar
      self.tagsSplit = tagsSplit
      self.presetsSplit = presetsSplit
    }
  }

  public enum Action {
    case effectsVisibilityChanged(Bool)
    case presetsList(PresetsList.Action)
    case soundFontsList(SoundFontsList.Action)
    case tagsList(TagsList.Action)
    // case task
    case toolBar(ToolBar.Action)
    case tagsSplit(SplitViewReducer.Action)
    case presetsSplit(SplitViewReducer.Action)
  }

  public var body: some ReducerOf<Self> {
    Scope(state: \.soundFontsList, action: \.soundFontsList) { SoundFontsList() }
    Scope(state: \.presetsList, action: \.presetsList) { PresetsList() }
    Scope(state: \.tagsList, action: \.tagsList) { TagsList() }
    Scope(state: \.toolBar, action: \.toolBar) { ToolBar() }
    Scope(state: \.tagsSplit, action: \.tagsSplit) { SplitViewReducer() }
    Scope(state: \.presetsSplit, action: \.presetsSplit) { SplitViewReducer() }

    Reduce { state, action in
      switch action {
      case .effectsVisibilityChanged(let value):
//        withAnimation(.easeInOut(duration: 0.3)) {
//          state.effectsVisible = value
//        }
        return .none

      case .soundFontsList: return .none
      case .presetsList: return .none
      case .tagsList: return .none
      // case .task: return task(&state)
      case .toolBar(.tagVisibilityButtonTapped):
        let panes: SplitViewPanes = state.toolBar.tagsListVisible ? .both : .primary
        return reduce(into: &state, action: .tagsSplit(.panesVisibilityChanged(panes)))
      case .toolBar: return .none

      case .tagsSplit(.panesVisibilityChanged):
        print("tagsSplit(.panesVisibilityChanged)")
        return .none

      case .tagsSplit:
        print("tagsSplit")
        return .none

      case .presetsSplit:
        print("presetsSplit")
        return .none
      }
    }
  }

  private let taskCancelId = "taskCancelId"

  public init() {}
}

private extension RootApp {

  func task(_ state: inout State) -> Effect<Action> {
    @Shared(.effectsVisible) var effectsVisible
    return .publisher {
      $effectsVisible.publisher.map(Action.effectsVisibilityChanged)
    }
  }
}

public struct RootAppView: View {
  private var store: StoreOf<RootApp>

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
    // .onAppear { store.send(.task) }
  }

  private var listViews: some View {
    SplitView(
      store: store.scope(state: \.presetsSplit, action: \.presetsSplit),
      primary: {
        fontsAndTags
      },
      divider: {
        HandleDivider(for: .horizontal, dividerConstraints: .init())
      },
      secondary: {
        PresetsListView(store: store.scope(state: \.presetsList, action: \.presetsList))
      }
    )
  }

  private var fontsAndTags: some View {
    SplitView(
      store: store.scope(state: \.tagsSplit, action: \.tagsSplit),
      primary: {
        SoundFontsListView(store: store.scope(state: \.soundFontsList, action: \.soundFontsList))
      },
      divider: {
        HandleDivider(for: .vertical, dividerConstraints: .init())
      },
      secondary: {
        TagsListView(store: store.scope(state: \.tagsList, action: \.tagsList))
      }
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
    Color(red: 0.08, green: 0.08, blue: 0.08)
      .frame(height: 280)
  }

  private var effectsView: some View {
    VStack {
      ScrollView(.horizontal) {
        HStack {
          VStack {
            Text("Hello")
            Text("World")
          }
          Circle()
            .fill(Color.blue)
            .frame(width: 120, height: 120)
          Circle()
            .fill(Color.green)
            .frame(width: 120, height: 120)
          Circle()
            .fill(Color.yellow)
            .frame(width: 120, height: 120)
        }
      }
      .padding(0)
      .background(Color(red: 0.08, green: 0.08, blue: 0.08))
    }
    .padding([.top, .bottom], 8)
    .frame(width: nil, height: 8.0) // store.effectsVisible and false ? 140.0 : 8.0)
    .offset(x: 0.0, y: 140.0) // store.effectsVisible ? 0.0 : 140.0)
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
        orientation: .vertical,
        constraints: .init(
          minPrimaryFraction: 0.3,
          minSecondaryFraction: 0.3,
          dragToHide: .bottom
        ),
        panesVisible: .primary,
        position: 0.5
      ),
      presetsSplit: SplitViewReducer.State(
        orientation: .horizontal,
        constraints: .init(
          minPrimaryFraction: 0.3,
          minSecondaryFraction: 0.3,
          dragToHide: .none
        ),
        panesVisible: .both,
        position: 0.5
      )
    )) { RootApp() })
  }
}

#Preview {
  RootAppView.preview
}
