// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import Models
import Settings
import SF2LibAU
import SnapshotTesting
import SoundFonts
import Testing
import TestSupport

@testable import Presets
@testable import AUv3Root

#if false

@Suite(
  .dependencies {
    $0.date = .constant(.now)
    $0.defaultDatabase = TestSupport.testDatabase()
    $0.mainQueue = .immediate
  },
  .snapshots(record: .failed)
)
@MainActor
struct AUv3RootTests {

  func store() async throws -> TestStoreOf<AUv3Root> {
    @Shared(.activeState) var activeState = .default
    let audioUnit = try await SF2LibAU.create()
    return .init(initialState: .init(audioUnit: audioUnit.auAudioUnit as! SF2LibAU)) {
      AUv3Root()
    }
  }

  func initialized(_ test: (TestStoreOf<AUv3Root>) async throws -> Void) async throws {
    let store = try await store()

    await store.send(.initialize)
    try await test(store)
    await store.send(.deinitialize)
    await store.finish()
  }

  @Test
  func initialize() async throws {
    try await initialized { _ in }
  }

  @Test
  func processPresetsSplitAction() async throws {
    try await initialized { store in
      await store.send(\.fontsAndPresetsSplit.delegate, .stateChanged(panesVisible: .both, position: 0.3))
    }
  }

  @Test
  func processTagsSplitAction() async throws {
    try await initialized { store in
      await store.send(\.fontsAndTagsSplit.delegate, .stateChanged(panesVisible: .both, position: 0.5)) {
        $0.toolBar.tagsListVisible.toggle()
      }
      #expect(store.state.toolBar.tagsListVisible == true)
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

#endif
