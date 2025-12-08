// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport
import SQLiteData

private let log = Logger(category: "TagNameEditor")

/**
 Feature that allows for editing of a tag name and optionally the association of a soundFont with the tag.
 */
@Reducer
public struct TagNameEditor {

  @ObservableState
  public struct State: Equatable, Identifiable, Sendable {
    public var id: FontTag.ID { tagId }

    public var draft: FontTag.Draft
    public let tagId: FontTag.ID
    public let originalMembership: Bool?
    public let originalDisplayName: String
    public var membership: Bool

    public init(tagId: FontTag.ID, draft: FontTag.Draft, membership: Bool? = nil) {
      self.tagId = tagId
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
          log.debug("saving changes - \(id) \(newName) \(ordering)")
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
            log.debug("tagging font with \(newName)")
            try TaggedSoundFont.insert {
              .init(soundFontId: soundFontId, tagId: id)
            }
            .execute(db)
          } else {
            log.debug("untagging font")
            try TaggedSoundFont.delete()
              .where {
                $0.soundFontId.eq(soundFontId) && $0.tagId.eq(id)
              }
              .execute(db)
          }
        }
      }
    }
  }

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case delegate(Delegate)
    case tagSwipedToDelete

    @CasePathable
    public enum Delegate: Equatable {
      case tagSwipedToDelete(FontTag.ID)
    }
  }

  @Dependency(\.defaultDatabase) private var database

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {

      case .tagSwipedToDelete:
        return .send(.delegate(.tagSwipedToDelete(state.id)), animation: .default)

      default:
        return .none
      }
    }
  }
}

public struct TagNameEditorView: View {
  @Bindable private var store: StoreOf<TagNameEditor>
  private var readOnly: Bool { store.id.isUbiquitous }
  private var editable: Bool { !readOnly }

  public init(store: StoreOf<TagNameEditor>) {
    self.store = store
  }

  public var body: some View {
    toggleNameField
  }

  private var toggleNameField: some View {
    HStack {
      if store.originalMembership != nil {
        Toggle("", isOn: $store.membership)
          .toggleStyle(.circledCheckMarkNoLabel)
          .disabled(store.id.isUbiquitous)
          .buttonStyle(.plain)
      }
      NameFieldView(text: $store.draft.displayName, readOnly: readOnly)
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
  }
}

extension TagNameEditorView {

  static var preview: some View {
    prepareDependencies { $0.defaultDatabase = previewDatabase() }
    _ = try? FontTag.make(displayName: "New Tag")
    _ = try? FontTag.make(displayName: "Another Tag")
    let tags = FontTag.tags
    return VStack {
      Form {
        ForEach(tags) { tag in
          TagNameEditorView(
            store: Store(
              initialState: .init(
                tagId: tag.id,
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
                tagId: tag.id,
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
