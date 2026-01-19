// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport

private let log: Logger = .init(category: "TagsEditor")

/**
 Editor for the collection of tags. The tag editing takes place in two areas: one for the tags shown in
 the tags panel on the main screen, and one when editing a specific font. In both, one can create new
 tags, rename previously-created ones, and delete user-created tags. The four built-in tags cannot be modified nor
 deleted.

 * When editing from the tags panel, one can also rearrange the order of the tags by entering "edit mode" and then
   dragging them around.
 * When editing from the font editor, one can change the membership of the font and a user tag.

 */
@Reducer
public struct TagsEditor {

  @frozen
  public enum Mode: Equatable {
    case tagEditing
    case fontEditing

    public var title: String {
      switch self {
      case .tagEditing: return "Tags Editor"
      case .fontEditing: return "Font Tags"
      }
    }
  }

  @Reducer
  public enum Destination {
    case alert(AlertState<Alert>)

    @CasePathable
    public enum Alert {
      case showedHideEmptyTagsNotice
    }
  }

  @ObservableState
  public struct State: Equatable {
    public var rows: IdentifiedArrayOf<TagNameEditor.State>
    public let mode: Mode
    public var editModeActive: Bool = false
    public var focused: Int?
    public var deleting: Set<Tag.ID> = []
    public let soundFontId: SoundFont.ID?
    @Presents public var destination: Destination.State?

    /**
     Define intial state of the feature.

     - parameter mode indication which kind of editing is being done, all tags or font-specific.
     - parameter focused optional tag to make active and focused (only valid for user-defined tags)
     - parameter soundFontId optional sound font that is being edited (only valid in `.fontEditing` mode)
     - parameter memberships optional mapping that describes which tags a font is a member of
     - parameter editMode the SwiftUI edit mode to start off in. Only used here when testing.
     */
    public init(
      mode: Mode,
      focused: Int? = nil,
      soundFontId: SoundFont.ID? = nil,
      memberships: [Tag.ID: Bool]? = nil,
      editModeActive: Bool = false
    ) {
      self.mode = mode
      self.rows = .init(
        uniqueElements: Tag.tags
          .map {
            .init(
              tagId: $0.id,
              draft: .init($0),
              membership: memberships != nil ? (memberships?[$0.id] ?? false) : nil
            )
          }
      )
      self.focused = focused
      self.editModeActive = editModeActive
      self.soundFontId = soundFontId
      self.destination = nil
    }

    public mutating func save() {
      log.debug("saving state")
      withDatabaseWriter { db in
        for id in deleting {
          try Tag.find(id).delete().execute(db)
        }
        for (index, var row) in rows.enumerated() {
          row.save(db, ordering: index, soundFontId: soundFontId)
        }
      }
    }
  }

  public enum Action: BindableAction {
    case addButtonTapped
    case binding(BindingAction<State>)
    case cancelButtonTapped
    case deleteButtonTapped(at: IndexSet)
    case destination(PresentationAction<Destination.Action>)
    case finalizeDeleteTag(rowId: Int)
    case rows(IdentifiedActionOf<TagNameEditor>)
    case saveButtonTapped
    case editModeActiveChanged(Bool)
    case tagMoved(at: IndexSet, to: Int)
    case toggleEditModeActive
  }

  @Dependency(\.defaultDatabase) private var database
  @Shared(.hideEmptyTags) private var hideEmptyTags
  @Shared(.showedHideEmptyTagsNotice) private var showedHideEmptyTagsNotice

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {

      case .addButtonTapped:
        return addTag(&state)

      case .cancelButtonTapped:
        return dismiss(&state, save: false)

      case .deleteButtonTapped(let indices):
        return deleteTag(&state, indices: indices)

      case .editModeActiveChanged(let value):
        state.editModeActive = value
        return .none

      case .finalizeDeleteTag(let rowId):
        return finalizeDeleteTag(&state, rowId: rowId)

      case let .rows(.element(id: id, action: .delegate(.tagSwipedToDelete))):
        return deleteTag(&state, rowId: id)

      case .saveButtonTapped:
        return dismiss(&state, save: true)

      case let .tagMoved(indices, offset):
        return moveTag(&state, at: indices, to: offset)

      case .toggleEditModeActive:
        return toggleEditModeActive(&state)

      default:
        return .none
      }
    }
    .forEach(\.rows, action: \.rows) {
      TagNameEditor()
    }
    .ifLet(\.destination, action: \.destination)
  }

  public init() {}
}

private extension TagsEditor {

  func addTag(_ state: inout State) -> Effect<Action> {
    let base = "New Tag"
    let existingNames = Set<String>(state.rows.map { $0.draft.displayName.trimmed(or: $0.originalDisplayName) })
    var newName = base

    var counter = 0
    while existingNames.contains(newName) {
      counter += 1
      newName = base + " \(counter)"
    }

    let rowId: Int = state.rows.count
    state.rows.append(
      .init(
        tagId: nil,
        draft: .init(displayName: newName, ordering: rowId),
        membership: state.soundFontId != nil ? true : nil
      )
    )

    state.focused = rowId

    // Show alert about empty tags not appearing in main view.
    if state.mode == .tagEditing,
       hideEmptyTags,
       !showedHideEmptyTagsNotice {
      state.destination = .alert(.newTagWillBeHidden())
      $showedHideEmptyTagsNotice.withLock { $0 = true }
    }

    return .none
  }

