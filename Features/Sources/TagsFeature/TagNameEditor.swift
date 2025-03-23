import ComposableArchitecture
import Models
import SwiftUI
import Tagged

@Reducer
public struct TagNameEditor {

  @ObservableState
  public struct State: Equatable, Identifiable {
    public var id: Tag.ID { tag.id }
    var tag: Tag
    var name: String
    var takeFocus: Bool

    public init(tag: Tag, takeFocus: Bool) {
      self.tag = tag
      self.name = tag.name
      self.takeFocus = takeFocus
    }
  }

  public enum Action: Equatable {
    case clearTakeFocus
    case delegate(Delegate)
    case deleteTag
    case nameChanged(String)
  }

  @CasePathable
  public enum Delegate: Equatable {
    case deleteTag(Tag)
  }

  @Dependency(\.defaultDatabase) var database

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .clearTakeFocus: return clearTakeFocus(&state)
      case .delegate: return .none

      case .deleteTag:
        let tag = state.tag
        return .run { send in
          await send(.delegate(.deleteTag(tag)), animation: .default)
        }

      case .nameChanged(let newName): return nameChanged(&state, value: newName)
      }
    }
  }
}

private extension TagNameEditor {

  func clearTakeFocus(_ state: inout State) -> Effect<Action> {
    state.takeFocus = false
    return .none
  }

  func nameChanged(_ state: inout State, value: String) -> Effect<Action> {
    state.name = value
    return .none
  }
}

public struct TagNameEditorView: View {
  @Bindable var store: StoreOf<TagNameEditor>
  @FocusState var hasFocus: Bool
  @Environment(\.editMode) var editMode

  var readOnly: Bool { store.tag.isUbiquitous }
  var editable: Bool { !readOnly }

  public var body: some View {
    TextField("", text: $store.name.sending(\.nameChanged))
      .focused($hasFocus)
      .disabled(readOnly)
      .deleteDisabled(readOnly)
      .foregroundStyle(editable ? .blue : .secondary)
      .font(Font.custom("Eurostile", size: 20))
      .onAppear {
        if store.takeFocus {
          hasFocus = true
          store.send(.clearTakeFocus)
        }
      }
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
}

#Preview {
  TagsListView.preview
}
