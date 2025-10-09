import ComposableArchitecture
import CustomSnapshot
import Dependencies
import DependenciesTestSupport
import Models
import SnapshotTesting
import Tagged
import Testing

@testable import SoundFonts

@Suite(
  .dependencies {
    $0.defaultDatabase = try appDatabase()
  },
  .snapshots(record: .failed)
)
@MainActor
struct SoundFontsListTests {

  func setup() throws -> TestStoreOf<SoundFontsList> {
    let store = TestStore(initialState: SoundFontsList.State()) {
      SoundFontsList()
    }

    return store
  }

  @Test func soundFontsListViewPreview() async throws {
    try withSnapshotTesting(record: .failed) {
      try CustomSnapshot.assertSnapshot(matching: SoundFontsListView.preview)
    }
  }
}
