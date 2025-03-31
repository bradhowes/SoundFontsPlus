// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import Models
import SwiftUI
import SwiftUISupport
import TagsFeature
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
    var tags: IdentifiedArrayOf<Tag>
    var focusField: Field?
    var tagged: [Tag.ID: Bool]
    var tagsList: String
    var displayName: String
    var notes: String

    public init(soundFont: SoundFont) {
      let tags = Tag.ordered
      self.soundFont = soundFont
      self.tags = tags
      self.focusField = .displayName
      self.tagged = tags.reduce(into: [:]) { $0[$1.id] = soundFont.tags.contains($1) }
      self.tagsList = Support.generateTagsList(from: soundFont.tags)
      self.displayName = soundFont.displayName
      self.notes = soundFont.notes
    }
  }

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case dismissButtonTapped
    case destination(PresentationAction<Destination.Action>)
    case editTagsButtonTapped
    case nameChanged(String)
    case notesChanged(String)
    case useEmbeddedNameTapped
    case useOriginalNameTapped
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .binding: return .none
      case .dismissButtonTapped: return dismiss()
      case .destination(.dismiss): return refresh(&state)
      case .destination: return .none
      case .editTagsButtonTapped: return editTags(&state)
      case .nameChanged(let value): return setName(&state, value: value)
      case .notesChanged(let value): return setNotes(&state, value: value)
//      case .path(.element(id: _, action: .delegate(.addTag(let tag)))): return addTag(&state, tag: tag)
//      case .path(.element(id: _, action: .delegate(.removeTag(let tag)))): return removeTag(&state, tag: tag)

      // case .path(.showTagsMemberList(.editTagsButtonTapped)): return .none
      // case .path(let pathAction): return monitorPathChange(pathAction, state: &state)
      case .useEmbeddedNameTapped: return setName(&state, value: state.soundFont.embeddedName)
      case .useOriginalNameTapped: return setName(&state, value: state.soundFont.originalName)
      }
    }
    .ifLet(\.$destination, action: \.destination)
    BindingReducer()
  }

  public init() {}
}

extension SoundFontEditor {

//  private func monitorPathChange(_ pathAction: StackActionOf<Path>, state: inout State) -> Effect<Action> {
//    switch pathAction {
//    case .element(id: _, action: .showTagsEditor(.editTagsButtonTapped)):
//      state.path.append(.showTagsEditor(TagsEditor.State(tags: state.tags.map { $0 }, focused: nil)))
//    case .element(id: _, action: .showTagsEditor(_)): break
//    case .popFrom(let id): break
//    default: break
//    }
//    return .none
//  }
//
  private func addTag(_ state: inout State, tag: Tag) -> Effect<Action> {
    state.tagged[tag.id] = true
    state.tagsList = Support.generateTagsList(from: state.tags.filter({ state.tagged[$0.id] ?? false }))
    return .none
  }

  private func dismiss() -> Effect<Action> {
    @Dependency(\.dismiss) var dismiss
    return .run { _ in await dismiss() }
  }

  func editTags(_ state: inout State) -> Effect<Action> {
    state.destination = .edit(TagsEditor.State(
      tags: state.tags,
      focused: nil,
      memberships: state.tagged
    ))
//    state.path.append(.showTagsEditor(TagsEditor.State(
//      tags: tags,
//      focused: nil,
//      memberships: state.tagged
//    ))
    return .none
  }

  private func refresh(_ state: inout State) -> Effect<Action> {
    return .none
  }

  private func removeTag(_ state: inout State, tag: Tag) -> Effect<Action> {
//    state.tagged[tag] = false
//    state.tagsList = Support.generateTagsList(from: state.tags.filter({ state.tagged[$0.id] ?? false }))
    return .none
  }

  private func save(_ state: inout State) -> Effect<Action> {
    @Dependency(\.defaultDatabase) var database
    var soundFont = state.soundFont
    soundFont.displayName = state.displayName
    soundFont.notes = state.notes

    try? database.write {
      try soundFont.save($0)
    }

//    for (tag, tagState) in state.tagged {
//      if tagState {
//        try? soundFont.addTag(tag.id)
//      } else {
//        try? soundFont.removeTag(tag.id)
//      }
//    }

    return dismiss()
  }

  private func setName(_ state: inout State, value: String ) -> Effect<Action> {
    state.displayName = value
    return .none
  }

  private func setNotes(_ state: inout State, value: String) -> Effect<Action> {
    state.notes = value
    return .none
  }
}

public struct SoundFontEditorView: View {
  @Bindable var store: StoreOf<SoundFontEditor>
  @FocusState var focusField: SoundFontEditor.Field?

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
        ToolbarItem(placement: .cancellationAction) {
          Button("Dismiss") {
            store.send(.dismissButtonTapped, animation: .default)
          }
        }
      }
      .bind($store.focusField, to: self.$focusField)
    }
    .sheet(
      item: $store.scope(state: \.destination?.edit, action: \.destination.edit)
    ) { editorStore in
      TagsEditorView(store: editorStore)
    }
  }

  var nameSection: some View {
    Section {
      TextField("Name", text: $store.displayName.sending(\.nameChanged))
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
          store.send(.editTagsButtonTapped)
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
      LabeledContent("Path", value: store.soundFont.sourcePath)
    }
  }
}

extension SoundFontEditorView {
  static var preview: some View {
    let _ = prepareDependencies {
      $0.defaultDatabase = try!.appDatabase()
    }

    @Dependency(\.defaultDatabase) var db
    let soundFonts = try! db.read { try! SoundFont.fetchAll($0) }
    return SoundFontEditorView(store: Store(initialState: .init(soundFont: soundFonts[0])) { SoundFontEditor() })
  }
}

#Preview {
  SoundFontEditorView.preview
}
