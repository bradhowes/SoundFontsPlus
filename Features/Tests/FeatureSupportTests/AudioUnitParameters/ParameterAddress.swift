import Foundation
import Models
import SnapshotTesting
import SwiftUI
import Testing

@testable import FeatureSupport

@Suite(
//  .dependencies {
//    $0.defaultDatabase = try appDatabase()
//  },
//  .snapshots(record: .failed)
)
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
