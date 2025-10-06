import ComposableArchitecture
import Dependencies
import SnapshotTesting
import Tagged
import Testing

@testable import Settings

@MainActor
struct SettingsTests {

  func setup() throws -> TestStoreOf<Settings> {
    let store = TestStore(initialState: Settings.State()) {
      Settings()
    }

    return store
  }

  @Test func settingsViewPreview() async throws {
    let view = SettingsView.preview
    try withSnapshotTesting(record: .failed) {
      try assertSnapshot(
        of: view,
        as: .wait(for: 1, on: .image(
          drawHierarchyInKeyWindow: false,
          layout: .fixed(width: 400, height: 800)
        ))
      )
    }
  }
}
