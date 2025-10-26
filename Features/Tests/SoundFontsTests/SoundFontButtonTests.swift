// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import Testing
import TestSupport

@testable import SoundFonts

@Suite(
  .snapshots(record: .failed)
)
@MainActor
struct SoundFontButtonTests {
  @Shared(.activeState) var activeState = .default

  fileprivate func store(kind: SoundFont.Kind) -> TestStoreOf<SoundFontButton> {
    let soundFontInfo = SoundFontInfo(id: 123, displayName: "Testing", kind: kind, location: Data())
    return TestStoreOf<SoundFontButton>(initialState: .init(soundFontInfo: soundFontInfo)) {
      SoundFontButton()
    }
  }

  @Test func buttonTapped() async throws {
    let store = store(kind: .installed)
    #expect(store.state.id == 123)
    await store.send(\.buttonTapped)
    await store.receive(\.delegate.selectSoundFont, store.state.soundFontInfo)
  }

  @Test func deleteButtonTappedOnInstalled() async throws {
    let store = store(kind: .installed)

    await store.send(.deleteButtonTapped) {
      $0.confirmationDialog = SoundFontButton.deleteFromAppConfirmationDialogState(displayName: $0.soundFontInfo.displayName)
    }
    await store.send(.confirmationDialog(.presented(.cancelButtonTapped))) {
      $0.confirmationDialog = nil
    }

    await store.send(.deleteButtonTapped) {
      $0.confirmationDialog = SoundFontButton.deleteFromAppConfirmationDialogState(displayName: $0.soundFontInfo.displayName)
    }
    await store.send(.confirmationDialog(.presented(.deleteButtonTapped))) {
      $0.confirmationDialog = nil
    }
    await store.receive(\.delegate.deleteSoundFont, store.state.soundFontInfo)

    await store.finish()
  }

  @Test func deleteButtonTappedOnExternal() async throws {
    let store = store(kind: .external)

    await store.send(.deleteButtonTapped) {
      $0.confirmationDialog = SoundFontButton.deleteFromDeviceConfirmationDialogState(displayName: $0.soundFontInfo.displayName)
    }
    await store.send(.confirmationDialog(.presented(.cancelButtonTapped))) {
      $0.confirmationDialog = nil
    }

    await store.send(.deleteButtonTapped) {
      $0.confirmationDialog = SoundFontButton.deleteFromDeviceConfirmationDialogState(displayName: $0.soundFontInfo.displayName)
    }
    await store.send(.confirmationDialog(.presented(.deleteButtonTapped))) {
      $0.confirmationDialog = nil
    }
    await store.receive(\.delegate.deleteSoundFont, store.state.soundFontInfo)

    await store.finish()
  }

  @Test func deleteButtonTappedOnBuiltin() async throws {
    let store = store(kind: .builtin)
    // This should never actually happen in the UI, but if it does it should do nothing
    await store.send(.deleteButtonTapped)
    await store.finish()
  }

  @Test func editButtonTapped() async throws {
    let store = store(kind: .builtin)
    await store.send(.editButtonTapped)
    await store.receive(\.delegate.editSoundFont, store.state.soundFontInfo)
    await store.finish()
  }

  @Test func longPressGestureFired() async throws {
    let store = store(kind: .builtin)
    await store.send(.longPressGestureFired)
    await store.receive(\.delegate.editSoundFont, store.state.soundFontInfo)
    await store.finish()
  }

  @Test func preview() async throws {
    try TestSupport.assertSnapshot(matching: SoundFontButtonView.preview)
  }
}
