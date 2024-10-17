import ComposableArchitecture
import Models
import SwiftUI
import Tagged

@Reducer
public struct TagNameEditor {

  @ObservableState
  public struct State: Equatable, Identifiable {
    public var id: TagModel.Key { key }
    let key: TagModel.Key
    let ordering: Int
    let editable: Bool
    var readOnly: Bool { !editable }
    var name: String

    public init(tag: TagModel) {
      self.key = tag.key
      self.ordering = tag.ordering
      self.editable = tag.isUserDefined
      self.name = tag.name
    }
  }

  public enum Action: Equatable, Sendable {
    case nameChanged(String)
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .nameChanged(let name):
        state.name = name
        return .none
      }
    }._printChanges()
  }
}

struct TagNameEditorView: View {
  @Bindable private var store: StoreOf<TagNameEditor>
  @FocusState var isFocused: Bool

  public init(store: StoreOf<TagNameEditor>) {
    self.store = store
    self.isFocused = false
  }

  public var body: some View {
    TextField("", text: $store.name.sending(\.nameChanged))
      .focusable(store.editable)
      .focused($isFocused)
      .disabled(store.readOnly)
      .deleteDisabled(store.readOnly)
      .textFieldStyle(.roundedBorder)
      .font(.headline)
      .foregroundStyle(.blue)
  }
}
