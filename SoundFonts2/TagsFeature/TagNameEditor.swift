// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftUI
import Tagged

/**
 Feature that allows for editing of a tag name and optionally the association of a soundFont with the tag.
 */
@Reducer
public struct TagNameEditor {

  @ObservableState
  public struct State: Equatable, Identifiable, Sendable {
    public var id: Tag.ID { tag.id }
    public var newName: String
    public var membership: Bool?

    public let tag: Tag
    public let soundFontId: SoundFont.ID?

    public init(tag: Tag, soundFontId: SoundFont.ID? = nil, membership: Bool? = nil) {
      self.newName = tag.displayName
      self.membership = membership
      self.tag = tag
      self.soundFontId = soundFontId
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
    guard let soundFontId = state.soundFontId, state.membership != nil else { return .none }
    state.membership = value
    if value {
      Operations.tagSoundFont(state.id, soundFontId: soundFontId)
    } else {
      Operations.untagSoundFont(state.id, soundFontId: soundFontId)
    }
    return .none
  }

  func updateName(_ state: inout State, value: String) -> Effect<Action> {
    state.newName = value
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
    if store.membership == nil || isEditing {
      nameField
    } else {
      toggleNameField
    }
  }

  private var nameField: some View {
    TextField("", text: $store.newName.sending(\.nameChanged))
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
          TagNameEditorView(store: Store(initialState: .init(
            tag: tag,
            soundFontId: SoundFont.ID(rawValue: 1),
            membership: tag.isUbiquitous ? nil : tag.id.rawValue % 2 == 0
          )) {
            TagNameEditor()
          })
        }
      }
      Form {
        ForEach(tags) { tag in
          TagNameEditorView(store: Store(initialState: .init(tag: tag)) { TagNameEditor() })
        }
      }
    }
  }
}

#Preview {
  TagNameEditorView.preview
}
