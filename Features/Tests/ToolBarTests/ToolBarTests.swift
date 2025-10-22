// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import Testing
import TestSupport

@testable import ToolBar

@Suite(
  .dependencies {
    $0.defaultDatabase = try appDatabase()
    $0.continuousClock = TestClock()
  },
  .snapshots(record: .failed)
)
@MainActor
struct ToolBarTests {
  @Shared(.activeState) var activeState = .default

  fileprivate func store() -> TestStoreOf<ToolBar> {
    TestStoreOf<ToolBar>(initialState: .init()) {
      ToolBar()
    }
  }

  @Test func initialize() async {
    let store = store()
    await store.send(.initialize)
    await store.send(.deinitialize)
    await store.finish()
  }

  @Test func activeVoiceCountChanged() async {
    let store = store()
    await store.send(.initialize)

    await store.send(.activeVoiceCountChanged(3)) {
      $0.activeVoiceCount = 3
    }

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test func activePresetIdChanged() async {
    @Shared(.activeState) var activeState
    let store = store()
    await store.send(.initialize)

    await store.send(.activePresetIdChanged(2)) {
      $0.preset = .init(
        id: Tagged(rawValue: 2),
        index: 1,
        bank: 0,
        program: 1,
        originalName: "Bright Yamaha Grand",
        soundFontId: Tagged(rawValue: 1),
        displayName: "Bright Yamaha Grand",
        notes: "",
        kind: .preset
      )
    }

    await store.send(.activePresetIdChanged(nil)) {
      $0.preset = nil
    }

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test func editPresetVisibility() async {
    let store = store()
    await store.send(.initialize)

    await store.send(.presetsVisibilityButtonTapped) {
      $0.editingPresetVisibility = true
    }

    await store.receive(\.delegate.editingPresetVisibilityChanged, true)

    await store.send(.presetsVisibilityButtonTapped) {
      $0.editingPresetVisibility = false
    }

    await store.receive(\.delegate.editingPresetVisibilityChanged, false)

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test(arguments: [false, true]) func effectsVisibilityButtonTapped(_ initValue: Bool) async {
    @Shared(.effectsPanelVisible) var effectsPanelVisible = initValue
    let store = store()
    #expect(store.state.effectsPanelVisible == initValue)

    await store.send(.initialize)
    await store.send(.effectsVisibilityButtonTapped) {
      $0.effectsPanelVisible.toggle()
    }

    await store.receive(\.delegate.effectsVisibilityChanged, !initValue)

    await store.send(.showMoreButtonTapped) {
      $0.showMoreButtons.toggle()
    }

    await store.send(.effectsVisibilityButtonTapped) {
      $0.effectsPanelVisible.toggle()
      $0.showMoreButtons = false
    }

    await store.receive(\.delegate.effectsVisibilityChanged, initValue)

    #expect(effectsPanelVisible == initValue)

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test func lastPlayedKeyChangedIgnore() async {
    let store = store()
    await store.send(.initialize)

    await store.send(.lastPlayedKeyChanged(.A6)) {
      $0.lastPlayedKey = .A6
    }

    await store.send(.lastPlayedKeyChanged(nil)) {
      $0.lastPlayedKey = nil
    }

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test func lastPlayedKeyChangedShow() async {
    @Shared(.showKeyNotes) var showKeyNotes
    $showKeyNotes.withLock { $0 = true }

    let store = store()
    await store.send(.initialize)

    await store.send(.lastPlayedKeyChanged(.A6)) {
      $0.lastPlayedKey = .A6
    }

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test func lastPlayedKeyChangedShowSolfege() async {
    @Shared(.showSolfegeTags) var showSolfegeTags
    $showSolfegeTags.withLock { $0 = true }

    let store = store()
    await store.send(.initialize)

    await store.send(.lastPlayedKeyChanged(.A6)) {
      $0.lastPlayedKey = .A6
    }

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test func settingsButtonTapped() async {
    let store = store()
    await store.send(.initialize)

    await store.send(.showMoreButtonTapped) {
      $0.showMoreButtons = true
    }

    await store.send(.settingsButtonTapped) {
      $0.showMoreButtons = false
    }

    await store.receive(\.delegate.settingsButtonTapped)

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test func setVisibleKeyRange() async {
    let store = store()
    await store.send(.initialize)

    await store.send(.setVisibleKeyRange(lowest: .A1, highest: .B3)) {
      $0.lowestKey = .A1
      $0.highestKey = .B3
    }

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test func showMoreButtonTapped() async {
    let store = store()
    await store.send(.initialize)

    await store.send(.showMoreButtonTapped) {
      $0.showMoreButtons = true
    }

    await store.send(.presetsVisibilityButtonTapped) {
      $0.editingPresetVisibility = true
    }

    await store.receive(\.delegate.editingPresetVisibilityChanged, true)

    await store.send(.showMoreButtonTapped) {
      $0.showMoreButtons = false
      $0.editingPresetVisibility = false
    }

    await store.receive(\.delegate.editingPresetVisibilityChanged, false)

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test(arguments: [false, true]) func slidingKeyboardButtonTappedInitFalse(_ initValue: Bool) async {
    @Shared(.keyboardSlides) var keyboardSlides = initValue

    let store = store()
    await store.send(.initialize)
    #expect(store.state.keyboardSlides == initValue)

    await store.send(.slidingKeyboardButtonTapped) {
      $0.keyboardSlides.toggle()
    }

    await store.send(.slidingKeyboardButtonTapped) {
      $0.keyboardSlides.toggle()
    }

    #expect(keyboardSlides == initValue)

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test(arguments: [false, true]) func tagsVisibilityButtonTapped(_ initValue: Bool) async {
    @Shared(.tagsListVisible) var tagsListVisible = initValue

    let store = store()
    await store.send(.initialize)
    #expect(store.state.tagsListVisible == initValue)

    await store.send(.tagsListVisibilityButtonTapped) {
      $0.tagsListVisible.toggle()
    }
    await store.receive(\.delegate.tagsListVisibilityChanged, !initValue)

    await store.send(.tagsListVisibilityButtonTapped) {
      $0.tagsListVisible.toggle()
    }
    await store.receive(\.delegate.tagsListVisibilityChanged, initValue)

    #expect(tagsListVisible == initValue)

    await store.send(.deinitialize)
    await store.finish()
  }

//  @Test func monitorActiveVoiceCount() async throws {
//    let store = store()
//    await store.send(.initialize)
//
//    await store.send(.monitorActiveVoiceCount)
//
//    await store.send(.deinitialize)
//    await store.finish()
//  }

  @Test func preview() async throws {
    @Shared(.activeState) var activeState = .default
    try TestSupport.assertSnapshot(matching: ToolBarView.preview)
  }
}
