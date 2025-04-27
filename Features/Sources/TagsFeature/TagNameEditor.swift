import ComposableArchitecture
import Models
import SwiftUI
import Tagged

@Reducer
public struct TagNameEditor {

  @ObservableState
  public struct State: Equatable, Identifiable {
    public let tagId: Tag.ID
    public var name: String
    public let soundFontId: SoundFont.ID?
    public var membership: Bool?
    public var id: Tag.ID { tagId }

    public init(tag: Tag, soundFontId: SoundFont.ID? = nil, membership: Bool? = nil) {
      self.tagId = tag.id
      self.name = tag.name
      self.soundFontId = soundFontId
      self.membership = membership
    }
  }

  public enum Action: Equatable {
    case delegate(Delegate)
    case deleteTag
    case membershipButtonTapped(Bool)
    case nameChanged(String)
  }

  @CasePathable
  public enum Delegate: Equatable {
    case deleteTag(Tag.ID)
  }

  @Dependency(\.defaultDatabase) var database

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .delegate: return .none

      case .deleteTag:
        let tagId = state.tagId
        return .run { send in
          await send(.delegate(.deleteTag(tagId)), animation: .default)
        }

      case .membershipButtonTapped(let value): return membershipChanged(&state, value: value)
      case .nameChanged(let newName): return nameChanged(&state, value: newName)
      }
    }
  }
}

private extension TagNameEditor {

  func membershipChanged(_ state: inout State, value: Bool) -> Effect<Action> {
    guard let soundFontId = state.soundFontId, state.membership != nil else { return .none }
    state.membership = value
    if value {
      _ = Operations.tagSoundFont(state.tagId, soundFontId: soundFontId)
    } else {
      _ = Operations.untagSoundFont(state.tagId, soundFontId: soundFontId)
    }
    return .none
  }

  func nameChanged(_ state: inout State, value: String) -> Effect<Action> {
    state.name = value
    return .none
  }
}

public struct TagNameEditorView: View {
  @Bindable private var store: StoreOf<TagNameEditor>
  @Environment(\.editMode) private var editMode

  private var readOnly: Bool { store.tagId.isUbiquitous }
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
    TextField("", text: $store.name.sending(\.nameChanged))
      .disabled(readOnly || isEditing)
      .deleteDisabled(readOnly)
      .foregroundStyle(editable ? .blue : .secondary)
      .font(Font.custom("Eurostile", size: 20))
      .swipeActions(edge: .trailing) {
        if editable {
          Button {
            store.send(.deleteTag)
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
        .disabled(store.tagId.isUbiquitous)
        .checkedStyle()
      nameField
    }
  }
}

extension TagNameEditorView {

  static var preview: some View {
    let _ = prepareDependencies { $0.defaultDatabase = try! .appDatabase() }
    @Dependency(\.defaultDatabase) var db

    let tags = try! db.write {
      _ = try Tag.make($0, name: "New Tag")
      _ = try Tag.make($0, name: "Another Tag")
      return try Tag.all().fetchAll($0)
    }

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
          TagNameEditorView(store: Store(initialState: .init(
            tag: tag
          )) {
            TagNameEditor()
          })
        }
      }
    }
  }
}

#Preview {
  TagNameEditorView.preview
}
