// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport
import HelpInfoSpotlightOverlay
import SnapshotTesting
import SwiftUI
import Testing
import TestSupport

@testable import Tags

@Suite()
@MainActor
struct TagsEditorHelpInfoTests {

  @Test(arguments: TagsEditorHelpInfo.allCases)
  func helpInfo(_ candidate: TagsEditorHelpInfo) {
    withSnapshotTesting(record: .failed) {
      TestSupport.assertSnapshot(
        matching: TestView(helpInfoItem: candidate),
        tag: "\(candidate)"
      )
    }
  }
}

struct TestView: View {
  let helpInfoItem: TagsEditorHelpInfo

  var body: some View {
    customHelpInfoOverlay(
      for: helpInfoItem,
      actions: HelpInfoSpotlightOverlayActions(dismiss: {}, previous: {}, next: {}),
      colorScheme: .dark
    )
    .helpInfoViewTag(helpInfoItem)
  }
}
