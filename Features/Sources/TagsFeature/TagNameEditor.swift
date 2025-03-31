import ComposableArchitecture
import Models
import SwiftUI
import Tagged

@Reducer
public struct TagNameEditor {

  @ObservableState
  public struct State: Equatable, Identifiable {
    public var id: Tag.ID { tag.id }
    let tag: Tag
    var name: String
    var membership: Bool?

    public init(tag: Tag, membership: Bool? = nil) {
      self.tag = tag
      self.name = tag.name
      self.membership = membership
    }
  }

  public enum Action: Equatable {
    case delegate(Delegate)
    case deleteTag
    case nameChanged(String)
    case memberChanged(Bool)
  }

  @CasePathable
  public enum Delegate: Equatable {
    case deleteTag(Tag)
  }

  @Dependency(\.defaultDatabase) var database

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .delegate: return .none

      case .deleteTag:
        let tag = state.tag
        return .run { send in
          await send(.delegate(.deleteTag(tag)), animation: .default)
        }

      case .memberChanged(let value): return memberChanged(&state, value: value)
      case .nameChanged(let newName): return nameChanged(&state, value: newName)
      }
    }
  }
}

private extension TagNameEditor {

  func memberChanged(_ state: inout State, value: Bool) -> Effect<Action> {
    precondition(state.membership != nil)
    state.membership = value
    return .none
  }

  func nameChanged(_ state: inout State, value: String) -> Effect<Action> {
    state.name = value
    return .none
  }
}

public struct TagNameEditorView: View {
  @Bindable var store: StoreOf<TagNameEditor>
  @Environment(\.editMode) var editMode

  var readOnly: Bool { store.tag.isUbiquitous }
  var editable: Bool { !readOnly }

  public var body: some View {
    if store.membership == nil {
      nameField
    } else {
      memberNameField
    }
  }

  private var nameField: some View {
    TextField("", text: $store.name.sending(\.nameChanged))
      .disabled(readOnly)
      .deleteDisabled(readOnly)
      .foregroundStyle(editable ? .blue : .secondary)
      .font(Font.custom("Eurostile", size: 20))
      .swipeActions(edge: .trailing) {
        if editable {
          Button {
            store.send(.deleteTag)
          } label: {
            Image(systemName: "trash")
              .tint(.red)
          }
        }
      }
  }

  private var memberNameField: some View {
    HStack {
      Toggle("", isOn: Binding(get: { store.membership ?? false }, set: { store.send(.memberChanged($0)) }))
        .disabled(store.tag.isUbiquitous)
        .checkedStyle()
      nameField
    }
  }
}

extension TagNameEditorView {

  static var preview: some View {
    let _ = prepareDependencies { $0.defaultDatabase = try! .appDatabase() }
    @Dependency(\.defaultDatabase) var db

    let tags = try! db.write {
      _ = try Tag.make($0, name: "New Tag")
      return try Tag.all().fetchAll($0)
    }

    return Form {
      TagNameEditorView(store: Store(initialState: .init(tag: tags[0])) { TagNameEditor() })
      TagNameEditorView(store: Store(initialState: .init(tag: tags.last!, membership: false)) { TagNameEditor() })
    }
  }
}

#Preview {
  TagNameEditorView.preview
}