  func deleteTag(_ state: inout State, rowId: Int) -> Effect<Action> {
    // This is done to support animation of deleted row.
    return .run { send in
      await send(.finalizeDeleteTag(rowId: rowId))
    }
  }

  func deleteTag(_ state: inout State, indices: IndexSet) -> Effect<Action> {
    if let rowId = indices.first {
      return deleteTag(&state, rowId: rowId)
    }
    return .none
  }

  func dismiss(_ state: inout State, save: Bool) -> Effect<Action> {
    if save {
      state.save()
    }
    @Dependency(\.dismiss) var dismiss
    return .run { _ in await dismiss() }
  }

  func finalizeDeleteTag(_ state: inout State, rowId: Int) -> Effect<Action> {
    if state.focused == rowId {
      state.focused = nil
    }

    if let row = state.rows.remove(id: rowId) {
      if let tagId = row.tagId {
        state.deleting.insert(tagId)
      }
    }

    return .none
  }

  func moveTag(_ state: inout State, at indices: IndexSet, to offset: Int) -> Effect<Action> {
    state.rows.move(fromOffsets: indices, toOffset: offset)
    return .none.animation(.smooth)
  }

  func toggleEditModeActive(_ state: inout State) -> Effect<Action> {
    withAnimation {
      state.editModeActive.toggle()
    }
    return .none
  }
}

extension TagsEditor.Destination.State: Equatable {}
extension TagsEditor.Destination.State: _EphemeralState {
  public typealias Action = Alert
}

public struct TagsEditorView: View {
  @Bindable private var store: StoreOf<TagsEditor>
  @FocusState private var focused: Int?

  public init(store: StoreOf<TagsEditor>) {
    self.store = store
  }

  public var body: some View {
    List {
      ForEach(store.scope(state: \.rows, action: \.rows)) { rowStore in
        TagNameEditorView(store: rowStore)
          .deleteDisabled(rowStore.isUbiquitous)
          .focused($focused, equals: rowStore.id)
      }
      .onMove { indices, destination in
        store.send(.tagMoved(at: indices, to: destination), animation: .default)
      }
      .onDelete {
        store.send(.deleteButtonTapped(at: $0), animation: .default)
      }
      .bind($store.focused, to: self.$focused)
    }
    .font(.tagsEditor)
    .navigationTitle(store.mode.title)
    .toolbar {
      if store.mode == .tagEditing {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { store.send(.cancelButtonTapped, animation: .default) }
            .disabled(store.editModeActive)
            .font(.button)
        }

        ToolbarItem(placement: .automatic) {
          Button {
            store.send(.toggleEditModeActive, animation: .default)
          } label: {
            if store.editModeActive {
              Text("Done")
                .foregroundStyle(.red)
            } else {
              Text("Edit")
            }
          }
          .font(.button)
        }
      }
      ToolbarItem(placement: .automatic) {
        Button {
          store.send(.addButtonTapped, animation: .default)
        } label: {
          Image(systemName: "plus")
        }
        .disabled(store.editModeActive)
        .font(.button)
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save") { store.send(.saveButtonTapped, animation: .default) }
          .disabled(store.editModeActive)
          .font(.button)
      }
    }
    .animation(.smooth, value: store.rows)
    .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
#if os(iOS)
    .environment(
      \.editMode,
       Binding(
        get: { store.editModeActive ? .active : .inactive },
        set: { store.send(.editModeActiveChanged($0 == .active)) }
       )
    )
#endif // os(iOS)
  }
}

#if DEBUG

extension TagsEditorView {

  static var preview: some View {
    prepareDependencies {
      $0.defaultDatabase = previewDatabase()
      navigationBarTitleStyle()
    }

    @Dependency(\.defaultDatabase) var db
    _ = try? Tag.make(displayName: "New Tag")
    let tags = Tag.tags
    return TagsEditorView(store: Store(initialState: .init(mode: .tagEditing, focused: tags.last?.ordering)) { TagsEditor() })
  }

  static var previewInEditMode: some View {
    prepareDependencies { $0.defaultDatabase = previewDatabase() }
    let tags = Tag.tags
    return TagsEditorView(store: Store(initialState: .init(mode: .tagEditing, focused: tags.last?.ordering, editModeActive: true)) {
      TagsEditor()
    })
  }

  static var previewWithMemberships: some View {
    prepareDependencies { $0.defaultDatabase = previewDatabase() }
    _ = try? Tag.make(displayName: "New Tag 1")
    _ = try? Tag.make(displayName: "New Tag 2")
    let tags = Tag.tags
    var memberships = [Tag.ID: Bool]()
    memberships[tags[0].id] = true
    memberships[tags[1].id] = true
    memberships[tags[4].id] = true

    return TagsEditorView(store: Store(initialState: .init(
      mode: .fontEditing,
      focused: tags.last?.ordering,
      soundFontId: SoundFont.ID(rawValue: 1),
      memberships: memberships)) {
        TagsEditor()
      })
  }
}

#Preview {
  TagsEditorView.previewWithMemberships
}

#endif // DEBUG
