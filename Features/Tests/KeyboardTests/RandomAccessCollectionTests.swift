// Copyright © 2025 Brad Howes. All rights reserved.

import BaseSupport
import ComposableArchitecture
import DependenciesTestSupport
import Models
import SnapshotTesting
import SwiftUI
import Testing
import TestSupport

@testable import Keyboard

@Suite
@MainActor
struct OrderedInsertionIndexTests {

  @Test
  func empty() async throws {
    let uat: [CGRect] = []
    #expect(uat.orderedInsertionIndex(for: .zero) == 0)
  }

  @Test
  func one() async throws {
    let uat: [CGRect] = [
      .init(x: 10, y: 0, width: 10, height: 10)
    ]
    #expect(uat.orderedInsertionIndex(for: .zero) == 0)
    #expect(uat.orderedInsertionIndex(for: .init(x: 19, y: 0)) == 0)
    #expect(uat.orderedInsertionIndex(for: .init(x: 20, y: 0)) == uat.count)
  }

  @Test
  func multiple() async throws {
    let uat: [CGRect] = [
      .init(x: 0, y: 0, width: 10, height: 10),
      .init(x: 10, y: 0, width: 10, height: 10),
      .init(x: 20, y: 0, width: 10, height: 10),
      .init(x: 30, y: 0, width: 10, height: 10),
      .init(x: 40, y: 0, width: 10, height: 10),
      .init(x: 50, y: 0, width: 10, height: 10)
    ]
    #expect(uat.orderedInsertionIndex(for: .zero) == 0)
    #expect(uat.orderedInsertionIndex(for: .init(x: 19, y: 0)) == 1)
    #expect(uat.orderedInsertionIndex(for: .init(x: 20, y: 0)) == 2)
    #expect(uat.orderedInsertionIndex(for: .init(x: 55, y: 0)) == 5)
    #expect(uat.orderedInsertionIndex(for: .init(x: 65, y: 0)) == uat.count)
  }

  @Test
  func overlapping() async throws {
    let uat: [CGRect] = [
      .init(x: 0, y: 0, width: 10, height: 10), // C
      .init(x: 7, y: 0, width: 6, height: 5), // C#
      .init(x: 10, y: 0, width: 10, height: 10), // D
      .init(x: 17, y: 0, width: 6, height: 5), // D#
      .init(x: 20, y: 0, width: 10, height: 10), // E
      .init(x: 30, y: 0, width: 10, height: 10), // F
      .init(x: 37, y: 0, width: 6, height: 10), // F#
      .init(x: 40, y: 0, width: 10, height: 10), // G
      .init(x: 47, y: 0, width: 6, height: 10), // G#
      .init(x: 50, y: 0, width: 10, height: 10) // A
    ]
    #expect(uat.orderedInsertionIndex(for: .zero) == 0)
    #expect(uat.orderedInsertionIndex(for: .init(x: 5, y: 8)) == 0)
    #expect(uat.orderedInsertionIndex(for: .init(x: 7, y: 8)) == 0)
    #expect(uat.orderedInsertionIndex(for: .init(x: 7, y: 4)) == 1)
    #expect(uat.orderedInsertionIndex(for: .init(x: 12, y: 4)) == 1)
    #expect(uat.orderedInsertionIndex(for: .init(x: 13, y: 8)) == 2)
    #expect(uat.orderedInsertionIndex(for: .init(x: 15, y: 4)) == 2)
    #expect(uat.orderedInsertionIndex(for: .init(x: 22, y: 8)) == 4)
    #expect(uat.orderedInsertionIndex(for: .init(x: 22, y: 4)) == 3)
    #expect(uat.orderedInsertionIndex(for: .init(x: 37, y: 4)) == 6)
    #expect(uat.orderedInsertionIndex(for: .init(x: 80, y: 4)) == uat.count)
  }
}
