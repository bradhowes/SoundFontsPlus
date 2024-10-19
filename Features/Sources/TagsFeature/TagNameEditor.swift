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
    var name: String
    var takeFocus: Bool

    public init(tag: TagModel, takeFocus: Bool) {
      self.key = tag.key
      self.name = tag.name
      self.takeFocus = takeFocus
      print("key: \(key) takeFocus: \(takeFocus)")
    }
  }

  public enum Action: Equatable, Sendable {
    case clearTakeFocus
    case nameChanged(String)
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .clearTakeFocus:
        state.takeFocus = false
        return .none

      case .nameChanged(let name):
        state.name = name
        return .none
      }
    }
  }
}

struct TagNameEditorView: View {
  @Bindable private var store: StoreOf<TagNameEditor>
  let canSwipe: Bool
  let deleteAction: ((TagModel.Key) -> Void)?

  @FocusState var hasFocus: Bool
  @State var confirmingDeletion: Bool = false

  public init(store: StoreOf<TagNameEditor>, canSwipe: Bool, deleteAction: ((TagModel.Key) -> Void)?) {
    self.store = store
    self.canSwipe = canSwipe
    self.deleteAction = deleteAction
  }

  public var body: some View {
    TextField("", text: $store.name.sending(\.nameChanged))
      .focused($hasFocus)
      .textFieldStyle(.roundedBorder)
      .disabled(deleteAction == nil)
      .deleteDisabled(deleteAction == nil)
      .font(.headline)
      .foregroundStyle(.blue)
      .swipeActions {
        if canSwipe && deleteAction != nil {
          Button {
            confirmingDeletion = true
          } label: {
            Label("Delete", systemImage: "trash")
              .tint(.red)
          }
        }
      }
      .confirmationDialog(
        "Are you sure you want to delete tag \(store.state.name)?",
        isPresented: $confirmingDeletion,
        titleVisibility: .visible
      ) {
        Button("Confirm", role: .destructive) {
          precondition(!TagModel.Ubiquitous.contains(key: store.state.key))
          deleteAction?(store.state.key)
        }
        Button("Cancel", role: .cancel) {
          confirmingDeletion = false
        }
      }
      .task {
        if store.takeFocus {
          store.send(.clearTakeFocus)
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.hasFocus = true
          }
        }
      }
  }
//
//  func withConfirmationDialog(state: ConfirmationDialogState, content: () -> View) -> some View {
//    content()
//      .confirmationDialog(
//        state.title,
//        isPresented: $confirmationDeletion,
//        titleVisibility: true
//      )
//
//  }
}
