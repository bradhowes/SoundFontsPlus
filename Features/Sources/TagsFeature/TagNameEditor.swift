//import ComposableArchitecture
//import Models
//import SwiftUI
//import Tagged
//
//@Reducer
//public struct TagNameEditor {
//
//  @ObservableState
//  public struct State: Equatable, Identifiable {
//    public var id: Tag.ID { tag.id }
//    var tag: Tag
//    var takeFocus: Bool
//
//    public init(tag: Tag, takeFocus: Bool) {
//      self.tag = tag
//      self.takeFocus = takeFocus
//    }
//  }
//
//  public enum Action {
//    case clearTakeFocus
//    case nameChanged(String)
//  }
//
//  public var body: some ReducerOf<Self> {
//    Reduce { state, action in
//      switch action {
//      case .clearTakeFocus:
//        state.takeFocus = false
//        return .none
//
//      case .nameChanged(let name):
//        state.tag.name = name
//        return .none
//      }
//    }
//  }
//}
//
//struct TagNameEditorView: View {
//  @Bindable private var store: StoreOf<TagNameEditor>
//  let canSwipe: Bool
//  let deleteAction: ((Tag.ID) -> Void)?
//
//  @FocusState var hasFocus: Bool
//  @State var confirmingTagDeletion: Bool = false
//
//  public init(store: StoreOf<TagNameEditor>, canSwipe: Bool, deleteAction: ((Tag.ID) -> Void)?) {
//    self.store = store
//    self.canSwipe = canSwipe
//    self.deleteAction = deleteAction
//  }
//
//  public var body: some View {
//    TextField("", text: $store.name.sending(\.nameChanged))
//      .focused($hasFocus)
//      .textFieldStyle(.roundedBorder)
//      .disabled(deleteAction == nil)
//      .deleteDisabled(deleteAction == nil)
//      .font(.headline)
//      .foregroundStyle(.blue)
//      .swipeActions(edge: .trailing) {
//        if canSwipe && deleteAction != nil {
//          Button {
//            confirmingTagDeletion = true
//          } label: {
//            Image(systemName: "trash")
//              .tint(.red)
//          }
//        }
//      }
//      .confirmationDialog(
//        "Are you sure you want to delete \(store.tag.name)?",
//        isPresented: $confirmingTagDeletion,
//        titleVisibility: .visible
//      ) {
//        Button("Confirm", role: .destructive) {
//          deleteAction?(store.tag.id)
//        }
//        Button("Cancel", role: .cancel) {
//          confirmingTagDeletion = false
//        }
//      }
//      .task {
//        if store.takeFocus {
//          store.send(.clearTakeFocus)
//          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//            self.hasFocus = true
//          }
//        }
//      }
//  }
//}
