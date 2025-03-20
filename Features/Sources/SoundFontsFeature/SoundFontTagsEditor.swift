//import ComposableArchitecture
//import Models
//import SwiftUI
//import SwiftUINavigation
//import Tagged
//
//@Reducer
//public struct SoundFontTagsEditor {
//
//  @ObservableState
//  public struct State: Equatable {
//    var rows: IdentifiedArrayOf<SoundFontTagsEditorItem.State>
//
//    public init(tagging: [TagModel: Bool]) {
//      self.rows = .init(uniqueElements: tagging.map { .init(tag: $0, tagState: $1) }
//        .sorted(by: { $0.tag.ordering < $1.tag.ordering })
//      )
//    }
//  }
//
//  public enum Action {
//    case delegate(Delegate)
//    case dismissButtonTapped
//    case rows(IdentifiedActionOf<SoundFontTagsEditorItem>)
//  }
//
//  @CasePathable
//  public enum Delegate {
//    case addTag(TagModel)
//    case removeTag(TagModel)
//  }
//
//  @Dependency(\.dismiss) var dismiss
//
//  public var body: some ReducerOf<Self> {
//    Reduce { state, action in
//      switch action {
//
//      case .delegate:
//        return .none
//
//      case .dismissButtonTapped:
//        let dismiss = dismiss
//        return .run { send in
//          await dismiss()
//        }
//
//      case let .rows(.element(id: key, action: .tagStateChanged(value))):
//        if let index = state.rows.index(id: key) {
//          let tag = state.rows[index].tag
//          if value {
//            return .send(.delegate(.addTag(tag)))
//          } else {
//            return .send(.delegate(.removeTag(tag)))
//          }
//        }
//        return .none
//
//      case .rows:
//        return .none
//      }
//    }
//    .forEach(\.rows, action: \.rows) {
//      SoundFontTagsEditorItem()
//    }
//  }
//}
//
//public struct SoundFontTagsEditorView: View {
//  private var store: StoreOf<SoundFontTagsEditor>
//
//  public init(store: StoreOf<SoundFontTagsEditor>) {
//    self.store = store
//  }
//
//  public var body: some View {
//    List {
//      ForEach(store.scope(state: \.rows, action: \.rows)) { rowStore in
//        SoundFontTagsEditorItemView(store: rowStore)
//      }
//    }
//    .navigationTitle("Tagging")
//  }
//}
