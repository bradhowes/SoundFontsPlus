// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import Models
import SwiftUI
import SwiftUISupport
import Tagged

@Reducer
public struct SoundFontEditor {

  @ObservableState
  public struct State: Equatable {
    let soundFont: SoundFont
    var tags: [Tag]

    var path = StackState<SoundFontTagsEditor.State>()
    var tagged: [Tag: Bool]
    var tagsList: String
    var activeTags: [Tag] { tagged.compactMap { $1 ? $0 : nil } }
    var displayName: String
    var notes: String

    public init(soundFont: SoundFont, tags: [Tag]) {
      self.soundFont = soundFont
      self.tags = tags
      self.tagged = tags.reduce(into: [:]) { $0[$1] = soundFont.tags.contains($1) }
      self.tagsList = Support.generateTagsList(from: soundFont.tags)
      self.displayName = soundFont.displayName
      self.notes = soundFont.notes
    }
  }

  public enum Action {
    case cancelButtonTapped
    case editTagsButtonTapped
    case nameChanged(String)
    case path(StackActionOf<SoundFontTagsEditor>)
    case saveButtonTapped
    case useEmbeddedNameTapped
    case useOriginalNameTapped
  }

  @Dependency(\.dismiss) var dismiss

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {

      case .cancelButtonTapped:
        let dismiss = dismiss
        return .run { _ in await dismiss() }

      case .editTagsButtonTapped:
        editTags(&state)
        return .none

      case .nameChanged(let name):
        if name != state.displayName {
          setName(&state, name: name)
        }
        return .none

      case let .path(.element(id: _, action: .delegate(.addTag(tag)))):
        addTag(&state, tag: tag)
        state.tagged[tag] = true
        state.tagsList = Support.generateTagsList(from: state.activeTags)
        return .none

      case let .path(.element(id: _, action: .delegate(.removeTag(tag)))):
        state.tagged[tag] = false
        state.tagsList = Support.generateTagsList(from: state.activeTags)
        return .none

      case .path:
        return .none

      case .saveButtonTapped:
        save(&state)
        let dismiss = dismiss
        return .run { _ in await dismiss() }

      case .useEmbeddedNameTapped:
        setName(&state, name: state.soundFont.embeddedName)
        return .none

      case .useOriginalNameTapped:
        setName(&state, name: state.soundFont.originalName)
        return .none
      }
    }
    .forEach(\.path, action: \.path) {
      SoundFontTagsEditor()
    }
  }

  public init() {}
}

extension SoundFontEditor {

  private func addTag(_ state: inout State, tag: Tag) {
    state.tagged[tag] = true
    state.tagsList = Support.generateTagsList(from: state.tagged.compactMap { $1 ? $0 : nil })
  }

  private func removeTag(_ state: inout State, tag: Tag) {
    state.tagged[tag] = false
    state.tagsList = Support.generateTagsList(from: state.tagged.compactMap { $1 ? $0 : nil })
  }

  func editTags(_ state: inout State) {
    // state.path.append(.init(tagged: state.tagged))
  }

  private func setName(_ state: inout State, name: String) {
    state.displayName = name
  }

  private func save(_ state: inout State) {
    @Dependency(\.defaultDatabase) var database
    var soundFont = state.soundFont
    soundFont.displayName = state.displayName
    soundFont.notes = state.notes

    try? database.write {
      try soundFont.save($0)
    }

    for (tag, tagState) in state.tagged {
      if tagState {
        try? soundFont.addTag(tag.id)
      } else {
        try? soundFont.removeTag(tag.id)
      }
    }
  }
}

public struct SoundFontEditorView: View {
  @Bindable var store: StoreOf<SoundFontEditor>

  public var body: some View {
    NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
      Form {
        Section(header: Text("Name")) {
          TextField("", text: $store.displayName.sending(\.nameChanged))
            .textFieldStyle(.roundedBorder)
        }
        Section(header: Text("Tags")) {
          HStack {
            Text(store.tagsList)
            Spacer()
            Button {
              store.send(.editTagsButtonTapped)
            } label: {
              Text("Edit")
            }
          }
        }
        Section(header: Text("Contents")) {
          Text("\(store.soundFont.presets.count) presets")
          Text("no favorites")
        }
        Section(header: Text("Original Name")) {
          HStack {
            Text(store.soundFont.originalName)
            Spacer()
            Button {
              store.send(.useOriginalNameTapped)
            } label: {
              Text("Use")
            }
          }
        }
        Section(header: Text("Embedded Name")) {
          HStack {
            Text(store.soundFont.embeddedName)
            Spacer()
            Button {
              store.send(.useEmbeddedNameTapped)
            } label: {
              Text("Use")
            }
          }
        }
//        Section(header: Text("Author")) {
//          Text(store.soundFont.embeddedAuthor)
//        }
//        Section(header: Text("Copyright")) {
//          Text(store.soundFont.embeddedCopyright)
//        }
//        Section(header: Text("Comment")) {
//          Text(store.soundFont.embeddedComment)
//        }
//        Section(header: Text("Kind")) {
//          Text("\(store.soundFont.location.kind)")
//        }
//        Section(header: Text("Path")) {
//          Text(store.soundFont.location.path)
//        }
      }
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
    } destination: { store in
      SoundFontTagsEditorView(store: store)
    }
  }
}
