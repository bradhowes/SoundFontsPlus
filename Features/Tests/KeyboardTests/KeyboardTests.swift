import ComposableArchitecture
import Dependencies
import DependenciesTestSupport
import Models
import Sharing
import SnapshotTesting
import SwiftUI
import Testing

@testable import Keyboard

@Suite(
  .dependencies {
    $0.defaultDatabase = try appDatabase()
  },
  //  .snapshots(record: .failed)
)
@MainActor
struct KeyboardTests {

  private let store: TestStoreOf<Keyboard>

  init() async throws {
    self.store = TestStore(initialState: Keyboard.State()) { Keyboard() }
  }

  @Test
  func keyboardTest() async throws {
    #expect(true)
  }
}
