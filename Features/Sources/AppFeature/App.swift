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
    public var effectsVisibility: Bool = false

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
    case effectsVisibilityChanged(Bool)
    case tagsListVisibilityChanged(Bool)
  }

  public var body: some ReducerOf<Self> {
    Scope(state: \.soundFontsList, action: \.soundFontsList) { SoundFontsList() }
    Scope(state: \.presetsList, action: \.presetsList) { PresetsList() }
    Scope(state: \.tagsList, action: \.tagsList) { TagsList() }
    Scope(state: \.toolBar, action: \.toolBar) { ToolBar() }
    Reduce { state, action in
      switch action {
      case .effectsVisibilityChanged(let value):
        withAnimation(.easeInOut(duration: 0.25)) {
          state.effectsVisibility = value
        }
        return .none

      case .soundFontsList: return .none
      case .presetsList: return .none
      case .tagsList: return .none
      case .tagsListVisibilityChanged(let value):
        withAnimation(.easeInOut(duration: 0.25)) {
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
    return .merge(
      .run { send in
        @Shared(.effectsVisible) var effectsVisible
        for await value in $effectsVisible.publisher.values {
          await send(.effectsVisibilityChanged(value))
        }
      },
      .run { send in
        @Shared(.tagsListVisible) var tagsListVisible
        for await value in $tagsListVisible.publisher.values {
          await send(.tagsListVisibilityChanged(value))
        }
      }
    ).cancellable(id: taskCancelId)
  }
}

public struct AppView: View {
  private var store: StoreOf<App>

  public init(store: StoreOf<App>) {
    self.store = store
  }

  public var body: some View {
    let style = SplitStyling(color: .accentColor.opacity(0.5), hideSplitter: true)

    VStack(spacing: 0) {
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
      // Effects view
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
      .frame(width: .infinity, height: store.effectsVisibility ? 140.0 : 8.0)
      .offset(x: 0.0, y: store.effectsVisibility ? 0.0 : 140.0)
      .clipped()
      VStack {
        // .offset(x: 0.0, y: effectsVisible ? 0.0 : 140.0)
        // Toolbar
        ToolBarView(store: store.scope(state: \.toolBar, action: \.toolBar))
        // Space for keyboard
        Color(red: 0.08, green: 0.08, blue: 0.08)
          .frame(height: 280)
      }
    }
    .onAppear { store.send(.task) }
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
