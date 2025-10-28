// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import Testing
import TestSupport

@testable import MIDIConnections

@Suite(
//  .dependencies {
//    $0.defaultDatabase = try appDatabase()
//  }
)
@MainActor
struct MIDIConnectionsTests {

  @Test func preview() async throws {
    try withSnapshotTesting(record: .failed) {
      try TestSupport.assertSnapshot(matching: MIDIConnectionsView.preview)
    }
  }
}
