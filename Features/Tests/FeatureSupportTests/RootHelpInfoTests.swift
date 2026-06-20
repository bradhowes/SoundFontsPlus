// Copyright © 2025 Brad Howes. All rights reserved.

import HelpInfoSpotlightOverlay
import SnapshotTesting
import SwiftUI
import Testing
import TestSupport

@testable import FeatureSupport

@Suite()
@MainActor
struct RootHelpInfoTests {

  @Test(arguments: RootHelpInfo.allCases)
  func helpInfo(_ candidate: RootHelpInfo) {
    withSnapshotTesting(record: .failed) {
      TestSupport.assertSnapshot(
        matching: TestView(helpInfoItem: candidate),
        tag: "\(candidate)"
      )
    }
  }
}

struct TestView: View {
  let helpInfoItem: RootHelpInfo

  var body: some View {
    customHelpInfoOverlay(
      for: helpInfoItem,
      actions: HelpInfoSpotlightOverlayActions(dismiss: {}, previous: {}, next: {}),
      colorScheme: .dark
    )
    .helpInfoViewTag(helpInfoItem)
  }
}
