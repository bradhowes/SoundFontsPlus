// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport
import SQLiteData

private let log: Logger = .init(category: "TagNameEditor")

/**
 Feature that allows for editing of a tag name and optionally the association of a soundFont with the tag.
 */
@Reducer
public struct TagNameEditor {

  @ObservableState
  public struct State: Equatable, Identifiable {

    /// The unique ID to use -- since new tags do not have a Tag.ID, use ``Tag.Draft.ordering`` to provide a unique value.
    public var id: Int { draft.ordering }
    public var draft: Tag.Draft
    public var tagId: Tag.ID?
    public var membership: Bool

    public let originalMembership: Bool?
    public let originalDisplayName: String

    public var isUbiquitous: Bool { tagId?.isUbiquitous ?? false }

    public init(tagId: Tag.ID? = nil, draft: Tag.Draft, membership: Bool? = nil) {
      self.tagId = tagId
      self.draft = draft
      self.originalDisplayName = draft.displayName
      self.originalMembership = membership
      self.membership = tagId == nil ? true : (membership ?? false)
    }

    public mutating func save(_ db: Database, ordering: Int, soundFontId: SoundFont.ID?) {
      withErrorReporting {
        let newName = draft.displayName.trimmed(or: originalDisplayName)

        // Only update DB if there is a change to record. Be sure to capture the ID any new Tag
        if tagId == nil || newName != originalDisplayName || ordering != draft.ordering {
          draft.displayName = newName
          draft.ordering = ordering
          let query = Tag.upsert {
            draft
          }.returning(\.id)
          if let tagId = try query.fetchOne(db) {
            self.tagId = tagId
          }
        }

        guard let soundFontId else { return }

        if let tagId, membership != originalMembership {
          if membership {
            log.debug("tagging font with \(newName)")
            try TaggedSoundFont.insert {
              .init(soundFontId: soundFontId, tagId: tagId)
            }
            .execute(db)
          } else {
            log.debug("untagging font")
            try TaggedSoundFont.delete()
              .where {
                $0.soundFontId.eq(soundFontId) && $0.tagId.eq(tagId)
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
      case tagSwipedToDelete(Int)
    }
  }

  @Dependency(\.defaultDatabase) private var database

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {

      case .binding(\.membership):
        print(action)
        return .none

      case .binding:
        return .none

      case .tagSwipedToDelete:
        return .run { [stateId = state.id] send in
            await send(.delegate(.tagSwipedToDelete(stateId)), animation: .default)
        }

      case .delegate:
        return .none

      }
    }
  }
}

public struct TagNameEditorView: View {
  @Bindable private var store: StoreOf<TagNameEditor>
  private var readOnly: Bool { store.isUbiquitous }
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
          .disabled(store.isUbiquitous)
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

#if DEBUG

extension TagNameEditorView {

  static var preview: some View {
    _ = try? Tag.make(displayName: "New Tag")
    _ = try? Tag.make(displayName: "Another Tag")
    let tags = Tag.tags
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
  // swiftlint:disable:next redundant_discardable_let
  let _ = prepareDependencies {
    installApplicationFont()
    $0.defaultDatabase = previewDatabase()
  }

  TagNameEditorView.preview
    .environment(\.font, Font.body)
}

#endif // DEBUG
