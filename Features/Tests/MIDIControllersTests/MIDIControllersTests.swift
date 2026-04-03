// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import Testing
import TestSupport

@testable import MIDIControllers

@Suite(
//  .dependencies {
//    $0.defaultDatabase = previewDatabase()
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

  @Test
  func preview() async throws {
    withDependencies {
      $0.defaultDatabase = previewDatabase(fonts: [])
    } operation: {
      withSnapshotTesting(record: .failed) {
        TestSupport.assertSnapshot(matching: MIDIControllersView.preview)
      }
    }
  }
}
