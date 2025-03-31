import ComposableArchitecture
import Models
import SwiftUI
import SwiftUINavigation
import TagsFeature
import Tagged

@Reducer
public struct SoundFontTagsMemberList {

  @ObservableState
  public struct State: Equatable {
    var path = StackState<TagsEditor.State>()
    var rows: IdentifiedArrayOf<SoundFontTagsMemberItem.State>

    public init(tagging: [Tag: Bool]) {
      self.rows = .init(uniqueElements: tagging.map { .init(tag: $0, tagState: $1) }
        .sorted(by: { $0.tag.ordering < $1.tag.ordering })
      )
    }
  }

  public enum Action: Equatable {
    case delegate(Delegate)
    case dismissButtonTapped
    case editTagsButtonTapped
    case rows(IdentifiedActionOf<SoundFontTagsMemberItem>)
  }

  @CasePathable
  public enum Delegate: Equatable {
    case addTag(Tag)
    case removeTag(Tag)
    case editTags
  }

  @Dependency(\.dismiss) var dismiss

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {

      case .delegate:
        return .none

      case .dismissButtonTapped:
        let dismiss = dismiss
        return .run { send in
          await dismiss()
        }

      case .editTagsButtonTapped: return .send(.delegate(.editTags))

      case let .rows(.element(id: key, action: .tagStateChanged(value))):
        if let index = state.rows.index(id: key) {
          let tag = state.rows[index].tag
          if value {
            return .send(.delegate(.addTag(tag)))
          } else {
            return .send(.delegate(.removeTag(tag)))
          }
        }
        return .none

      case .rows:
        return .none
      }
    }
    .forEach(\.rows, action: \.rows) {
      SoundFontTagsMemberItem()
    }
  }
}

private extension SoundFontTagsMemberList {

  func editTags(_ state: inout State) -> Effect<Action> {
//    state.path.append(.init(tags: state.rows.map(\.tag), focused: nil))
    return .none
  }
}

public struct SoundFontTagsMemberListView: View {
  private var store: StoreOf<SoundFontTagsMemberList>

  public init(store: StoreOf<SoundFontTagsMemberList>) {
    self.store = store
  }

  public var body: some View {
    List {
      ForEach(store.scope(state: \.rows, action: \.rows)) { rowStore in
        SoundFontTagsMemberItemView(store: rowStore)
      }
    }
    .navigationTitle("Memberships")
    .toolbar {
      Button {
        store.send(.editTagsButtonTapped)
      } label: {
        Text("Edit")
      }
    }
  }
}

extension SoundFontTagsMemberListView {
  static var preview: some View {
    let _ = prepareDependencies {
      $0.defaultDatabase = try!.appDatabase()
    }

    @Dependency(\.defaultDatabase) var db
    let soundFonts = try! db.read { try! SoundFont.fetchAll($0) }
    let soundFont = soundFonts[0]

    _ = try! db.write {
      _ = try Tag.make($0, name: "Foo")
      _ = try Tag.make($0, name: "Bar")
    }

    let all = Tag.ordered
    let tags = Set<Tag>(soundFont.tags)
    var tagging = Dictionary<Tag, Bool>()
    for tag in all {
      tagging[tag] = tags.contains(tag)
    }

    return NavigationStack {
      SoundFontTagsMemberListView(store: Store(initialState: .init(tagging: tagging)) { SoundFontTagsMemberList() })
    }
  }
}

#Preview {
  SoundFontTagsMemberListView.preview
}
