import Testing

import ComposableArchitecture
import Dependencies
import GRDB
import Models
import SF2ResourceFiles
import SnapshotTesting
import SwiftUI
import Tagged
@testable import TagsFeature

@MainActor
struct TagButtonTests {

  func initialize(_ body: (TestStoreOf<TagButton>) async throws -> Void) async throws {
    try await TestSupport.initialize { tags in
      @Dependency(\.defaultDatabase) var database
      try await body(TestStore(initialState: TagButton.State(tagInfo: TagInfo.from(tags[0]))) { TagButton() })
    }
  }

  @Test func testButtonTapped() async throws {
    try await initialize { store in
      @Dependency(\.defaultDatabase) var database
      @Shared(.activeState) var activeState
      $activeState.withLock { $0.activeTagId = Tag.Ubiquitous.builtIn.id }

      await store.send(\.buttonTapped)
      #expect(activeState.activeTagId == Tag.Ubiquitous.all.id)

    }
  }

  @Test func testDeleteButtonTapped() async throws {
    try await initialize { store in
      await store.send(\.deleteButtonTapped) {
        $0.confirmationDialog = TagButton.deleteConfirmationDialogState(displayName: store.state.tagInfo.name)
      }
      await store.send(\.confirmationDialog.deleteButtonTapped) {
        $0.confirmationDialog = nil
      }
      await store.receive(.delegate(.deleteTag(store.state.tagInfo)))

      await store.send(\.deleteButtonTapped) {
        $0.confirmationDialog = TagButton.deleteConfirmationDialogState(displayName: store.state.tagInfo.name)
      }
      await store.send(\.confirmationDialog.cancelButtonTapped) {
        $0.confirmationDialog = nil
      }
    }
  }

  @Test func testLongPressGesture() async throws {
    try await initialize { store in
      await store.send(\.longPressGestureFired)
      await store.receive(.delegate(.editTags))
    }
  }

  @Test func tagButtonPreview() async throws {
    withSnapshotTesting(record: .failed) {
      struct HostView: SwiftUI.View {
        var body: some SwiftUI.View {
          TagButtonView.preview
            .environment(\.editMode, .constant(.inactive))
        }
      }
      let view = HostView()
      assertSnapshot(of: view, as: .image(layout: .device(config: .iPhoneSe), traits: .init(userInterfaceStyle: .dark)))
    }
  }
}
