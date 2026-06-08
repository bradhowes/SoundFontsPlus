// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import SnapshotTesting
import Testing
import TestSupport

@testable import MIDITrafficIndicator

@Suite
@MainActor
struct MIDITrafficIndicatorTests {

  @Test
  func preview() {
    withDependencies {
      $0.mainQueue = .immediate
    } operation: {
      withSnapshotTesting(record: .failed) {
        let view = MIDITrafficIndicatorView.preview
        TestSupport.assertSnapshot(matching: view)
      }
    }
  }
}
