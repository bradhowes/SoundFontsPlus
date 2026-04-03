// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import Testing
import TestSupport

@testable import MIDIAssignments

@Suite(
  // .dependencies {
    // $0.defaultDatabase = previewDatabase()
  // }
)
@MainActor
struct MIDIAssignmentsTests {

  func store() -> TestStoreOf<MIDIAssignments> {
    return TestStoreOf<MIDIAssignments>(
      initialState: .init()
    ) {
      MIDIAssignments()
    }
  }

  @Test
  func preview() async throws {
    withDependencies {
      $0.defaultDatabase = previewDatabase()
    } operation: {
      withSnapshotTesting(record: .failed) {
        TestSupport.assertSnapshot(matching: MIDIAssignmentsView.preview)
      }
    }
  }
}
