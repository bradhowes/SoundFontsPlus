// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport
import HelpInfoSpotlightOverlay

private let log: Logger = .init(category: "TagsEditor")

/**
 Editor for the collection of tags. The tag editing takes place in two areas: one for the tags shown in
 the tags panel on the main screen, and one when editing a specific font. In both, one can create new
 tags, rename previously-created ones, and delete user-created tags. The four built-in tags cannot be modified nor
 deleted.

 When editing from the tags panel:

 * one can rearrange the order of the tags by entering "edit mode" then dragging them up and down.
 * tag visibility can be toggled

 When editing from the font editor:

 * one can change the membership of the font and a user tag.

 */
@Reducer
public struct TagsEditor {

  fileprivate enum Mode: Equatable {
    case tagEditing
    case fontEditing

    var title: String {
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
    fileprivate let mode: Mode
    public var rows: IdentifiedArrayOf<TagNameEditor.State>
    public var editModeActive: Bool
    public var focused: Int?
    public var deleting: Set<Tag.ID> = []
    public let soundFontId: SoundFont.ID?
    public var helpInfoSelection: TagsEditorHelpInfo?
    @Presents public var destination: Destination.State?

    /**
     Define initial state of the feature for tag editing from main tag view.

     - parameter focused the index of the tag to set focus on (only useful for user tags).
     - parameter editModeActive true if edit mode is active (only used in tests)
     */
    public init(
      focused: Int? = nil,
      editModeActive: Bool = false
    ) {
      self.mode = .tagEditing
      self.rows = .init(uniqueElements: Tag.tags .map {
        .init(tagId: $0.id, draft: .init($0), membership: nil, visible: $0.visible)
      })
      self.editModeActive = editModeActive
      self.soundFontId = nil
    }

    /**
     Define initial state of the feature for tag editing from sound font editor view.

     - parameter soundFontId the ID of the sound font being edited
     - parameter memberships the mapping of tag memberships for the sound font
     - parameter editModeActive true if edit mode is active (only used in tests)
     */
    public init(
      soundFontId: SoundFont.ID,
      memberships: [Tag.ID: Bool],
      editModeActive: Bool = false
    ) {
      self.mode = .fontEditing
      self.rows = .init(
        uniqueElements: Tag.tags
          .map {
            .init(
              tagId: $0.id,
              draft: .init($0),
              membership: memberships[$0.id] ?? false,
              visible: $0.visible
            )
          }
      )
      self.editModeActive = editModeActive
      self.soundFontId = soundFontId
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
    case helpButtonTapped
    case rows(IdentifiedActionOf<TagNameEditor>)
    case saveButtonTapped
    case editModeActiveChanged(Bool)
    case tagMoved(at: IndexSet, to: Int)
    case toggleEditModeActive
  }

  @Dependency(\.defaultDatabase) private var database
  @Dependency(\.dismiss) var dismiss
  @Shared(.hideEmptyTags) private var hideEmptyTags

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

        // TODO: add test
      case .editModeActiveChanged(let value):
        state.editModeActive = value
        return .none

      case .finalizeDeleteTag(let rowId):
        return finalizeDeleteTag(&state, rowId: rowId)

      case .helpButtonTapped:
        state.helpInfoSelection = state.mode == .fontEditing ? .tagsListMembership : .tagsListVisibility
        return .none

      case let .rows(.element(id: id, action: \.delegate.tagSwipedToDelete)):
        return deleteTag(&state, rowId: id)

        // TODO: add test
      case let .rows(.element(id: id, action: \.binding.membership)):
        // This is only called when editing a sound font, so soundFontId must be non-nil
        guard
          let soundFontId = state.soundFontId,
          let index = state.rows.index(id: id)
        else {
          return .none
        }

        let tagState = state.rows[index]
        if checkForEmptyTag(soundFontId: soundFontId, tagState: tagState) {
          state.destination = .alert(.tagWillBeHidden(displayName: tagState.draft.displayName))
        }
        return .none

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
        membership: state.soundFontId != nil ? false : nil
      )
    )

    state.focused = rowId

