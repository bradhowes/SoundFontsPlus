// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import Foundation
import Models
import SnapshotTesting
import SwiftUI
import Testing
import TestSupport

@testable import BaseSupport

@Suite
@MainActor
struct ParameterAddressTests {

  @Test
  func testTreeCreation() {
    let tree = ParameterAddress.createParameterTree()
    #expect(tree.children.count == ParameterAddress.count)
  }

  @Test
  func lookup() async throws {
    let tree = ParameterAddress.createParameterTree()
    #expect(tree[.delayEnabled].displayName == "Enabled")
    #expect(tree[.delayTime].displayName == "Time")
    #expect(tree[.delayFeedback].displayName == "Feedback")
    #expect(tree[.delayCutoff].displayName == "Cutoff")
    #expect(tree[.delayAmount].displayName == "Amount")
    #expect(tree[.reverbEnabled].displayName == "Enabled")
    #expect(tree[.reverbRoomIndex].displayName == "Room")
    #expect(tree[.reverbAmount].displayName == "Amount")
  }
}
