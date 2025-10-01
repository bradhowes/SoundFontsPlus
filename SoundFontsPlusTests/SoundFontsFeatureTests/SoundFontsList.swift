import Testing

import ComposableArchitecture
import Dependencies
import SnapshotTesting
import Tagged

@testable import SoundFontsPlus

extension BaseTestSuite {

  @MainActor
  struct SoundFontsListTests {}
}

extension BaseTestSuite.SoundFontsListTests {

  func setup() throws -> TestStoreOf<SoundFontsList> {
    let store = TestStore(initialState: SoundFontsList.State()) {
      SoundFontsList()
    }

    return store
  }

  @Test func soundFontsListViewPreview() async throws {
    try withSnapshotTesting(record: .failed) {
      try BaseTestSuite.assertSnap(
        matching: SoundFontsListView.preview,
        size: .init(width: 400, height: 800),
        colorScheme: .dark
      )
    }
  }
}