    return .none
  }

  func checkForEmptyTag(soundFontId: SoundFont.ID, tagState: TagNameEditor.State) -> Bool {
    if !hideEmptyTags { return false }
    if let tagId = tagState.tagId {
      // Existing tag, os see if we are removing the sole association to the tag
      let memberships = Tag.soundFontIds(for: tagId)
      return memberships.count == 1 && memberships.contains(soundFontId) && !tagState.membership
    } else {
      // New tag and membership was unset
      return !tagState.membership
    }
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
    return .run { [dismiss] _ in await dismiss() }
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
    withAnimation(.smooth) {
      state.rows.move(fromOffsets: indices, toOffset: offset)
    }
    return .none
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

// MARK: - view

public struct TagsEditorView: View {
  @Bindable private var store: StoreOf<TagsEditor>
  @FocusState private var focused: Int?
  @Environment(\.colorScheme) var colorScheme

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
    .helpInfoViewTag(store.mode == .tagEditing ? .tagsListVisibility : .tagsListMembership)
    .navigationTitle(store.mode.title)
    .toolbar {
      ToolbarItem(placement: .automatic) {
        Button {
          store.send(.helpButtonTapped)
        } label: {
          Image(systemName: .helpButtonImageName)
            .tint(Color.mainAccentColor)
        }
      }
      if store.mode == .tagEditing {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            store.send(.cancelButtonTapped, animation: .default)
          } label: {
            Image(systemName: .cancelButtonImageName)
          }
          .disabled(store.editModeActive)
          .helpInfoViewTag(.cancelButton)
        }
        ToolbarItem(placement: .automatic) {
          Button {
            store.send(.toggleEditModeActive, animation: .default)
          } label: {
            if store.editModeActive {
              Text("Done")
                .foregroundStyle(.red)
            } else {
              Image(systemName: .editButtonImageName)
            }
          }
          .helpInfoViewTag(store.editModeActive ? .doneButton : .editButton)
        }
      }
      ToolbarItem(placement: .automatic) {
        Button {
          store.send(.addButtonTapped, animation: .default)
        } label: {
          Image(systemName: .addButtonImageName)
        }
        .disabled(store.editModeActive)
        .helpInfoViewTag(TagsEditorHelpInfo.addButton)
      }
      ToolbarItem(placement: .confirmationAction) {
        Button {
          store.send(.saveButtonTapped, animation: .default)
        } label: {
          Image(systemName: .checkmarkImageName)
        }
        .disabled(store.editModeActive)
        .helpInfoViewTag(.saveButton)
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
    .helpInfoSpotlightOverlay(
      selection: $store.helpInfoSelection,
      orderedIDs: TagsEditorHelpInfo.allCases,
      overlay: { helpItem, actions in
        customHelpInfoOverlay(for: helpItem, actions: actions, colorScheme: colorScheme)
      }
    )
  }
}

extension View {

  public func tagsEditorSheet(_ store: Binding<StoreOf<TagsEditor>?>) -> some View {
    self
      .sheet(item: store) { child in
        NavigationStack {
          TagsEditorView(store: child)
        }
      }
  }
}

#if DEBUG

extension TagsEditorView {

  static var preview: some View {
    _ = try? Tag.make(displayName: "New Tag")
    let tags = Tag.tags
    return TagsEditorView(store: Store(initialState: .init(focused: tags.last?.ordering)) { TagsEditor() })
  }

  static var previewInEditMode: some View {
    preview
      .environment(\.editMode, .constant(.active))
  }

  static var previewWithMemberships: some View {
    _ = try? Tag.make(displayName: "New Tag 1")
    _ = try? Tag.make(displayName: "New Tag 2")
    let tags = Tag.tags
    var memberships = [Tag.ID: Bool]()
    memberships[tags[0].id] = true
    memberships[tags[1].id] = true
    memberships[tags[4].id] = true

    return NavigationView {
      TagsEditorView(
        store: Store(
          initialState: .init(
            soundFontId: SoundFont.ID(rawValue: 1),
            memberships: memberships)
        ) {
          TagsEditor()
        }
      )
    }
  }

  static var previewWithMembershipsInEditMode: some View {
    previewWithMemberships
      .environment(\.editMode, .constant(.active))
  }
}

#Preview {
  // swiftlint:disable:next redundant_discardable_let
  let _ = prepareDependencies {
    installApplicationFont()
    $0.defaultDatabase = previewDatabase()
  }
  TagsEditorView.previewWithMemberships
    .environment(\.font, Font.body)
}

#endif // DEBUG
