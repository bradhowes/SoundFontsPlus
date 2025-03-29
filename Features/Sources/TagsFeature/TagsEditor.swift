import ComposableArchitecture
import GRDB
import Models
import SwiftUI

@Reducer
public struct TagsEditor {

  @ObservableState
  public struct State: Equatable {
    var rows: IdentifiedArrayOf<TagNameEditor.State>
    var editMode: EditMode = .inactive
    var focused: Tag.ID?

    public init(tags: [Tag], focused: Tag.ID?, editMode: EditMode = .inactive) {
      self.rows = .init(uniqueElements: tags.map{ .init(tag: $0) })
      self.focused = focused
      self.editMode = editMode
    }
  }

  public enum Action: Equatable, BindableAction {
    case addButtonTapped
    case binding(BindingAction<State>)
    case deleteTag(at: IndexSet)
    case finalizeDeleteTag(IndexSet)
    case rows(IdentifiedActionOf<TagNameEditor>)
    case saveButtonTapped
    case tagMoved(at: IndexSet, to: Int)
    case toggleEditMode
  }

  @Dependency(\.defaultDatabase) var database

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .addButtonTapped: return addTag(&state)
      case .binding: return .none
      case .deleteTag(let indices): return deleteTag(&state, indices: indices)
      case .finalizeDeleteTag(let indices): return finalizeDeleteTag(&state, indices: indices)
      case let .rows(.element(id: id, action: .delegate(.deleteTag))):
        return deleteTag(&state, indices: IndexSet(integer: IndexSet.Element(id.rawValue)))
      case .rows: return .none
      case .saveButtonTapped: return saveButtonTapped(&state)
      case let .tagMoved(indices, offset): return moveTag(&state, at: indices, to: offset)
      case .toggleEditMode: return toggleEditMode(&state)
      }
    }
    BindingReducer()
    .forEach(\.rows, action: \.rows) {
      TagNameEditor()
    }
  }
}

private extension TagsEditor {

  func addTag(_ state: inout State) -> Effect<Action> {
    let tags = Support.addTag(existing: state.rows.map { $0.tag} )
    if let tag = tags.last {
      state.rows.append(.init(tag: tag))
      state.focused = tag.id
    }
    return .none.animation(.default)
  }

  func deleteTag(_ state: inout State, indices: IndexSet) -> Effect<Action> {
    return .run { send in
      await send(.finalizeDeleteTag(indices))
    }.animation(.default)
  }

  func finalizeDeleteTag(_ state: inout State, indices: IndexSet) -> Effect<Action> {
    if let tagId = indices.first,
       let row = state.rows.first(where: { $0.id.rawValue == tagId }) {
      let newRows = state.rows.filter { $0.id.rawValue != tagId }
      state.rows = newRows
      _ = try? database.write { db in try row.tag.delete(db) }
    }
    return .none.animation(.default)
  }

  func moveTag(_ state: inout State, at indices: IndexSet, to offset: Int) -> Effect<Action> {
    state.rows.move(fromOffsets: indices, toOffset: offset)
    print(state.rows)
    return .none.animation(.default)
  }

  func saveButtonTapped(_ state: inout State) -> Effect<Action> {
    let tags = state.rows.enumerated().map { index, editor in
      var changed = editor.tag
      changed.name = editor.name
      changed.ordering = index
      return changed
    }

    _ = try? database.write { db in
      for var tag in tags {
        try tag.save(db)
      }
    }

    @Dependency(\.dismiss) var dismiss
    return .run { _ in await dismiss() }
  }

  func toggleEditMode(_ state: inout State) -> Effect<Action> {
    state.editMode = state.editMode.isEditing ? .inactive : .active
    return .none.animation(.default)
  }
}

public struct TagsEditorView: View {
  @Bindable var store: StoreOf<TagsEditor>
  @FocusState var focused: Tag.ID?
  @Environment(\.editMode) var editMode

  public var body: some View {
    NavigationStack {
      List {
        if store.editMode.isEditing {
          // When in editing mode, there is not confirmation of deletion, and no swipe button.
          ForEach(store.scope(state: \.rows, action: \.rows), id: \.state.id) { rowStore in
            TagNameEditorView(store: rowStore)
          }
          .onMove { store.send(.tagMoved(at: $0, to: $1), animation: .default) }
          .onDelete { store.send(.deleteTag(at: $0), animation: .default) }
          .bind($store.focused, to: self.$focused)
        } else {
          // When not in editing mode, allow for swipe-to-delete + confirmation of intent
          ForEach(store.scope(state: \.rows, action: \.rows), id: \.state.id) { rowStore in
            TagNameEditorView(store: rowStore)
              .focused($focused, equals: rowStore.tag.id)
          }
          .bind($store.focused, to: self.$focused)
        }
      }
      .environment(\.editMode, $store.editMode)
      .navigationTitle("Tags Editor")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Save") { store.send(.saveButtonTapped, animation: .default) }
            .disabled(store.editMode == .active)
        }
        ToolbarItem(placement: .automatic) {
          Button("Add Tag", systemImage: "plus") { store.send(.addButtonTapped, animation: .default) }
            .disabled(store.editMode == .active)
        }
        ToolbarItem(placement: .automatic) {
          Button {
            store.send(.toggleEditMode, animation: .default)
          } label: {
            if store.editMode.isEditing {
              Text("Done")
                .foregroundStyle(.red)
            } else {
              Text("Edit")
            }
          }
        }
      }
    }
  }
}

extension TagsEditorView {

  static var preview: some View {
    let _ = prepareDependencies { $0.defaultDatabase = try! .appDatabase() }
    @Dependency(\.defaultDatabase) var db

    let tags = try! db.write {
      _ = try Tag.make($0, name: "New Tag")
      return try Tag.all().fetchAll($0)
    }

    return TagsEditorView(store: Store(initialState: .init(tags: tags, focused: tags.last?.id)) { TagsEditor() })
  }

  static var previewInEditMode: some View {
    let _ = prepareDependencies { $0.defaultDatabase = try! .appDatabase() }
    @Dependency(\.defaultDatabase) var db

    let tags = try! db.write {
      _ = try Tag.make($0, name: "New Tag")
      return try Tag.all().fetchAll($0)
    }

    return TagsEditorView(store: Store(initialState: .init(tags: tags, focused: tags.last?.id, editMode: .active)) {
      TagsEditor()
    })
  }
}

#Preview {
  TagsEditorView.preview
}
