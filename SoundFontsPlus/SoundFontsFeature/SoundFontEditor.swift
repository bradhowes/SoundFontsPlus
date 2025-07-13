// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import SharingGRDB
import SwiftUI
import Tagged

@Reducer
public struct SoundFontEditor {

  @Reducer(state: .equatable, action: .equatable)
  public enum Destination {
    case edit(TagsEditor)
  }

  @ObservableState
  public struct State: Equatable {
    let soundFont: SoundFont
    let presetCount: Int
    let favoriteCount: Int
    let hiddenCount: Int

    var tagsList: String
    var displayName: String
    var notes: String

    @Presents var destination: Destination.State?

    public init(soundFont: SoundFont) {
      self.soundFont = soundFont
      self.tagsList = SoundFontsSupport.generateTagsList(from: soundFont.tags)
      self.displayName = soundFont.displayName
      self.notes = soundFont.notes
      (self.presetCount, self.favoriteCount, self.hiddenCount) = soundFont.elementCounts
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

  public enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case cancelButtonTapped
    case changeTagsButtonTapped
    case destination(PresentationAction<Destination.Action>)
    case displayNameChanged(String)
    case notesChanged(String)
    case pathButtonTapped
    case saveButtonTapped
    case unhideAllButtonTapped
    case useEmbeddedNameTapped
    case useOriginalNameTapped
  }

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding: return .none
      case .changeTagsButtonTapped: return editTags(&state)
      case .cancelButtonTapped: return dismiss(&state, save: false)
      case .destination(.dismiss): return updateTagsList(&state)
      case .destination: return .none
      case .displayNameChanged(let value): return updateDisplayName(&state, value: value)
      case .notesChanged(let value): return updateNotes(&state, value: value)
      case .pathButtonTapped: return visitPath(&state)
      case .saveButtonTapped: return dismiss(&state, save: true)
      case .unhideAllButtonTapped: return .none
      case .useEmbeddedNameTapped: return updateDisplayName(&state, value: state.soundFont.embeddedName)
      case .useOriginalNameTapped: return updateDisplayName(&state, value: state.soundFont.originalName)
      }
    }
    .ifLet(\.$destination, action: \.destination)
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
    let tags = FontTag.ordered
    let memberships = tags.reduce(into: [:]) { $0[$1.id] = state.soundFont.tags.contains($1) }
    state.destination = .edit(TagsEditor.State(
      mode: .fontEditing,
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
        Section(header: Text("Author")) {
          Text(store.soundFont.embeddedAuthor)
        }
        Section(header: Text("Copyright")) {
          Text(store.soundFont.embeddedCopyright)
        }
        Section(header: Text("Comment")) {
          Text(store.soundFont.embeddedComment)
        }
        Section(header: Text("Path")) {
          Button {
          } label: {
            Text(store.soundFont.sourcePath)
          }
        }
      }
      .font(.soundFontEditor)
      .navigationTitle("SoundFont")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            store.send(.cancelButtonTapped, animation: .default)
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            store.send(.saveButtonTapped, animation: .default)
          }
        }
      }
    }
    .sheet(item: $store.scope(state: \.destination?.edit, action: \.destination.edit)) { editorStore in
      TagsEditorView(store: editorStore)
    }
  }

  var nameSection: some View {
    Section {
      NameFieldView(text: $store.displayName, readOnly: false)
      HStack {
        Text(store.soundFont.originalName)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
        Button {
          store.send(.useOriginalNameTapped)
        } label: {
          Text("Original")
        }
      }
      HStack {
        Text(store.soundFont.embeddedName)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
        Button("Embedded") { store.send(.useEmbeddedNameTapped) }
      }
    }
  }

  var notesSection: some View {
    Section(header: Text("Notes")) {
      TextEditor(text: $store.notes.sending(\.notesChanged))
        .textEditorStyle(.automatic)
        .lineLimit(1...5)
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
      LabeledContent("Presets", value: "\(store.presetCount + store.hiddenCount)")
      LabeledContent {
        Button {
          store.send(.unhideAllButtonTapped)
        } label: {
          Text("\(store.hiddenCount)")
        }
      } label: {
        Text("Hidden presets")
      }
      LabeledContent("Favorites/Copies", value: "\(store.favoriteCount)")
    }
  }

  var presetCountLabel: String {
    let total = store.presetCount + store.hiddenCount
    if store.hiddenCount > 0 {
      return "\(total) (\(store.hiddenCount) hidden)"
    } else {
      return "\(total)"
    }
  }
}

extension SoundFontEditorView {
  static var preview: some View {
    // swiftlint:disable:next force_try
    var soundFonts = try! prepareDependencies {
      // swiftlint:disable:next force_try
      $0.defaultDatabase = try! appDatabase()
      navigationBarTitleStyle()
      return try $0.defaultDatabase.read { try SoundFont.all.fetchAll($0) }
    }

    soundFonts[0].notes = "This is line 1\nThis is line 2\nThis is line 3\nThis is line 4"
    return SoundFontEditorView(store: Store(initialState: .init(soundFont: soundFonts[0])) { SoundFontEditor() })
  }
}

#Preview {
  SoundFontEditorView.preview
}
