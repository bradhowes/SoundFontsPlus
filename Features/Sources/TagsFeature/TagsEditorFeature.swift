import ComposableArchitecture
import Models
import SwiftUI
import SwiftUINavigation

@Reducer
public struct TagsEditorFeature {

  @ObservableState
  public struct State: Equatable {
    var tagInfos: IdentifiedArrayOf<TagInfo>

    public init(tags: IdentifiedArrayOf<TagModel>) {
      self.tagInfos = .init(
        uniqueElements: tags.map{
          .init(key: $0.key, ordering: $0.ordering, editable: !$0.ubiquitous, name: $0.name)
        }
      )
    }
  }

  public enum Action: BindableAction, Equatable, Sendable {
    case addButtonTapped
    case binding(BindingAction<State>)
    case deleteButtonTapped(IndexSet)
    case tagMoved(at: IndexSet, to: Int)
    case tagNameChanged
  }

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .addButtonTapped:
        addTag(&state)
        return .none

      case .binding:
        return .none

      case let .deleteButtonTapped(indices):
        deleteTag(&state, at: indices)
        return .none

      case let .tagMoved(indices, offset):
        moveTag(&state, at: indices, to: offset)
        return .none

      case .tagNameChanged:
        saveChanges(state)
        return .none
      }
    }
  }

  private func addTag(_ state: inout State) {
    do {
      let tag = try TagModel.create(name: "New Tag")
      state.tagInfos.append(.init(key: tag.key, ordering: tag.ordering, editable: !tag.ubiquitous, name: tag.name))
    } catch {
      print("duplicate tags are not allowed")
    }
  }

  private func deleteTag(_ state: inout State, at indices: IndexSet) {
    if let index = indices.first {
      let key = state.tagInfos[index].key
      state.tagInfos.remove(atOffsets: indices)
      do {
        try TagModel.delete(key: key)
      } catch {
        print("failed to delete tag \(key)")
      }
    }
  }

  private func moveTag(_ state: inout State, at indices: IndexSet, to offset: Int) {
    @Dependency(\.modelContextProvider) var context
    state.tagInfos.move(fromOffsets: indices, toOffset: offset)
    for (index, tagInfo) in state.tagInfos.elements.enumerated() {
      if let tag = TagModel.fetch(key: tagInfo.key) {
        tag.ordering = index
      }
    }

    do {
      try context.save()
    } catch {
      print("failed to save changes")
    }
  }

  private func saveChanges(_ state: State) {

  }
}

public struct TagsEditorView: View {
  @Bindable private var store: StoreOf<TagsEditorFeature>

  public init(store: StoreOf<TagsEditorFeature>) {
    self.store = store
  }

  public var body: some View {
    List {
      ForEach(store.tagInfos.elements) { tagInfo in
        Text(tagInfo.name)
          .disabled(!tagInfo.editable)
          .onSubmit { store.send(.tagNameChanged) }
          .deleteDisabled(!tagInfo.editable)
      }
      .onMove { store.send(.tagMoved(at: $0, to: $1)) }
      .onDelete { store.send(.deleteButtonTapped($0)) }
    }
  }
}

