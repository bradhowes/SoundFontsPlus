// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftUI
import Tagged

@Reducer
public struct TagsEditor: Sendable {

  public enum Mode: Sendable {
    case tagEditing
    case fontEditing

    public var title: String {
      switch self {
      case .tagEditing: return "Tags Editor"
      case .fontEditing: return "Font Tags"
      }
    }
  }

  @ObservableState
  public struct State: Equatable, Sendable {
    var rows: IdentifiedArrayOf<TagNameEditor.State>
    let mode: Mode
    var editMode: EditMode = .inactive
    var focused: FontTag.ID?
    var deleted: Set<FontTag.ID> = []

    let soundFontId: SoundFont.ID?

    public init(
      mode: Mode,
      focused: FontTag.ID? = nil,
      soundFontId: SoundFont.ID? = nil,
      memberships: [FontTag.ID:Bool]? = nil,
      editMode: EditMode = .inactive,
    ) {
      self.mode = mode
      self.rows = .init(uniqueElements: Operations.tags.map {
        .init(
          id: $0.id,
          draft: .init($0),
          membership: memberships != nil ? (memberships?[$0.id] ?? false) : nil
        )
      })
      self.focused = focused
      self.editMode = editMode
      self.soundFontId = soundFontId
    }

    public mutating func save() {
      @Dependency(\.defaultDatabase) var database
      withErrorReporting {
        try database.write { db in
          for id in deleted {
            withErrorReporting {
              try FontTag.find(id).delete().execute(db)
            }
          }
          for (index, var row) in rows.enumerated() {
            row.save(db, ordering: index, soundFontId: soundFontId)
          }
        }
      }
    }
  }

  public enum Action: Equatable, BindableAction {
    case addButtonTapped
    case binding(BindingAction<State>)
    case cancelButtonTapped
    case deleteButtonTapped(at: IndexSet)
    case finalizeDeleteTag(tagId: FontTag.ID)
    case rows(IdentifiedActionOf<TagNameEditor>)
    case saveButtonTapped
    case tagMoved(at: IndexSet, to: Int)
    case toggleEditMode
  }

  @Dependency(\.defaultDatabase) var database
  @Shared(.activeState) var activeState

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .addButtonTapped: return addTag(&state)
      case .binding: return .none
      case .cancelButtonTapped: return dismiss(&state, save: false)
      case .deleteButtonTapped(let indices): return deleteTag(&state, indices: indices)
      case .finalizeDeleteTag(let tagId): return finalizeDeleteTag(&state, tagId: tagId)
      case let .rows(.element(id: id, action: .delegate(.tagSwipedToDelete))): return deleteTag(&state, tagId: id)
      case .rows: return .none
      case .saveButtonTapped: return dismiss(&state, save: true)
      case let .tagMoved(indices, offset): return moveTag(&state, at: indices, to: offset)
      case .toggleEditMode: return toggleEditMode(&state)
      }
    }
    .forEach(\.rows, action: \.rows) {
      TagNameEditor()
    }
  }

  public init() {}
}

private extension TagsEditor {

  func addTag(_ state: inout State) -> Effect<Action> {
    let base = "New Tag"
    let existingNames = Set<String>(state.rows.map { $0.draft.displayName.trimmed(or: $0.originalDisplayName) })
    var newName = base

    var tagId: FontTag.ID = 0
    while existingNames.contains(newName) {
      tagId += 1
      newName = base + " \(tagId.rawValue)"
    }

    // Added tags always have negative Tag.ID values so we can properly handle them when we save.
    tagId = FontTag.ID(rawValue: -1)
    while state.rows.index(id: tagId) != nil {
      tagId -= 1
    }

    state.rows.append(.init(
      id: tagId,
      draft: .init(displayName: newName, ordering: state.rows.count),
      membership: state.soundFontId != nil ? false : nil
    ))

    state.focused = tagId

    return .none
  }

  func finalizeDeleteTag(_ state: inout State, tagId: FontTag.ID) -> Effect<Action> {
    withAnimation(.smooth) {
      state.rows = state.rows.filter { $0.id != tagId }
    }
    if tagId > 0 {
      state.deleted.insert(tagId)
    }
    return .none
  }

