import ComposableArchitecture
import Dependencies
import SnapshotTesting
import SwiftUI
import Tagged
import Testing

@testable import SoundFonts2

@MainActor
struct TagsListTests {
  func initialize(_ body: (TestStoreOf<TagsList>) async throws -> Void) async throws {
    try await withDependencies {
      $0.defaultDatabase = try appDatabase()
    } operation: {
      let newTag = try Tag.make(displayName: "New Tag")
      @Shared(.activeState) var activeState
      $activeState.withLock {
        $0.activeTagId = Tag.Ubiquitous.all.id
      }
      try await body(TestStore(initialState: TagsList.State()) {
        TagsList()
      })
    }
  }

  @Test func creation() async throws {
    try await initialize { store in
      #expect(store.state.rows.count == 4)
      await store.send(.onAppear)
      await store.finish()
    }
  }

  @Test func addButtonTapped() async throws {
    try await initialize { store in
      #expect(store.state.rows.count == 4)
      await store.send(.addButtonTapped) {
        let tags = Operations.orderedTags
        $0.rows.append(TagButton.State(tagInfo: .init(tag: tags[4])))
      }
      await store.finish()
    }
  }

  @Test func rowEditButtonTapped() async throws {
    try await initialize { store in
      #expect(store.state.rows.count == 4)
      await store.send(.rows(.element(id:1, action: .delegate(.editTags)))) {
        $0.destination = .edit(TagsEditor.State(focused: nil))
      }

      await store.send(.destination(.dismiss)) {
        $0.destination = nil
      }

      await store.finish()
    }
  }

  @Test func rowDeleteButtonTapped() async throws {
    try await initialize { store in
      #expect(store.state.rows.count == 5)
      await store.send(.rows(.element(id:1, action: .delegate(.deleteTag(store.state.rows[4].tagInfo)))))
      await store.receive(\.fetchTags) {
        $0.rows.remove(at: 4)
      }
      await store.finish()
    }
  }

  @Test func activeRowDeleteButtonTapped() async throws {
    try await initialize { store in
      #expect(store.state.rows.count == 4)
      @Shared(.activeState) var activeState

      await store.send(.addButtonTapped) {
        let tags = Operations.orderedTags
        $0.rows.append(TagButton.State(tagInfo: .init(tag: tags[4])))
      }
      #expect(store.state.rows.count == 5)

      await store.send(.rows(.element(id: 5, action: .buttonTapped)))
      #expect(activeState.activeTagId == 5)

      await store.send(.rows(.element(id:1, action: .delegate(.deleteTag(store.state.rows[4].tagInfo)))))
      await store.receive(\.fetchTags) {
        $0.rows.remove(at: 4)
      }

      #expect(activeState.activeTagId == Tag.Ubiquitous.all.id)

      await store.finish()
    }
  }

  @Test func editorAddButtonTapped() async throws {
    try await initialize { store in
      #expect(store.state.rows.count == 4)

      await store.send(.rows(.element(id:1, action: .delegate(.editTags)))) {
        $0.destination = .edit(TagsEditor.State(focused: nil))
      }

      store.exhaustivity = .off
      await store.send(.destination(.presented(.edit(.addButtonTapped)))) {
        let tags = Operations.orderedTags
        $0.rows.append(TagButton.State(tagInfo: .init(tag: tags[4])))
      }
      store.exhaustivity = .on

      await store.finish()
    }
  }

  @Test func editorDeleteButtonTapped() async throws {
    try await initialize { store in
      #expect(store.state.rows.count == 4)

      await store.send(.rows(.element(id:1, action: .delegate(.editTags)))) {
        $0.destination = .edit(TagsEditor.State(focused: nil))
      }

      await store.send(.destination(.presented(.edit(.addButtonTapped)))) {
        let tags = Operations.orderedTags
        $0.rows.append(TagButton.State(tagInfo: .init(tag: tags[4])))
        $0.destination = .edit(TagsEditor.State(focused: Tag.ID(rawValue: 5)))
      }

      store.exhaustivity = .on
      await store.send(.destination(.presented(.edit(.finalizeDeleteTag(.init(integer: 5)))))) {
        $0.rows.remove(id: 5)
        $0.destination = .edit(TagsEditor.State(focused: Tag.ID(rawValue: 5)))
      }

      let tag = Operations.tag(5)
      #expect(tag == nil)

      await store.finish()
    }
  }

  @Test func tagsListViewPreview() async throws {
    withSnapshotTesting(record: .failed) {
      struct HostView: SwiftUI.View {
        var body: some SwiftUI.View {
          TagsListView.preview
            .environment(\.editMode, .constant(.inactive))
        }
      }
      let view = HostView()
      assertSnapshot(of: view, as: .image(layout: .device(config: .iPhoneSe), traits: .init(userInterfaceStyle: .dark)))
    }
  }

  @Test func tagsListWithEditorPreview() async throws {
    withSnapshotTesting(record: .failed) {
      struct HostView: SwiftUI.View {
        var body: some SwiftUI.View {
          TagsListView.previewWithEditor
            .environment(\.editMode, .constant(.inactive))
        }
      }
      let view = HostView()
      assertSnapshot(of: view, as: .image(layout: .device(config: .iPhoneSe), traits: .init(userInterfaceStyle: .dark)))
    }
  }
}

