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
  public struct State {
    public var soundFontsList: SoundFontsList.State
    public var presetsList: PresetsList.State
    public var tagsList: TagsList.State
    public var toolBar: ToolBar.State
    public var effectsVisible: Bool
    public var tagsListVisible: Bool

    public init(
      soundFontsList: SoundFontsList.State,
      presetsList: PresetsList.State,
      tagsList: TagsList.State,
      toolBar: ToolBar.State
    ) {
      self.soundFontsList = soundFontsList
      self.presetsList = presetsList
      self.tagsList = tagsList
      self.toolBar = toolBar

      @Shared(.effectsVisible) var effectsVisible
      @Shared(.tagsListVisible) var tagsListVisible

      self.effectsVisible = effectsVisible
      self.tagsListVisible = tagsListVisible
    }
  }

  public enum Action {
    case effectsVisibilityChanged(Bool)
    case presetsList(PresetsList.Action)
    case soundFontsList(SoundFontsList.Action)
    case tagsList(TagsList.Action)
    case tagsListVisibilityChanged(Bool)
    case task
    case toolBar(ToolBar.Action)
  }

  public var body: some ReducerOf<Self> {
    Scope(state: \.soundFontsList, action: \.soundFontsList) { SoundFontsList() }
    Scope(state: \.presetsList, action: \.presetsList) { PresetsList() }
    Scope(state: \.tagsList, action: \.tagsList) { TagsList() }
    Scope(state: \.toolBar, action: \.toolBar) { ToolBar() }

    Reduce { state, action in
      switch action {
      case .effectsVisibilityChanged(let value):
        withAnimation(.easeInOut(duration: 0.3)) {
          state.effectsVisible = value
        }
        return .none

      case .tagsListVisibilityChanged(let value):
        state.tagsListVisible = value
        return .none

      case .soundFontsList: return .none
      case .presetsList: return .none
      case .tagsList: return .none
      case .task: return task(&state)
      case .toolBar: return .none
      }
    }
  }

  private let taskCancelId = "taskCancelId"

  public init() {}
}

private extension RootApp {

  func task(_ state: inout State) -> Effect<Action> {
    @Shared(.effectsVisible) var effectsVisible
    @Shared(.tagsListVisible) var tagsListVisible
    return .merge(
      .publisher {
        $effectsVisible.publisher.map(Action.effectsVisibilityChanged)
      },
      .publisher {
        $tagsListVisible.publisher.map(Action.tagsListVisibilityChanged)
      }
    ).cancellable(id: taskCancelId)
  }
}

public struct RootAppView: View {
  private var store: StoreOf<RootApp>
  private let tagsListDividerConstraints: SplitViewDividerConstraints = .init(
    minPrimaryFraction: 0.3,
    minSecondaryFraction: 0.3,
    dragToHideSecondary: true
  )

  @StateObject private var tagsListSideVisible: SplitViewSideVisibleContainer
  @StateObject private var tagsListPosition = SplitViewPositionContainer(0.5)
  @StateObject private var presetsListPosition = SplitViewPositionContainer(0.5)

  public init(store: StoreOf<RootApp>) {
    self.store = store
    self._tagsListSideVisible = .init(wrappedValue: .init(.primary, setter: { value in
      @Shared(.tagsListVisible) var tagsListVisible
      $tagsListVisible.withLock { $0 = value == .both }
    }))
  }

  public var body: some View {
    let _ = Self._printChanges()
    VStack(spacing: 0) {
      listViews
      effectsView
      toolbarAndKeyboard
    }
    .onAppear { store.send(.task) }
    .onChange(of: store.tagsListVisible) { oldValue, newValue in
      withAnimation {
        tagsListSideVisible.setValue(newValue ? .both : .primary)
      }
    }
  }

  private var listViews: some View {
    SplitView(orientation: .horizontal, position: presetsListPosition) {
      fontsAndTags
    } divider: {
      HandleDivider(orientation: .horizontal, dividerConstraints: .init())
    } secondary: {
      PresetsListView(store: store.scope(state: \.presetsList, action: \.presetsList))
    }
  }

  private var fontsAndTags: some View {
    SplitView(
      orientation: .vertical,
      position: tagsListPosition,
      sideVisible: tagsListSideVisible,
      dividerConstraints: tagsListDividerConstraints
    ) {
      SoundFontsListView(store: store.scope(state: \.soundFontsList, action: \.soundFontsList))
    } divider: {
      HandleDivider(orientation: .vertical, dividerConstraints: .init())
    } secondary: {
      TagsListView(store: store.scope(state: \.tagsList, action: \.tagsList))
    }
  }

  private var toolbarAndKeyboard: some View {
    VStack {
      ToolBarView(store: store.scope(state: \.toolBar, action: \.toolBar))
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
    .frame(width: nil, height: store.effectsVisible ? 140.0 : 8.0)
    .offset(x: 0.0, y: store.effectsVisible ? 0.0 : 140.0)
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
      toolBar: ToolBar.State()
    )) { RootApp() })
  }
}

#Preview {
  RootAppView.preview
}
