import ComposableArchitecture
import Models
import SwiftUI
import SwiftUINavigation

@Reducer
public struct TagsEditor {

  @ObservableState
  public struct State: Equatable {
    var rows: IdentifiedArrayOf<TagNameEditor.State>

    public init(tags: IdentifiedArrayOf<TagModel>) {
      self.rows = .init(uniqueElements: tags.map{ .init(tag: $0) })
    }
  }

  public enum Action: Equatable, Sendable {
    case addButtonTapped
    case deleteButtonTapped(IndexSet)
    case rows(IdentifiedActionOf<TagNameEditor>)
    case tagMoved(at: IndexSet, to: Int)
    case tagNameChanged
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .addButtonTapped:
        addTag(&state)
        return .none

      case let .deleteButtonTapped(indices):
        deleteTag(&state, at: indices)
        return .none

      case .rows:
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
      for var each in state.rows where each.hasFocus {
        each.hasFocus = false
      }

      let tag = try TagModel.create(name: "New Tag")
      state.rows.append(.init(tag: tag))
    } catch {
      print("failed to create new tag")
    }
  }

  private func deleteTag(_ state: inout State, at indices: IndexSet) {
    if let index = indices.first {
      let key = state.rows[index].key
      state.rows.remove(atOffsets: indices)
      do {
        try TagModel.delete(key: key)
      } catch {
        print("failed to delete tag \(key)")
      }
    }
  }

  private func moveTag(_ state: inout State, at indices: IndexSet, to offset: Int) {
    @Dependency(\.modelContextProvider) var context
    state.rows.move(fromOffsets: indices, toOffset: offset)
    for (index, tagInfo) in state.rows.elements.enumerated() {
      do {
        let tag = try TagModel.fetch(key: tagInfo.key)
        tag.ordering = index
      } catch {
        print("failed to fetch tag \(tagInfo.key)")
      }
    }

    do {
      try context.save()
    } catch {
      print("failed to save changes")
    }
  }

  private func saveChanges(_ state: State) {
    @Dependency(\.modelContextProvider) var context
    for tagInfo in state.rows.elements {
      do {
        let tag = try TagModel.fetch(key: tagInfo.key)
        tag.name = tagInfo.name
      } catch {
        print("failed to fetch tag \(tagInfo.key)")
      }
    }
    try? context.save()
  }
}

public struct TagsEditorView: View {
  @Bindable private var store: StoreOf<TagsEditor>

  public init(store: StoreOf<TagsEditor>) {
    self.store = store
  }

  public var body: some View {
    let _ = Self._printChanges()
    List {
      ForEach(store.scope(state: \.rows, action: \.rows), id: \.state.key) { store in
        TagNameEditorView(store: store)
      }
      .onMove { store.send(.tagMoved(at: $0, to: $1)) }
      .onDelete { store.send(.deleteButtonTapped($0)) }
    }
  }
}
