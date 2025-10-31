// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import Testing
import TestSupport

@testable import MIDIControllers

@Suite(
//  .dependencies {
//    $0.defaultDatabase = try appDatabase()
//  }
)
@MainActor
struct MIDIControllersTests {

  func store() -> TestStoreOf<MIDIControllers> {
    return TestStoreOf<MIDIControllers>(
      initialState: .init()
    ) {
      MIDIControllers()
    }
  }

  @Test func preview() async throws {
    try withSnapshotTesting(record: .failed) {
      try TestSupport.assertSnapshot(matching: MIDIControllersView.preview)
    }
  }
}
