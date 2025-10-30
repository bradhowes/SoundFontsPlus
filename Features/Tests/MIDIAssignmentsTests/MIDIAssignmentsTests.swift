// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import Testing
import TestSupport

@testable import MIDIAssignments

@Suite(
  .dependencies {
    $0.defaultDatabase = try appDatabase()
  }
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

  @Test func preview() async throws {
    try withSnapshotTesting(record: .failed) {
      try TestSupport.assertSnapshot(matching: MIDIAssignmentsView.preview)
    }
  }
}
