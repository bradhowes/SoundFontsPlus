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
      self.rows = .init(uniqueElements: tags.map{ .init(tag: $0, takeFocus: false) })
    }
  }

  public enum Action: Sendable {
    case addButtonTapped
    case confirmedDeletion(key: TagModel.Key)
    case deleteButtonTapped(at: IndexSet)
    case dismissButtonTapped
    case rows(IdentifiedActionOf<TagNameEditor>)
    case tagMoved(at: IndexSet, to: Int)
  }

  @Dependency(\.dismiss) var dismiss

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .addButtonTapped:
        addTag(&state)
        return .none

      case .confirmedDeletion(let key):
        deleteTag(&state, key: key)
        return .none

      case let .deleteButtonTapped(indices):
        if let index = indices.first {
          deleteTag(&state, key: state.rows[index].key)
        }
        return .none

      case .dismissButtonTapped:
        let dismiss = dismiss
        return .run { _ in await dismiss() }

      case .rows(.element(let id, .nameChanged(let name))):
        if let index = state.rows.index(id: id) {
          state.rows[index].name = name
          saveNameChange(state, for: index)
        }
        return .none

      case let .tagMoved(indices, offset):
        moveTag(&state, at: indices, to: offset)
        return .none

      case .rows(.element(_, action: .clearTakeFocus)):
        return .none
      }
    }
    .forEach(\.rows, action: \.rows) {
      TagNameEditor()
    }
  }
}

extension TagsEditor {

  private func addTag(_ state: inout State) {
    do {
      let tag = try TagModel.create(name: "New Tag")
      state.rows.append(.init(tag: tag, takeFocus: true))
    } catch {
      print("failed to create new tag")
    }
  }

  private func deleteTag(_ state: inout State, key: TagModel.Key) {
    precondition(!TagModel.Ubiquitous.contains(key: key))
    do {
      if let index = state.rows.index(id: key) {
        state.rows.remove(at: index)
        try TagModel.delete(key: key)
      }
    } catch {
      print("failed to delete tag \(key)")
    }
  }

  private func moveTag(_ state: inout State, at indices: IndexSet, to offset: Int) {
    defer { save() }

    state.rows.move(fromOffsets: indices, toOffset: offset)
    for (index, tagInfo) in state.rows.elements.enumerated() {
      do {
        let tag = try TagModel.fetch(key: tagInfo.key)
        tag.ordering = index
      } catch {
        print("failed to fetch tag \(tagInfo.key)")
      }
    }
  }

  private func saveNameChange(_ state: State, for index: Int) {
    defer { save() }
    do {
      let tag = try TagModel.fetch(key: state.rows[index].key)
      tag.name = state.rows[index].name
    } catch {
      print("failed to update tag \(state.rows[index].key) name")
    }
  }

  private func save() {
    @Dependency(\.modelContextProvider) var context
    do {
      try context.save()
    } catch {
      print("failed to save changes")
    }
  }
}

public struct TagsEditorView: View {
  private var store: StoreOf<TagsEditor>

  public init(store: StoreOf<TagsEditor>) {
    self.store = store
  }

  public var body: some View {
    List {
      TagsEditorRowsView(store: store)
    }
    .navigationTitle("Tags")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Dismiss") {
          store.send(.dismissButtonTapped, animation: .default)
        }
      }
      ToolbarItem(placement: .automatic) {
        AddButton {
          store.send(.addButtonTapped, animation: .default)
        }
      }
      ToolbarItem(placement: .automatic) {
        EditButton()
      }
    }
  }
}

// Create custom button view that tracks the editMode state and disables itself when editiing is active
// Views that are not children of the view hosting the `EditButton` do not see its effect.
private struct AddButton: View {
  private let action: () -> Void
  @Environment(\.editMode) var editMode
  private var editing: Bool { editMode?.wrappedValue.isEditing ?? false }

  init(action: @escaping () -> Void) {
    self.action = action
  }

  public var body: some View {
    Button("Add Tag", systemImage: "plus", action: action)
      .disabled(editing)
  }
}

private struct TagsEditorRowsView: View {
  @Environment(\.editMode) var editMode
  private var store: StoreOf<TagsEditor>
  private var editing: Bool { editMode?.wrappedValue.isEditing ?? false }

  init(store: StoreOf<TagsEditor>) {
    self.store = store
  }

  var body: some View {
    if editing {
      ForEach(store.scope(state: \.rows, action: \.rows), id: \.state.key) { rowStore in
        TagNameEditorView(store: rowStore, canSwipe: false, deleteAction: deleteAction(key: rowStore.state.key))
      }
      .onMove { store.send(.tagMoved(at: $0, to: $1), animation: .default) }
      .onDelete { store.send(.deleteButtonTapped(at: $0), animation: .default) }
    } else {
      // When not in editing mode, allow for swipe-to-delete + confirmation of intent
      ForEach(store.scope(state: \.rows, action: \.rows), id: \.state.key) { rowStore in
        TagNameEditorView(store: rowStore, canSwipe: true, deleteAction: deleteAction(key: rowStore.state.key))
      }
    }
  }

  private func deleteAction(key: TagModel.Key) -> ((TagModel.Key) -> Void)? {
    TagModel.Ubiquitous.contains(key: key) ? nil : { store.send(.confirmedDeletion(key: $0), animation: .default) }
  }
}
