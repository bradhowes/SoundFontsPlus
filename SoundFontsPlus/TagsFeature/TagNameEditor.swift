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
    public var draft: FontTag.Draft
    public var id: FontTag.ID { tagId }
    public let tagId: FontTag.ID
    public let originalMembership: Bool?
    public let originalDisplayName: String
    public var membership: Bool

    public init(id: FontTag.ID, draft: FontTag.Draft, membership: Bool? = nil) {
      self.tagId = id
      self.draft = draft
      self.originalDisplayName = draft.displayName
      self.originalMembership = membership
      self.membership = membership ?? false
    }

    public mutating func save(_ db: Database, ordering: Int, soundFontId: SoundFont.ID?) {
      withErrorReporting {
        let newName = draft.displayName.trimmed(or: originalDisplayName)

        // Only update DB if there is a change to record. Be sure to capture the ID any new Tag
        var id = self.id
        if id < 0 || newName != originalDisplayName || ordering != draft.ordering {
          draft.displayName = newName
          draft.ordering = ordering
          let query = FontTag.upsert {
            draft
          }.returning(\.id)
          if let tagId = try query.fetchOne(db) {
            id = tagId
          }
        }

        precondition(id > 0)
        guard let soundFontId else { return }

        if membership != originalMembership {
          if membership {
            try TaggedSoundFont.insert {
              .init(soundFontId: soundFontId, tagId: id)
            }.execute(db)
          } else {
            try TaggedSoundFont.delete().where { $0.soundFontId.eq(soundFontId) && $0.tagId.eq(id) }.execute(db)
          }
        }
      }
    }
  }

  public enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case delegate(Delegate)
    case membershipButtonTapped(Bool)
    case tagSwipedToDelete

    @CasePathable
    public enum Delegate: Equatable {
      case tagSwipedToDelete(FontTag.ID)
    }
  }

  @Dependency(\.defaultDatabase) var database

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding: return .none
      case .delegate: return .none
      case .membershipButtonTapped(let value): return toggleMembership(&state, value: value)
      case .tagSwipedToDelete: return .send(.delegate(.tagSwipedToDelete(state.id)), animation: .default)
      }
    }
  }
}

private extension TagNameEditor {

  func toggleMembership(_ state: inout State, value: Bool) -> Effect<Action> {
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
    toggleNameField
  }

  private var nameField: some View {
    TextField("", text: $store.draft.displayName)
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
      if store.originalMembership != nil {
        Toggle("", isOn: $store.membership)
          .disabled(store.id.isUbiquitous)
          .checkedStyle()
      }
      nameField
    }
  }
}

extension TagNameEditorView {

  static var preview: some View {
    let _ = prepareDependencies { $0.defaultDatabase = try! appDatabase() }
    _ = try? FontTag.make(displayName: "New Tag")
    _ = try? FontTag.make(displayName: "Another Tag")
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
