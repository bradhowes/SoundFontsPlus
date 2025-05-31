// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import SharingGRDB
import SwiftUI
import Tagged

@Reducer
public struct SoundFontEditor {

  public enum Field {
    case displayName
    case notes
  }

  @Reducer(state: .equatable)
  public enum Destination {
    case edit(TagsEditor)
  }

  @ObservableState
  public struct State: Equatable {
    @Presents var destination: Destination.State?
    let soundFont: SoundFont
    var focusField: Field?
    var tagsList: String
    var displayName: String
    var notes: String

    public init(soundFont: SoundFont) {
      self.soundFont = soundFont
      self.tagsList = SoundFontsSupport.generateTagsList(from: soundFont.tags)
      self.displayName = soundFont.displayName
      self.notes = soundFont.notes
    }

    public mutating func save() {
      displayName = displayName.trimmed(or: soundFont.displayName)
      notes = notes.trimmed(or: soundFont.notes)
      @Dependency(\.defaultDatabase) var database
      try? database.write { db in
        try SoundFont.update {
          $0.displayName = displayName
          $0.notes = notes
        }
        .where { $0.id == soundFont.id }
        .execute(db)
      }
    }
  }

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case changeTagsButtonTapped
    case dismissButtonTapped
    case destination(PresentationAction<Destination.Action>)
    case displayNameChanged(String)
    case notesChanged(String)
    case pathButtonTapped
    case useEmbeddedNameTapped
    case useOriginalNameTapped
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .binding: return .none
      case .changeTagsButtonTapped: return editTags(&state)
      case .dismissButtonTapped: return dismiss(&state, save: true)
      case .destination(.dismiss): return updateTagsList(&state)
      case .destination: return .none
      case .displayNameChanged(let value): return updateDisplayName(&state, value: value)
      case .notesChanged(let value): return updateNotes(&state, value: value)
      case .pathButtonTapped: return visitPath(&state)
      case .useEmbeddedNameTapped: return updateDisplayName(&state, value: state.soundFont.embeddedName)
      case .useOriginalNameTapped: return updateDisplayName(&state, value: state.soundFont.originalName)
      }
    }
    .ifLet(\.$destination, action: \.destination)
    BindingReducer()
  }

  public init() {}
}

extension SoundFontEditor {

  private func dismiss(_ state: inout State, save: Bool) -> Effect<Action> {
    if save {
      state.save()
    }

    @Dependency(\.dismiss) var dismiss
    return .run { _ in await dismiss() }
  }

  func editTags(_ state: inout State) -> Effect<Action> {
    let tags = Tag.ordered
    let memberships = tags.reduce(into: [:]) { $0[$1.id] = state.soundFont.tags.contains($1) }
    state.destination = .edit(TagsEditor.State(
      focused: nil,
      soundFontId: state.soundFont.id,
      memberships: memberships
    ))
    return .none
  }

  private func updateTagsList(_ state: inout State) -> Effect<Action> {
    state.tagsList = SoundFontsSupport.generateTagsList(from: state.soundFont.tags)
    return .none
  }

  private func updateDisplayName(_ state: inout State, value: String ) -> Effect<Action> {
    state.displayName = value
    return .none
  }

  private func updateNotes(_ state: inout State, value: String) -> Effect<Action> {
    state.notes = value
    return .none
  }

  private func visitPath(_ state: inout State) -> Effect<Action> {
    // TODO: change to use shareddocuments:// scheme so that Files.app opens path
    @Environment(\.openURL) var openURL
    if let url = URL(string: state.soundFont.sourcePath) {
      openURL(url)
    }
    return .none
  }
}

public struct SoundFontEditorView: View {
  @Bindable private var store: StoreOf<SoundFontEditor>
  @FocusState private var focusField: SoundFontEditor.Field?

  public init(store: StoreOf<SoundFontEditor>) {
    self.store = store
  }

  public var body: some View {
    NavigationStack {
      Form {
        nameSection
        tagsSection
        notesSection
        infoSection
      }
      .navigationTitle("SoundFont Info")
      .toolbar {
        ToolbarItem(placement: .automatic) {
          Button("Dismiss") {
            store.send(.dismissButtonTapped, animation: .default)
          }
        }
      }
      .bind($store.focusField, to: self.$focusField)
    }
    .sheet(item: $store.scope(state: \.destination?.edit, action: \.destination.edit)) { editorStore in
      TagsEditorView(store: editorStore)
    }
  }

  var nameSection: some View {
    Section {
      TextField("Name", text: $store.displayName.sending(\.displayNameChanged))
        .focused($focusField, equals: .displayName)
        .textFieldStyle(.automatic)
      HStack {
        Button {
          store.send(.useOriginalNameTapped)
        } label: {
          Text("Original")
        }
        Spacer()
        Text(store.soundFont.originalName)
          .foregroundStyle(.secondary)
      }
      HStack {
        Button("Embedded") { store.send(.useEmbeddedNameTapped) }
        Spacer()
        Text(store.soundFont.embeddedName)
          .foregroundStyle(.secondary)
      }
    }
  }

  var notesSection: some View {
    Section(header: Text("Notes")) {
      TextEditor(text: $store.notes.sending(\.notesChanged))
    }
  }

  var tagsSection: some View {
    Section(header: Text("Tags")) {
      HStack {
        Text(store.tagsList)
        Spacer()
        Button {
          store.send(.changeTagsButtonTapped)
        } label: {
          Text("Change")
        }
      }
    }
  }

  var infoSection: some View {
    Section(header: Text("Contents")) {
      LabeledContent("Presets", value: "\(store.soundFont.presets.count)")
      LabeledContent("Favorites", value: "None")
      LabeledContent("Author", value: store.soundFont.embeddedAuthor)
      LabeledContent("Copyright", value: store.soundFont.embeddedCopyright)
      LabeledContent("Comment", value: store.soundFont.embeddedComment)
      LabeledContent("Kind", value: store.soundFont.sourceKind)
      LabeledContent {
        Button(store.soundFont.sourcePath) {}
      } label: {
        Text("Path")
      }
    }.font(.footnote)
  }
}

extension SoundFontEditorView {
  static var preview: some View {
    let soundFonts = try! prepareDependencies {
      $0.defaultDatabase = try! appDatabase()
      return try $0.defaultDatabase.read { try SoundFont.all.fetchAll($0) }
    }

    return SoundFontEditorView(store: Store(initialState: .init(soundFont: soundFonts[0])) { SoundFontEditor() })
  }
}

#Preview {
  SoundFontEditorView.preview
}
