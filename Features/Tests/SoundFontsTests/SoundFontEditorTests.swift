// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import Testing
import TestSupport

@testable import SoundFonts

@Suite(
  .dependencies {
    $0.defaultDatabase = try appDatabase()
  },
  //  .snapshots(record: .failed)
)
@MainActor
struct SoundFontEditorTests {

  func setup() throws -> TestStoreOf<SoundFontEditor> {
    let soundFont = SoundFont.with(id: 1)!
    let store = TestStore(initialState: SoundFontEditor.State(soundFont: soundFont)) {
      SoundFontEditor()
    }

    return store
  }

  @Test func soundFontEditorViewPreview() async throws {
    try withSnapshotTesting(record: .failed) {
      try TestSupport.assertSnapshot(matching: SoundFontEditorView.preview)
    }
  }
}
