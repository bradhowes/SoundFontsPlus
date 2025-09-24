// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import ProgressHUD
import SQLiteData
import SwiftUI
import Tagged

@Reducer
public struct SoundFontEditor {

  @Reducer(state: .equatable)
  public enum Path {
    case editTags(TagsEditor)
  }

  @Reducer(state: .equatable)
  public enum Destination: Equatable {
    case alert(AlertState<Alert>)

    @CasePathable
    public enum Alert {
      case showHiddenPresetsConfirmed
    }
  }

  @ObservableState
  public struct State: Equatable {
    var path = StackState<Path.State>()
    @Presents var destination: Destination.State?

    let soundFont: SoundFont
    let presetCount: Int
    let favoriteCount: Int

    var hiddenCount: Int
    var tagsList: String
    var displayName: String
    var notes: String

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

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case cancelButtonTapped
    case changeTagsButtonTapped
    case delegate(Delegate)
    case destination(PresentationAction<Destination.Action>)
    case displayNameChanged(String)
    case notesChanged(String)
    case path(StackActionOf<Path>)
    case saveButtonTapped
    case unhideAllButtonTapped
    case useEmbeddedNameTapped
    case useOriginalNameTapped

    public enum Delegate {
      case refreshPresets
    }
  }

  public var body: some ReducerOf<Self> {
    BindingReducer()

    Reduce { state, action in
      switch action {

      case .binding:
        return .none

      case .cancelButtonTapped:
        return dismiss(&state, save: false)

      case .changeTagsButtonTapped:
        return editTags(&state)

      case .delegate:
        return .none

      case .destination(.presented(.alert(.showHiddenPresetsConfirmed))):
        return unhidePresets(&state)

      case .destination(.dismiss):
        state.tagsList = SoundFontsSupport.generateTagsList(from: state.soundFont.tags)
        return .none

      case .destination:
        return .none

      case .displayNameChanged(let value):
        state.displayName = value
        return .none

      case .notesChanged(let value):
        state.notes = value
        return .none

      case .path:
        return .none

      case .saveButtonTapped:
        return dismiss(&state, save: true)

      case .unhideAllButtonTapped:
        state.destination = .alert(.confirmShowHiddenPresets(action: .showHiddenPresetsConfirmed))
        return .none

      case .useEmbeddedNameTapped:
        state.displayName = state.soundFont.embeddedName
        return .none

      case .useOriginalNameTapped:
        state.displayName = state.soundFont.originalName
        return .none

      }
    }
    .forEach(\.path, action: \.path)
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
    let tags = FontTag.tags
    let memberships = tags.reduce(into: [:]) { $0[$1.id] = state.soundFont.tags.contains($1) }
    state.path.append(.editTags(TagsEditor.State(
      mode: .fontEditing,
      focused: nil,
      soundFontId: state.soundFont.id,
      memberships: memberships
    )))
    return .none
  }

  func unhidePresets(_ state: inout State) -> Effect<Action> {
    withDatabaseWriter { db in
      try Preset.update {
        $0.kind = .preset
      }
      .where { $0.kind.eq(Preset.Kind.hidden) && $0.soundFontId.eq(state.soundFont.id) }
      .execute(db)
    }

    state.hiddenCount = 0
    return .send(.delegate(.refreshPresets))
  }
}

public struct SoundFontEditorView: View {
  @Bindable private var store: StoreOf<SoundFontEditor>
  @Environment(\.openURL) var openURL

  public init(store: StoreOf<SoundFontEditor>) {
    self.store = store
  }

  public var body: some View {
    NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
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
        pathSection
      }
      .font(.soundFontEditor)
      .navigationTitle("SoundFont")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            store.send(.cancelButtonTapped, animation: .default)
          }
          .font(.button)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            store.send(.saveButtonTapped, animation: .default)
          }
          .font(.button)
        }
      }
    } destination: { store in
      switch store.case {
      case .editTags(let store): TagsEditorView(store: store)
      }
    }
    .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
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

  var pathSection: some View {
    Section(header: Text("Path")) {
      HStack {
        Text(store.soundFont.sourcePath)
          .font(.footnote)
        Button {
          UIPasteboard.general.string = store.soundFont.sourcePath
          ProgressHUD.banner("Copied", "Path copied to clipboard")
        } label: {
          Image(systemName: "document.on.document")
        }
      }
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
