import Testing

import ComposableArchitecture
import Dependencies
import SnapshotTesting
import Tagged

@testable import SoundFontsPlus

extension BaseTestSuite {

  @MainActor
  struct SoundFontEditorTests {}
}

extension BaseTestSuite.SoundFontEditorTests {

  func setup() throws -> TestStoreOf<SoundFontEditor> {
    let soundFont = SoundFont.with(id: 1)!
    let store = TestStore(initialState: SoundFontEditor.State(soundFont: soundFont)) {
      SoundFontEditor()
    }

    return store
  }

  @Test func soundFontEditorViewPreview() async throws {
    try withSnapshotTesting(record: .failed) {
      try BaseTestSuite.assertSnap(
        matching: SoundFontEditorView.preview,
        size: .init(width: 400, height: 800),
        colorScheme: .dark
      )
    }
  }
}
