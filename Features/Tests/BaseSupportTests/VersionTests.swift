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
struct VersionTests {

  @Test
  func parse() {
    #expect(Version.parse("0.0.0") == .init(0, 0, 0))
    #expect(Version.parse("0.1.2") == .init(0, 1, 2))
    #expect(Version.parse("1.2.3") == .init(1, 2, 3))
    #expect(Version.parse("-1.3.3") == nil)
    #expect(Version.parse("1.-2.3") == nil)
    #expect(Version.parse("1.2.-3") == nil)
    #expect(Version.parse("0") == nil)
    #expect(Version.parse("0.") == nil)
    #expect(Version.parse("0.0") == nil)
    #expect(Version.parse("0.0.") == nil)
    #expect(Version.parse("0.0.a") == nil)
    #expect(Version.parse("0.0.0.") == nil)
    #expect(Version.parse("0.0.0.0") == nil)
  }

  @Test
  func equality() {
    #expect(Version(1, 2, 3) == Version(1, 2, 3))
    #expect(Version(1, 2, 3) != Version(1, 2, 4))
    #expect(Version(1, 2, 3) != Version(1, 3, 3))
    #expect(Version(1, 2, 3) != Version(2, 2, 4))
  }

  @Test
  func ordering() {
    #expect(Version(1, 2, 3) <= Version(1, 2, 3))
    #expect(Version(1, 2, 3) < Version(1, 2, 4))
    #expect(Version(1, 2, 3) < Version(2, 0, 0))
    #expect(Version(1, 2, 3) < Version(1, 3, 0))
  }
}
