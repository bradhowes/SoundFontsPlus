import ComposableArchitecture
import Models
import SwiftUI
import SwiftUINavigation

@Reducer
public struct TagsEditor {

  @Reducer(action: .sendable)
  public enum Destination {
    case alert(AlertState<Support.Alert>)
  }

  @ObservableState
  public struct State: Equatable {
    @Presents var destination: Destination.State?
    var rows: IdentifiedArrayOf<TagNameEditor.State>

    public init(tags: IdentifiedArrayOf<TagModel>) {
      self.rows = .init(uniqueElements: tags.map{ .init(tag: $0) })
    }
  }

  public enum Action: BindableAction, Sendable {
    case addButtonTapped
    case binding(BindingAction<State>)
    case confirmedDeletion(key: TagModel.Key)
    case deleteButtonSwiped(key: TagModel.Key, name: String)
    case deleteButtonTapped(at: IndexSet)
    case destination(PresentationAction<Destination.Action>)
    case dismissButtonTapped
    case rows(IdentifiedActionOf<TagNameEditor>)
    case tagMoved(at: IndexSet, to: Int)
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

      case .confirmedDeletion(let key):
        deleteTag(&state, key: key)
        return .run { _ in
          @Dependency(\.dismiss) var dismiss
          await dismiss()
        }

      case let .deleteButtonSwiped(key, name):
        state.destination = .alert(.confirmTagDeletion(key, name: name))
        return .none

      case let .deleteButtonTapped(indices):
        if let index = indices.first {
          deleteTag(&state, key: state.rows[index].key)
        }
        return .none

      case .destination(.presented(.alert(let alertAction))):
        switch alertAction {
        case .confirmedDeletion(let key):
          deleteTag(&state, key: key)
        }
        return .none

      case .destination:
        return .none

      case .dismissButtonTapped:
        return .none

      case .rows(.element(let id, .nameChanged(let name))):
        if let index = state.rows.index(id: id) {
          state.rows[index].name = name
          saveNameChange(state, for: index)
        }
        return .none

      case let .tagMoved(indices, offset):
        moveTag(&state, at: indices, to: offset)
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }
}

extension TagsEditor.Destination.State: Equatable {}

extension TagsEditor {

  private func addTag(_ state: inout State) {
    do {
      let tag = try TagModel.create(name: "New Tag")
      state.rows.append(.init(tag: tag))
    } catch {
      print("failed to create new tag")
    }
  }

  private func deleteTag(_ state: inout State, key: TagModel.Key) {
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
  @Bindable private var store: StoreOf<TagsEditor>

  public init(store: StoreOf<TagsEditor>) {
    self.store = store
  }

  public var body: some View {
    List {
      TagEditorRowsView(store: store)
    }
    .navigationTitle("Tags")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Dismiss") {
          store.send(.dismissButtonTapped, animation: .default)
        }
      }
      ToolbarItem(placement: .automatic) {
        Button {
          store.send(.addButtonTapped)
        } label: {
          Image(systemName: "plus")
        }
      }
      ToolbarItem(placement: .automatic) {
        EditButton()
      }
    }
  }
}

public struct TagEditorRowsView: View {
  @Environment(\.editMode) var editMode
  @Bindable private var store: StoreOf<TagsEditor>

  public init(store: StoreOf<TagsEditor>) {
    self.store = store
  }

  public var body: some View {

    // When in editing mode, we do not want to have a swipe-to-delete item and we want to enable the onMove and
    // onDelete actions. There is no confirmation shown for any deletions.
    if editMode?.wrappedValue.isEditing ?? false {
      return ForEach(store.scope(state: \.rows, action: \.rows), id: \.state.key) { rowStore in
        TagNameEditorView(store: rowStore)
      }
      .onMove { store.send(.tagMoved(at: $0, to: $1)) }
      .onDelete { store.send(.deleteButtonTapped(at: $0)) }
      .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
    } else {

      // When not in editing mode, allow for swipe-to-delete + confirmation of intent
      return ForEach(store.scope(state: \.rows, action: \.rows), id: \.state.key) { rowStore in
        withDeleteSwipeActions(rowStore: rowStore) {
          TagNameEditorView(store: rowStore)
        }
      }
      .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
    }
  }

  private func withDeleteSwipeActions<T>(
    rowStore: StoreOf<TagNameEditor>,
    @ViewBuilder content: () -> T
  ) -> some View where T: View {
    content()
      .swipeActions {
        if rowStore.state.editable {
          Button(role: .destructive) {
            store.send(.deleteButtonSwiped(key: rowStore.state.key, name: rowStore.state.name))
          } label: {
            Label("Delete", systemImage: "trash")
          }
        }
      }
  }
}
