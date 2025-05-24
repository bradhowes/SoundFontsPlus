// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftUI
import Tagged

@Reducer
public struct TagsEditor: Sendable {

  @ObservableState
  public struct State: Equatable, Sendable {
    var rows: IdentifiedArrayOf<TagNameEditor.State>
    var editMode: EditMode = .inactive
    var focused: Tag.ID?
    let soundFontId: SoundFont.ID?
    let showMemberships: Bool

    public init(
      focused: Tag.ID? = nil,
      soundFontId: SoundFont.ID? = nil,
      memberships: [Tag.ID:Bool]? = nil,
      editMode: EditMode = .inactive,
    ) {
      self.rows = .init(uniqueElements: Operations.orderedTags.map {
        .init(
          tag: $0,
          soundFontId: soundFontId,
          membership: memberships != nil ? (memberships?[$0.id] ?? false) : nil
        )
      })
      self.focused = focused
      self.editMode = editMode
      self.soundFontId = soundFontId
      self.showMemberships = memberships != nil
    }
  }

  public enum Action: Equatable, BindableAction {
    case addButtonTapped
    case binding(BindingAction<State>)
    case deleteTag(at: IndexSet)
    case dismissButtonTapped
    case finalizeDeleteTag(IndexSet)
    case rows(IdentifiedActionOf<TagNameEditor>)
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
      case .dismissButtonTapped: return dismissButtonTapped(&state)
      case .finalizeDeleteTag(let indices): return finalizeDeleteTag(&state, indices: indices)
      case let .rows(.element(id: id, action: .delegate(.deleteTag))):
        return deleteTag(&state, indices: IndexSet(integer: IndexSet.Element(id.rawValue)))
      case .rows: return .none
      case let .tagMoved(indices, offset): return moveTag(&state, at: indices, to: offset)
      case .toggleEditMode: return toggleEditMode(&state)
      }
    }
    BindingReducer()
    .forEach(\.rows, action: \.rows) {
      TagNameEditor()
    }
  }

  public init() {}
}

private extension TagsEditor {

  func addTag(_ state: inout State) -> Effect<Action> {
    if let tag = try? Tag.make(displayName: "New Tag") {
      state.rows.append(.init(
        tag: tag,
        soundFontId: state.soundFontId,
        membership: state.showMemberships ? false : nil
      ))
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
       let _ = state.rows.first(where: { $0.id.rawValue == tagId }) {
      let newRows = state.rows.filter { $0.id.rawValue != tagId }
      state.rows = newRows
      _ = Operations.deleteTag(Tag.ID(rawValue: Int64(tagId)))
    }
    return .none.animation(.default)
  }

  func moveTag(_ state: inout State, at indices: IndexSet, to offset: Int) -> Effect<Action> {
    state.rows.move(fromOffsets: indices, toOffset: offset)
    return .none.animation(.default)
  }

  func dismissButtonTapped(_ state: inout State) -> Effect<Action> {
    Operations.updateTags(state.rows.map { ($0.id, $0.name) })
    @Dependency(\.dismiss) var dismiss
    return .run { _ in await dismiss() }
  }

  func toggleEditMode(_ state: inout State) -> Effect<Action> {
    state.editMode = state.editMode.isEditing ? .inactive : .active
    return .none.animation(.default)
  }
}

public struct TagsEditorView: View {
  @Bindable private var store: StoreOf<TagsEditor>
  @FocusState private var focused: Tag.ID?
  @Environment(\.editMode) private var editMode

  public init(store: StoreOf<TagsEditor>) {
    self.store = store
  }

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
          // .bind($store.focused, to: self.$focused)
        } else {
          // When not in editing mode, allow for swipe-to-delete + confirmation of intent
          ForEach(store.scope(state: \.rows, action: \.rows), id: \.state.id) { rowStore in
            TagNameEditorView(store: rowStore)
              .focused($focused, equals: rowStore.tagId)
          }
          .bind($store.focused, to: self.$focused)
        }
      }
      .environment(\.editMode, $store.editMode)
      .navigationTitle("Tags Editor")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Dismiss") { store.send(.dismissButtonTapped, animation: .default) }
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
    let _ = prepareDependencies { $0.defaultDatabase = try! appDatabase() }
    @Dependency(\.defaultDatabase) var db
    let _ = try? Tag.make(displayName: "New Tag")
    let tags = Operations.orderedTags
    return TagsEditorView(store: Store(initialState: .init(focused: tags.last?.id)) { TagsEditor() })
  }

  static var previewInEditMode: some View {
    let _ = prepareDependencies { $0.defaultDatabase = try! appDatabase() }
    let tags = Operations.orderedTags
    return TagsEditorView(store: Store(initialState: .init(focused: tags.last?.id, editMode: .active)) {
      TagsEditor()
    })
  }

  static var previewWithMemberships: some View {
    let _ = prepareDependencies { $0.defaultDatabase = try! appDatabase() }
    let _ = try? Tag.make(displayName: "New Tag 1")
    let _ = try? Tag.make(displayName: "New Tag 2")
    let tags = Operations.orderedTags
    var memberships = [Tag.ID:Bool]()
    memberships[tags[0].id] = true
    memberships[tags[1].id] = true
    memberships[tags[4].id] = true

    return TagsEditorView(store: Store(initialState: .init(
      focused: tags.last?.id,
      soundFontId: SoundFont.ID(rawValue: 1),
      memberships: memberships)) {
      TagsEditor()
    })
  }
}

#Preview {
  TagsEditorView.previewWithMemberships
}
