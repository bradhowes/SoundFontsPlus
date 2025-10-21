// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import Testing
import TestSupport

@testable import ToolBar

@Suite(
  .dependencies {
    $0.defaultDatabase = try appDatabase()
  },
  .snapshots(record: .failed)
)
@MainActor
struct ToolBarTests {
  @Shared(.activeState) var activeState = .default

  fileprivate func store() -> TestStoreOf<ToolBar> {
    TestStoreOf<ToolBar>(initialState: .init()) {
      ToolBar()
    }
  }

  @Test func initialize() async throws {
    let store = store()
    await store.send(.initialize)
    await store.send(.deinitialize)
    await store.finish()
  }

//  @Test func monitorActiveVoiceCount() async throws {
//    let store = store()
//    await store.send(.initialize)
//
//    await store.send(.monitorActiveVoiceCount)
//
//    await store.send(.deinitialize)
//    await store.finish()
//  }

  @Test func preview() async throws {
    @Shared(.activeState) var activeState = .default
    try TestSupport.assertSnapshot(matching: ToolBarView.preview)
  }
}
