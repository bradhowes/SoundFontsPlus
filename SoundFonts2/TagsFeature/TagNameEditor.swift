// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import SharingGRDB
import SwiftUI
import Tagged

/**
 Feature that allows for editing of a tag name and optionally the association of a soundFont with the tag.
 */
@Reducer
public struct TagNameEditor {

  @ObservableState
  public struct State: Equatable, Identifiable, Sendable {
    public var draft: Tag.Draft
    public var id: Tag.ID { tagId }
    public let tagId: Tag.ID
    public let originalMembership: Bool?
    public let originalDisplayName: String
    public var membership: Bool?

    public init(id: Tag.ID, draft: Tag.Draft, membership: Bool? = nil) {
      self.tagId = id
      self.draft = draft
      self.originalDisplayName = draft.displayName
      self.originalMembership = membership
      self.membership = membership
    }

    public mutating func save(_ db: Database, ordering: Int, soundFontId: SoundFont.ID?) {
      withErrorReporting {
        let newName = draft.displayName.trimmed(or: originalDisplayName)

        // Only update DB if there is a change to record. Be sure to capture the ID any new Tag
        var id = self.id
        if id < 0 || newName != originalDisplayName || ordering != draft.ordering {
          draft.displayName = newName
          draft.ordering = ordering
          if let tagId = try Tag.upsert(draft).returning(\.id).fetchOne(db) {
            id = tagId
          }
        }

        precondition(id > 0)
        guard let membership, let soundFontId else { return }

        if membership != originalMembership {
          if membership {
            try TaggedSoundFont.insert(.init(soundFontId: soundFontId, tagId: id)).execute(db)
          } else {
            try TaggedSoundFont.delete().where { $0.soundFontId.eq(soundFontId) && $0.tagId.eq(id) }.execute(db)
          }
        }
      }
    }
  }

  public enum Action: Equatable {
    case delegate(Delegate)
    case membershipButtonTapped(Bool)
    case nameChanged(String)
    case tagSwipedToDelete

    @CasePathable
    public enum Delegate: Equatable {
      case tagSwipedToDelete(Tag.ID)
    }
  }

  @Dependency(\.defaultDatabase) var database

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .delegate: return .none
      case .membershipButtonTapped(let value): return toggleMembership(&state, value: value)
      case .nameChanged(let newName): return updateName(&state, value: newName)
      case .tagSwipedToDelete: return .send(.delegate(.tagSwipedToDelete(state.id)), animation: .default)
      }
    }
  }
}

private extension TagNameEditor {

  func toggleMembership(_ state: inout State, value: Bool) -> Effect<Action> {
    precondition(state.membership != nil)
    state.membership = value
    return .none
  }

  func updateName(_ state: inout State, value: String) -> Effect<Action> {
    state.draft.displayName = value
    return .none
  }
}

public struct TagNameEditorView: View {
  @Bindable private var store: StoreOf<TagNameEditor>
  @Environment(\.editMode) private var editMode

  private var readOnly: Bool { store.id.isUbiquitous }
  private var editable: Bool { !readOnly }
  private var isEditing: Bool { editMode?.wrappedValue.isEditing == true }

  public init(store: StoreOf<TagNameEditor>) {
    self.store = store
  }

  public var body: some View {
    let _ = print("rendering cell \(store.tagId)")
    if readOnly {
      name
    }
    else if store.membership == nil || isEditing {
      nameField
    } else {
      toggleNameField
    }
  }

  private var name: some View {
    Text(store.draft.displayName)
      .foregroundStyle(editable ? .blue : .secondary)
      .font(Font.custom("Eurostile", size: 20))
  }

  private var nameField: some View {
    TextField("", text: $store.draft.displayName.sending(\.nameChanged))
      .textFieldStyle(.roundedBorder)
      .disabled(readOnly || isEditing)
      .deleteDisabled(readOnly)
      .foregroundStyle(editable ? .blue : .secondary)
      .font(Font.custom("Eurostile", size: 20))
      .swipeActions(edge: .trailing) {
        if editable {
          Button {
            store.send(.tagSwipedToDelete)
          } label: {
            Image(systemName: "trash")
              .tint(.red)
          }
        }
      }
  }

  private var toggleNameField: some View {
    HStack {
      Toggle("", isOn: Binding(get: { store.membership ?? false }, set: { store.send(.membershipButtonTapped($0)) }))
        .disabled(store.id.isUbiquitous)
        .checkedStyle()
      nameField
    }
  }
}

extension TagNameEditorView {

  static var preview: some View {
    let _ = prepareDependencies { $0.defaultDatabase = try! appDatabase() }
    _ = try? Tag.make(displayName: "New Tag")
    _ = try? Tag.make(displayName: "Another Tag")
    let tags = Operations.tags
    return VStack {
      Form {
        ForEach(tags) { tag in
          TagNameEditorView(
            store: Store(
              initialState: .init(
                id: tag.id,
                draft: .init(tag),
                membership: tag.isUbiquitous ? nil : tag.id.rawValue % 2 == 0
              )
            ) {
              TagNameEditor()
            }
          )
        }
      }
      Form {
        ForEach(tags) { tag in
          TagNameEditorView(
            store: Store(
              initialState: .init(
                id: tag.id,
                draft: .init(tag)
              )
            ) {
              TagNameEditor()
            }
          )
        }
      }
    }
  }
}

#Preview {
  TagNameEditorView.preview
}
