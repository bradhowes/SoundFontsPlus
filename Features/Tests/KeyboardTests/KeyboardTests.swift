import ComposableArchitecture
import Dependencies
import DependenciesTestSupport
import Foundation
import Sharing
import SnapshotTesting
import SwiftUI
import Testing

@testable import Keyboard

extension BaseTestSuite {

  @MainActor
  struct KeyboardTests {
    private let store: TestStoreOf<Keyboard>

    init() async throws {
      self.store = TestStore(initialState: Keyboard.State()) { Keyboard() }
    }
  }
}

extension BaseTestSuite.KeyboardTests {

  @Test
  func keyboardTest() async throws {
    #expect(true)
  }
}
