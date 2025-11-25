// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import Testing

@testable import BaseSupport

@Suite
struct ProcessInfoTests {

  @Test
  func isOnGithub() {
    #expect(ProcessInfo.processInfo.isOnGithub == ProcessInfo.processInfo.isOnGithub)
  }
}
