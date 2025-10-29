// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import FeatureSupport
import SnapshotTesting
import Testing
import TestSupport

@testable import FileImporter

@Suite(
//  .dependencies {
//    $0.defaultDatabase = try appDatabase()
//  }
)
@MainActor
struct FileImporterTests {

  func store() -> TestStoreOf<FileImporter> {
    TestStoreOf<FileImporter>(initialState: .init()) {
      FileImporter()
    }
  }

  @Test func firstTest() async {
    _ = store()
  }
}
