// Copyright © 2025 Brad Howes. All rights reserved.
#if false

import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import Testing
import TestSupport

@testable import MuteSwitchMonitor

@Suite
@MainActor
struct MuteSwitchMonitorTests {
  private let store: TestStoreOf<MuteSwitchMonitor>

  init() async throws {
    let store = TestStore(initialState: VolumeMonitor.State()) {
      VolumeMonitor()
    }
    self.store = store
  }
}

#endif // false
