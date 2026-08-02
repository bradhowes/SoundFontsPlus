// Copyright © 2025 Brad Howes. All rights reserved.

import BRHSplitView
import DependenciesTestSupport
import FeatureSupport
import MIDITrafficIndicator
import Models
import Settings
import SF2LibAU
import SnapshotTesting
import SoundFonts
import SQLiteData
import Tagged
import Tags
import Testing
import TestSupport
import ToolBar

@testable import Presets
@testable import AUv3Root

@Suite(
  .dependencies {
    $0.continuousClock = TestClock<Duration>()
    $0.date = .constant(.now)
    $0.defaultDatabase = TestSupport.testDatabase()
    $0.fileManager = .liveValue
    $0.mainQueue = .main
    $0.uuid = .incrementing
  },
  .serialized // due to SF2LibAU creation
)
@MainActor
struct AUv3RootTests {

  @Shared(.auv3FontsAndPresetsSplitPosition) var fontsAndPresetsSplitPosition
  @Shared(.auv3FontsAndTagsSplitPosition) var fontsAndTagsSplitPosition
  @Shared(.auv3TagsListVisible) var tagsListVisible = false

  func store() async -> TestStoreOf<AUv3Root> {
    let acd = Bundle.main.audioComponentDescription
    let audioUnit = try! SF2LibAU(componentDescription: acd)
    return .init(initialState: .init(audioUnit: audioUnit)) {
      AUv3Root()
    }
  }

  func initialized(
    exhaustivity: Exhaustivity = .on,
    _ closure: (TestStoreOf<AUv3Root>) async throws -> Void
  ) async throws {
    guard !ProcessInfo.processInfo.isOnGithub else { return }

    let store = await store()

    await store.send(\.initialize)
    await store.receive(\.toolBar.clearTemporaryStatus) { $0.toolBar.temporaryStatus = nil }
    await store.receive(\.fullStateChanged)

    try await store.withExhaustivity(exhaustivity) {
      try await closure(store)
    }

    await store.send(\.deinitialize)
    await store.receive(\.presetsList.deinitialize)
    await store.receive(\.soundFontsList.deinitialize)
    await store.receive(\.tagsList.deinitialize)
    await store.receive(\.toolBar.deinitialize)
    await store.receive(\.toolBar.midiTrafficIndicator.deinitialize)

    await store.finish()
  }

  @Test
  func initialize() async throws {
    try await initialized { _ in }
  }

  @Test
  func processPresetsSplitAction() async throws {
    try await initialized { store in
      #expect(fontsAndPresetsSplitPosition == 0.5)
      await store.send(\.fontsAndPresetsSplit.delegate, .stateChanged(panesVisible: .both, position: 0.3))
      #expect(fontsAndPresetsSplitPosition == 0.3)
    }
  }

  @Test
  func processTagsSplitAction() async throws {
    try await initialized { store in
      #expect(tagsListVisible == false)
      #expect(fontsAndTagsSplitPosition == 0.4)
      await store.send(\.fontsAndTagsSplit.delegate, .stateChanged(panesVisible: .both, position: 0.5)) {
        $0.toolBar.setTagsListVisible(true)
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
        await store.send(\.tagsList.delegate, .edit(focus: 1))
        #expect(store.state.destination != nil)
      }
    }
  }

  @Test
  func showEditPreset() async throws {
    try await initialized { store in
      #expect(store.state.presetsList.sections.isEmpty == false)
      let section = store.state.presetsList.sections.first!
      let preset = Preset.with(id: 1)! // section.rows.first!.preset
      await store.send(
        \.presetsList.delegate,
         .edit(
          sectionId: section.id,
          preset: preset
         )
      ) {
        $0.destination = .presetEditor(
          .init(
            sectionId: section.id,
            preset: preset,
            isActive: false
          )
        )
      }

      await store.send(\.destination.dismiss) {
        $0.destination = nil
      }

      await store.receive(\.presetsList.updateFetchAllQuery)
      await store.receive(\.presetsList, .rowsSourceUpdated(source: [], showActive: false))
    }
  }

  @Test
  func showSettings() async throws {
    try await initialized { store in
      _ = await store.withExhaustivity(.off(showSkippedAssertions: false)) {
        await store.send(\.toolBar.delegate.settingsButtonTapped)
      }
      await store.send(\.destination.dismiss) {
        $0.destination = nil
      }
      await store.receive(\.presetsList.updateFetchAllQuery)
      await store.receive(\.presetsList, .rowsSourceUpdated(source: [], showActive: false))
    }
  }

  @Test
  func editingPresetVisibilityChanged() async throws {
    try await initialized { store in
      await store.send(\.toolBar.delegate.editingPresetVisibilityChanged, true)
      await store.receive(\.presetsList.editingVisibilityChanged, true) { $0.presetsList.editingVisibility = true }
      await store.receive(\.presetsList, .rowsSourceUpdated(source: [], showActive: false))
      await store.send(\.toolBar.delegate.editingPresetVisibilityChanged, false)
      await store.receive(\.presetsList.editingVisibilityChanged, false) { $0.presetsList.editingVisibility = false }
      await store.receive(\.presetsList, .rowsSourceUpdated(source: [], showActive: false))
    }
  }

  @Test
  func presetNameTapped() async throws {
    try await initialized { store in
      await store.send(\.toolBar.delegate.presetNameTapped)
      await store.receive(\.soundFontsList.showActiveSoundFont)
    }
  }

  @Test
  func tagsListVisibilityChanged() async throws {
    try await initialized { store in
      await store.send(\.toolBar.delegate.tagsListVisibilityChanged, true) {
        $0.toolBar.tagsListVisibleToggle()
      }
      await store.receive(\.fontsAndTagsSplit.updatePanesVisibility, .init(rawValue: 3)) {
        $0.fontsAndTagsSplit.panesVisible = .init(rawValue: 3)
      }
      await store.receive(\.fontsAndTagsSplit.delegate, .stateChanged(panesVisible: .init(rawValue: 3), position: 0.4))
      await store.send(\.toolBar.delegate.tagsListVisibilityChanged, false) {
        $0.toolBar.tagsListVisibleToggle()
      }
      await store.receive(\.fontsAndTagsSplit.updatePanesVisibility, .init(rawValue: 1)) {
        $0.fontsAndTagsSplit.panesVisible = .init(rawValue: 1)
      }
      await store.receive(\.fontsAndTagsSplit.delegate, .stateChanged(panesVisible: .init(rawValue: 1), position: 0.4))
    }
  }

  @Test(.snapshots(record: .failed))
  func auv3RootViewPreview() async throws {
    withDependencies {
      $0.mainQueue = .immediate
    } operation: {
      TestSupport.assertSnapshot(matching: AUv3RootView.preview)
    }
  }
}
