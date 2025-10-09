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
      try CustomSnapshot.assertSnapshot(matching: SoundFontEditorView.preview)
    }
  }
}
