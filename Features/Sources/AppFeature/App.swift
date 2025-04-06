import ComposableArchitecture
import Models
import PresetsFeature
import Sharing
import SoundFontsFeature
import SplitView
import SwiftUI
import TagsFeature
import ToolBarFeature

@Reducer
public struct App {

  @ObservableState
  public struct State {
    public var soundFontsList: SoundFontsList.State
    public var presetsList: PresetsList.State
    public var tagsList: TagsList.State
    public var toolBar: ToolBar.State
    @ObservationIgnored let tagsListSideHolder: SideHolder

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
      self.tagsListSideHolder = .usingUserDefaults(key: .tagsListVisible)
    }
  }

  public enum Action {
    case soundFontsList(SoundFontsList.Action)
    case presetsList(PresetsList.Action)
    case tagsList(TagsList.Action)
    case task
    case toolBar(ToolBar.Action)
    case tagsListVisibilityChanged(Bool)
  }

  public var body: some ReducerOf<Self> {
    Scope(state: \.soundFontsList, action: \.soundFontsList) { SoundFontsList() }
    Scope(state: \.presetsList, action: \.presetsList) { PresetsList() }
    Scope(state: \.tagsList, action: \.tagsList) { TagsList() }
    Scope(state: \.toolBar, action: \.toolBar) { ToolBar() }
    Reduce { state, action in
      switch action {
      case .soundFontsList: return .none
      case .presetsList: return .none
      case .tagsList: return .none
      // case .toolBar(.delegate(.setTagVisibility(let value))): return setTagVisibility(&state, value: value)
      case .tagsListVisibilityChanged(let value):
        withAnimation {
          state.tagsListSideHolder.side = value ? .none : .secondary
        }
        return .none
      case .task: return task(&state)
      case .toolBar: return .none
      }
    }
  }

  private let taskCancelId = "taskCancelId"
}

private extension App {

  func task(_ state: inout State) -> Effect<Action> {
    return .run { send in
      @Shared(.tagsListVisible) var tagsListVisible
      for await value in $tagsListVisible.publisher.values {
        await send(.tagsListVisibilityChanged(value))
      }
    }.cancellable(id: taskCancelId)
  }
}

public struct AppView: View {
  private var store: StoreOf<App>
  @Shared(.effectsVisible) var effectsVisible

  public init(store: StoreOf<App>) {
    self.store = store
  }

  public var body: some View {
    let style = SplitStyling(color: .accentColor.opacity(0.5), hideSplitter: true)

    VStack {
      HSplit(left: {
        VSplit(top: {
          SoundFontsListView(store: store.scope(state: \.soundFontsList, action: \.soundFontsList))
        }, bottom: {
          TagsListView(store: store.scope(state: \.tagsList, action: \.tagsList))
        })
        .fraction(FractionHolder.usingUserDefaults(0.4, key: .fontsAndTagsSplitFraction))
        .splitter {
          CustomSplitter(
            layout: .vertical,
            styling: style
          )
        }
        .constraints(minPFraction: 0.4, minSFraction: 0.2)
        .hide(store.tagsListSideHolder)
      }, right: {
        PresetsListView(store: store.scope(state: \.presetsList, action: \.presetsList))
      })
      .fraction(FractionHolder.usingUserDefaults(0.4, key: .fontsAndPresetsSplitFraction))
      .splitter {
        CustomSplitter(
          layout: .horizontal,
          styling: style
        )
      }
      .constraints(minPFraction: 0.2, minSFraction: 0.2)
    }
    .onAppear { store.send(.task) }
    // Toolbar
    if effectsVisible {
      Color(red: 0.08, green: 0.08, blue: 0.08)
        .frame(height: 140)
    }
    ToolBarView(store: store.scope(state: \.toolBar, action: \.toolBar))
    // Space for keyboard
    Color(red: 0.08, green: 0.08, blue: 0.08)
      .frame(height: 280)
  }
}

extension AppView {

  static var preview: some View {
    let _ = prepareDependencies {
      $0.defaultDatabase = try!.appDatabase()
    }

    @Dependency(\.defaultDatabase) var database
    let tags = Tag.ordered
    guard let soundFonts = (try? database.read {
      guard let tag = try Tag.fetchOne($0, id: Tag.Ubiquitous.all.id) else { return Optional<[SoundFont]>.none }
      return try tag.soundFonts.fetchAll($0)
    }) else { fatalError() }

    return AppView(store: Store(initialState: .init(
      soundFontsList: SoundFontsList.State(soundFonts: soundFonts),
      presetsList: PresetsList.State(soundFont: soundFonts[0]),
      tagsList: TagsList.State(tags: tags),
      toolBar: ToolBar.State()
    )) { App() })
  }
}

struct CustomSplitter: SplitDivider {
  @ObservedObject var layout: LayoutHolder
  @ObservedObject var styling: SplitStyling

  init(layout: SplitLayout, styling: SplitStyling) {
    self.layout = .init(layout)
    self.styling = styling
  }

  var body: some View {
    ZStack {
      switch layout.value {
      case .horizontal:

        Rectangle()
          .fill(Color(red: 0.08, green: 0.08, blue: 0.08))
          .frame(width: 10)
          .padding(0)

        RoundedRectangle(cornerRadius: styling.visibleThickness / 2)
          .fill(styling.color)
          .frame(width: styling.visibleThickness, height: 24)
          .padding(EdgeInsets(top: styling.inset, leading: 0, bottom: styling.inset, trailing: 0))

        VStack {
          Color.black
            .frame(width: 2, height: 2)
          Color.black
            .frame(width: 2, height: 2)
        }

      case .vertical:

        Rectangle()
          .fill(Color(red: 0.08, green: 0.08, blue: 0.08))
          .frame(height: 10)
          .padding(0)

        RoundedRectangle(cornerRadius: styling.visibleThickness / 2)
          .fill(styling.color)
          .frame(width: 24, height: styling.visibleThickness)
          .padding(EdgeInsets(top: 0, leading: styling.inset, bottom: 0, trailing: styling.inset))

        HStack {
          Color.black
            .frame(width: 2, height: 2)
          Color.black
            .frame(width: 2, height: 2)
        }
      }
    }
    .contentShape(Rectangle())
//    .onTapGesture(count: 2) {
//      print("double-tap")
//      hide.hide(.secondary)
//    }
  }}

#Preview {
  AppView.preview
}
