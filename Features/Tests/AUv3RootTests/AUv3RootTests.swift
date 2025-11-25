// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import Models
import Settings
import SnapshotTesting
import SoundFonts
import Testing
import TestSupport

@testable import Presets
@testable import AUv3Root

@Suite(
  .dependencies {
    $0.date = .constant(.now)
    $0.defaultDatabase = TestSupport.testDatabase()
    $0.mainQueue = .immediate
    $0.synthAUv3ComponentDescription = SynthAUv3ComponentDescription.testValue
  },
  .snapshots(record: .failed)
)
@MainActor
struct AUv3RootTests {

  func store() -> TestStoreOf<AUv3Root> {
    @Shared(.activeState) var activeState = .default
    return .init(initialState: .init()) {
      AUv3Root()
    }
  }

  func initialized(_ test: (TestStoreOf<AUv3Root>) async throws -> Void) async throws {
    let store = store()

    await store.send(.initialize)

    await store.receive(\.activePresetIdChanged) {
      $0.toolBar.preset = Preset(
        id: 1,
        index: 0,
        bank: 0,
        program: 0,
        originalName: "Original Preset 1",
        soundFontId: 1,
        displayName: "Font 1 Preset 1"
      )
    }

    try await test(store)

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func initialize() async throws {
    let store = store()

    await store.send(.initialize)

    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func processPresetsSplitAction() async throws {
    try await initialized { store in
      @Shared(.fontsAndPresetsSplitPosition) var fontsAndPresetsSplitPosition
      #expect(fontsAndPresetsSplitPosition == 0.5)
      await store.send(\.fontsAndPresetsSplit.delegate, .stateChanged(panesVisible: .both, position: 0.3))
      #expect(fontsAndPresetsSplitPosition == 0.3)
    }
  }

  @Test
  func processTagsSplitAction() async throws {
    try await initialized { store in
      @Shared(.tagsListVisible) var tagsListVisible
      @Shared(.fontsAndTagsSplitPosition) var fontsAndTagsSplitPosition
      #expect(tagsListVisible == false)
      #expect(fontsAndTagsSplitPosition == 0.4)
      await store.send(\.fontsAndTagsSplit.delegate, .stateChanged(panesVisible: .both, position: 0.5)) {
        $0.toolBar.tagsListVisible.toggle()
      }
      #expect(tagsListVisible == true)
      #expect(fontsAndTagsSplitPosition == 0.5)
    }
  }

  @Test
  func refreshPresets() async throws {
    try await initialized { store in
      let soundFont = SoundFont.with(id: 1)!
      await store.send(\.soundFontsList.delegate, .edit(soundFont)) {
        $0.destination = .soundFontEditor(SoundFontEditor.State(soundFont: soundFont))
      }
      _ = await store.withExhaustivity(.off(showSkippedAssertions: false)) {
        await store.send(\.destination.presented.soundFontEditor.delegate, .refreshPresets)
      }
    }
  }

  @Test
  func showChanges() async throws {
    try await initialized { store in
      @Shared(.lastShowedChangesVersion) var lastShowedChangesVersion
      _ = await store.withExhaustivity(.off(showSkippedAssertions: false)) {
        await store.send(\.toolBar.delegate, .settingsButtonTapped)
        #expect(store.state.destination != nil)
        let settings = store.state.destination
        #expect(lastShowedChangesVersion == "")
        await store.send(\.destination.settings.delegate, .showChanges)
        #expect(store.state.destination != settings)
        #expect(lastShowedChangesVersion != "")
      }
    }
  }

//  @Test func showPresetEditor() async throws {
//    try await initialized { store in
//      await store.send(\.presetsList, .fetchPresets)
//      let preset = Preset.with(id: 1)
//      await store.send(\.presetsList.sections, .element(id: 10000, action: .rows(.element(id: 1, action: .delegate(.editPreset(preset!))))))
//      #expect(store.state.destination != nil)
//    }
//  }

  @Test
  func showSoundFontEditor() async throws {
    try await initialized { store in
      let soundFont = SoundFont.with(id: 1)!
      await store.send(\.soundFontsList.delegate, .edit(soundFont)) {
        $0.destination = .soundFontEditor(SoundFontEditor.State(soundFont: soundFont))
      }
    }
  }

  @Test
  func showTagsEditor() async throws {
    try await initialized { store in
      _ = await store.withExhaustivity(.off(showSkippedAssertions: false)) {
        await store.send(\.tagsList.delegate, .edit(1))
        #expect(store.state.destination != nil)
      }
    }
  }

  @Test
  func auv3RootViewPreview() async throws {
    try TestSupport.assertSnapshot(matching: AUv3RootView.preview)
  }
}
