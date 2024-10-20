// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftUI
import Models
import Tagged

@Reducer
public struct SoundFontEditor {

  @ObservableState
  public struct State: Equatable {
    var path = StackState<SoundFontTagsEditor.State>()
    var soundFont: SoundFontModel
    var displayName: String
    var tagsList: String

    public init(soundFont: SoundFontModel) {
      self.soundFont = soundFont
      self.displayName = soundFont.displayName
      self.tagsList = Support.generateTagsList(from: soundFont)
    }
  }

  public enum Action {
    case dismissButtonTapped
    case editTagsButtonTapped
    case nameChanged(String)
    case path(StackActionOf<SoundFontTagsEditor>)
    case useEmbeddedNameTapped
    case useOriginalNameTapped
  }

  @Dependency(\.dismiss) var dismiss

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {

      case .dismissButtonTapped:
        let dismiss = dismiss
        save(&state)
        return .run { _ in await dismiss() }

      case .editTagsButtonTapped:
        state.path.append(.init(soundFont: state.soundFont))
        return .none

      case .nameChanged(let name):
        if name != state.displayName {
          // setName(&state, name: name)
        }
        return .none

      case .path(.element(id: _, action:.delegate(.updateTags))):
        updateTags(&state)
        return .none

      case .path:
        return .none

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

  private func setName(_ state: inout State, name: String) {
    state.displayName = name
  }

  private func save(_ state: inout State) {
    @Dependency(\.modelContextProvider) var context
    state.soundFont.displayName = state.displayName
    do {
      try context.save()
    } catch {
      print("error encountered saving change to sound font - \(error.localizedDescription)")
    }
  }

  private func updateTags(_ state: inout State) {
    state.tagsList = Support.generateTagsList(from: state.soundFont)
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
          Button("Done") {
            store.send(.dismissButtonTapped, animation: .default)
          }
        }
      }
    } destination: { store in
      SoundFontTagsEditorView(store: store)
    }
  }
}
