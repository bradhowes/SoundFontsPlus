import Testing

import ComposableArchitecture
import Dependencies
import SnapshotTesting
import Tagged

@testable import SoundFontsPlus

extension BaseTestSuite {

  @MainActor
  struct SettingsFeatureTests {}
}

extension BaseTestSuite.SettingsFeatureTests {

  func setup() throws -> TestStoreOf<SettingsFeature> {
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    }

    return store
  }

  @Test func settingsViewPreview() async throws {
    try withSnapshotTesting(record: .failed) {
      try BaseTestSuite.assertSnap(
        matching: SettingsView.preview,
        size: .init(width: 400, height: 800),
        colorScheme: .dark
      )
    }
  }
}
