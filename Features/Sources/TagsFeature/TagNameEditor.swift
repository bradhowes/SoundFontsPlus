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
    var hasFocus: Bool

    public init(tag: TagModel) {
      self.key = tag.key
      self.ordering = tag.ordering
      self.editable = tag.isUserDefined
      self.name = tag.name
      self.hasFocus = false
    }
  }

  public enum Action: BindableAction, Equatable, Sendable {
    case binding(BindingAction<State>)
  }

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding(\.name):
        print("name change")
        return .none

      case .binding:
        return .none
      }
    }
  }
}

struct TagNameEditorView: View {
  @Bindable private var store: StoreOf<TagNameEditor>
  @FocusState var focusedField: TagModel.Key?

  public init(store: StoreOf<TagNameEditor>) {
    self.store = store
    self.focusedField = store.key
  }

  public var body: some View {
    TextField("", text: $store.name)
      .focusable(store.editable)
      .focused($focusedField, equals: store.key)
      .disabled(store.readOnly)
      .deleteDisabled(store.readOnly)
      .textFieldStyle(.roundedBorder)
  }
}