  func deleteTag(_ state: inout State, tagId: FontTag.ID) -> Effect<Action> {
    return .run { send in
      await send(.finalizeDeleteTag(tagId: tagId))
    }
  }

  func deleteTag(_ state: inout State, indices: IndexSet) -> Effect<Action> {
    if let tagId = indices.first, state.rows.first(where: { $0.id.rawValue == tagId }) != nil {
      return deleteTag(&state, tagId: FontTag.ID(rawValue: Int64(tagId)))
    }
    return .none
  }

  func moveTag(_ state: inout State, at indices: IndexSet, to offset: Int) -> Effect<Action> {
    state.rows.move(fromOffsets: indices, toOffset: offset)
    return .none.animation(.smooth)
  }

  func dismiss(_ state: inout State, save: Bool) -> Effect<Action> {
    if save {
      state.save()
    }
    @Dependency(\.dismiss) var dismiss
    return .run { _ in await dismiss() }
  }

  func toggleEditMode(_ state: inout State) -> Effect<Action> {
    withAnimation {
      state.editMode = state.editMode.isEditing ? .inactive : .active
    }
    return .none
  }
}

public struct TagsEditorView: View {
  @Bindable private var store: StoreOf<TagsEditor>
  @FocusState private var focused: FontTag.ID?

  public init(store: StoreOf<TagsEditor>) {
    self.store = store
    UINavigationBar.appearance().largeTitleTextAttributes = [
      .font : UIFont(name: "Eurostile", size: 48)!,
      .foregroundColor : UIColor.systemBlue
    ]
  }

  public var body: some View {
    NavigationStack {
      List {
        ForEach(store.scope(state: \.rows, action: \.rows)) { rowStore in
          TagNameEditorView(store: rowStore)
            .deleteDisabled(rowStore.id.isUbiquitous)
            .focused($focused, equals: rowStore.id)
        }
        .onMove { indices, destination in
          store.send(.tagMoved(at: indices, to: destination), animation: .default)
        }
        .onDelete {
          print("onDelete: at: \($0)")
          store.send(.deleteButtonTapped(at: $0), animation: .default)
        }
        .bind($store.focused, to: self.$focused)
      }
      .font(.tagsEditor)
      .navigationTitle(store.mode.title)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { store.send(.cancelButtonTapped, animation: .default) }
            .disabled(store.editMode == .active)
        }
        if store.mode == .tagEditing {
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
        ToolbarItem(placement: .automatic) {
          Button {
            store.send(.addButtonTapped, animation: .default)
          } label: {
            Image(systemName: "plus")
          }
          .disabled(store.editMode == .active)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { store.send(.saveButtonTapped, animation: .default) }
            .disabled(store.editMode == .active)
        }
      }
      .environment(\.editMode, $store.editMode)
      .environment(\.colorScheme, .dark)
    }
  }
}

extension TagsEditorView {

  static var preview: some View {
    let _ = prepareDependencies { $0.defaultDatabase = try! appDatabase() }
    @Dependency(\.defaultDatabase) var db
    let _ = try? FontTag.make(displayName: "New Tag")
    let tags = Operations.tags
    return TagsEditorView(store: Store(initialState: .init(mode: .tagEditing, focused: tags.last?.id)) { TagsEditor() })
  }

  static var previewInEditMode: some View {
    let _ = prepareDependencies { $0.defaultDatabase = try! appDatabase() }
    let tags = Operations.tags
    return TagsEditorView(store: Store(initialState: .init(mode: .tagEditing, focused: tags.last?.id, editMode: .active)) {
      TagsEditor()
    })
  }

  static var previewWithMemberships: some View {
    let _ = prepareDependencies { $0.defaultDatabase = try! appDatabase() }
    let _ = try? FontTag.make(displayName: "New Tag 1")
    let _ = try? FontTag.make(displayName: "New Tag 2")
    let tags = Operations.tags
    var memberships = [FontTag.ID:Bool]()
    memberships[tags[0].id] = true
    memberships[tags[1].id] = true
    memberships[tags[4].id] = true

    return TagsEditorView(store: Store(initialState: .init(
      mode: .fontEditing,
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
