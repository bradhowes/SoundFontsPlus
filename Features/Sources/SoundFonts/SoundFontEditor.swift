// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport
import SQLiteData
import Tags

@Reducer
public struct SoundFontEditor {

  @Reducer
  @CasePathable
  public enum Path {
    case editTags(TagsEditor)
  }

  @Reducer
  @CasePathable
  public enum Destination: Equatable {
    case alert(AlertState<Alert>)

    @CasePathable
    public enum Alert {
      case showHiddenPresetsConfirmed
    }
  }

  @ObservableState
  public struct State: Equatable {
    public var path = StackState<Path.State>()
    @Presents public var destination: Destination.State?

    public let soundFont: SoundFont
    public let presetCount: Int
    public let favoriteCount: Int

    public var hiddenCount: Int
    public var tagsList: String
    public var displayName: String
    public var notes: String

    public var memberships: [FontTag.ID: Bool] {
      let tags = FontTag.tags
      return tags.reduce(into: [:]) { $0[$1.id] = soundFont.tags.contains($1) }
    }

    public init(soundFont: SoundFont) {
      self.soundFont = soundFont
      self.tagsList = Self.generateTagsList(from: soundFont.tags)
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

    static public func generateTagsList(from tags: [FontTag]) -> String {
      tags.map(\.displayName).sorted().joined(separator: ", ")
    }
  }

  @CasePathable
  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case cancelButtonTapped
    case changeTagsButtonTapped
    case delegate(Delegate)
    case destination(PresentationAction<Destination.Action>)
    case path(StackActionOf<Path>)
    case saveButtonTapped
    case unhideAllButtonTapped
    case useEmbeddedNameTapped
    case useOriginalNameTapped

    @CasePathable
    public enum Delegate {
      case refreshPresets
    }
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    BindingReducer()

    Reduce { state, action in
      switch action {

      case .cancelButtonTapped:
        return dismiss(&state, save: false)

      case .changeTagsButtonTapped:
        return editTags(&state)

      case .destination(.presented(.alert(.showHiddenPresetsConfirmed))):
        return unhidePresets(&state)

      case .path(.popFrom):
        let tags = state.soundFont.tags
        state.tagsList = State.generateTagsList(from: tags)
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

      default:
        return .none
      }
    }
    .forEach(\.path, action: \.path)
    .ifLet(\.$destination, action: \.destination)
  }
}

extension SoundFontEditor.Path.State: Equatable {}
extension SoundFontEditor.Destination.State: Equatable {}

extension SoundFontEditor {

  private func dismiss(_ state: inout State, save: Bool) -> Effect<Action> {
    if save {
      state.save()
    }
    @Dependency(\.dismiss) var dismiss
    return .run { _ in await dismiss() }
  }

  func editTags(_ state: inout State) -> Effect<Action> {
    state.path.append(
      .editTags(
        TagsEditor.State(
          mode: .fontEditing,
          soundFontId: state.soundFont.id,
          memberships: state.memberships
        )
      )
    )
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
      TextEditor(text: $store.notes)
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
          // ProgressHUD.banner("Copied", "Path copied to clipboard")
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
      $0.defaultDatabase = previewDatabase()
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
