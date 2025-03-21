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
    let tags: [Tag]

    var path = StackState<SoundFontTagsEditor.State>()
    var tagged: [Tag: Bool]
    var tagsList: String
    var activeTags: [Tag] { tagged.compactMap { $1 ? $0 : nil } }

    public init(soundFont: SoundFont, tags: [Tag]) {
      self.soundFont = soundFont
      self.tags = tags
      self.tagged = tags.reduce(into: [:]) { $0[$1] = soundFont.tags.contains($1) }
      self.tagsList = Support.generateTagsList(from: soundFont.tags)
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
//        let dismiss = dismiss
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
        state.tagging[tag] = true
        state.tagsList = Support.generateTagsList(from: state.activeTags)
        return .none

      case let .path(.element(id: _, action: .delegate(.removeTag(tag)))):
        state.tagging[tag] = false
        state.tagsList = Support.generateTagsList(from: state.activeTags)
        return .none

      case .path:
        return .none

      case .saveButtonTapped:
        save(&state)
        let dismiss = dismiss
        return .run { _ in await dismiss() }

      case .useEmbeddedNameTapped:
        setName(&state, name: state.soundFont.info.embeddedName)
        return .none

      case .useOriginalNameTapped:
        setName(&state, name: state.soundFont.info.originalName)
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

  private func addTag(_ state: inout State, tag: TagModel) {
    state.tagged[tag] = true
    state.tagsList = Support.generateTagsList(from: state.tagging.compactMap { $1 ? $0 : nil })
  }

  private func removeTag(_ state: inout State, tag: TagModel) {
    state.tagged[tag] = false
    state.tagsList = Support.generateTagsList(from: state.tagging.compactMap { $1 ? $0 : nil })
  }

  func editTags(_ state: inout State) {
    state.path.append(.init(tagging: state.tagging))
  }

  private func setName(_ state: inout State, name: String) {
    state.displayName = name
  }

  private func save(_ state: inout State) {
    @Dependency(\.modelContextProvider) var context
    state.soundFont.displayName = state.displayName
    state.soundFont.tags = []
    for (tag, tagState) in state.tagging {
      if tagState {
        state.soundFont.tags.append(tag)
        if !tag.tagged.contains(state.soundFont) {
          tag.tagged.append(state.soundFont)
        }
      } else {
        if tag.tagged.contains(state.soundFont) {
          tag.tagged.removeAll { $0 == state.soundFont }
        }
      }
    }
    NotificationCenter.default.post(name: Notifications.tagsChanged, object: nil)
    do {
      try context.save()
    } catch {
      print("error encountered saving change to sound font - \(error.localizedDescription)")
    }
  }
}

public struct SoundFontEditorView: View {
  @Bindable var store: StoreOf<SoundFontEditor>
  @FocusState var displayNameHasFocus: Bool

  public var body: some View {
    NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
      Form {
        Section(header: Text("Name")) {
          TextField("", text: $store.displayName.sending(\.nameChanged))
            .focused($displayNameHasFocus)
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
            Text(store.soundFont.info.originalName)
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
            Text(store.soundFont.info.embeddedName)
            Spacer()
            Button {
              store.send(.useEmbeddedNameTapped)
            } label: {
              Text("Use")
            }
          }
        }
        Section(header: Text("Author")) {
          Text(store.soundFont.info.embeddedAuthor)
        }
        Section(header: Text("Copyright")) {
          Text(store.soundFont.info.embeddedCopyright)
        }
        Section(header: Text("Comment")) {
          Text(store.soundFont.info.embeddedComment)
        }
        Section(header: Text("Kind")) {
          Text("\(store.soundFont.location.kind)")
        }
        Section(header: Text("Path")) {
          Text(store.soundFont.location.path)
        }
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
