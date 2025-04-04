import ComposableArchitecture
import Models
import PresetsFeature
import SoundFontsFeature
import SplitView
import SwiftUI
import TagsFeature
import ToolBarFeature

@Reducer
public struct App {

  @ObservableState
  public struct State: Equatable {
    public var soundFontsList: SoundFontsList.State
    public var presetsList: PresetsList.State
    public var tagsList: TagsList.State
    public var toolBar: ToolBar.State
    public var tagsVisible: Bool = false

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
    }
  }

  public enum Action {
    case soundFontsList(SoundFontsList.Action)
    case presetsList(PresetsList.Action)
    case tagsList(TagsList.Action)
    case toolBar(ToolBar.Action)
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
      case .toolBar: return .none
      }
    }
  }
}

public struct AppView: View {
  let store: StoreOf<App>

  public init(store: StoreOf<App>) {
    self.store = store
  }

  public var body: some View {
    let style = SplitStyling(color: .accentColor.opacity(0.5))

    VStack {
      HSplit(left: {
        VSplit(top: {
          SoundFontsListView(store: store.scope(state: \.soundFontsList, action: \.soundFontsList))
        }, bottom: {
          TagsListView(store: store.scope(state: \.tagsList, action: \.tagsList))
        })
        .fraction(0.6)
        .splitter { CustomSplitter(layout: LayoutHolder(.vertical),
                                   hide: SideHolder(.secondary), styling: style) }
      }, right: {
        PresetsListView(store: store.scope(state: \.presetsList, action: \.presetsList))
      })
      .fraction(0.5)
      .splitter { CustomSplitter(layout: LayoutHolder(.horizontal),
                                 hide: SideHolder(.secondary), styling: style) }
      .constraints(minPFraction: 0.3, minSFraction: 0.3)
    }
    // Toolbar
    ToolBarView(store: store.scope(state: \.toolBar, action: \.toolBar))
    // Space for keyboard
    Color.secondary.opacity(0.2)
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
  @ObservedObject var hide: SideHolder
  @ObservedObject var styling: SplitStyling

  var body: some View {
    ZStack {
      switch layout.value {
      case .horizontal:

        Color.clear
          .frame(width: styling.invisibleThickness)
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

        Color.clear
          .frame(height: styling.invisibleThickness)
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
    .onTapGesture(count: 2) {
      print("double-tap")
      hide.hide(.secondary)
    }
  }}

#Preview {
  AppView.preview
}
