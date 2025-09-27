// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation

extension ProcessInfo {
  public static var isOnGithub: Bool {
    Self.processInfo.environment["HOME"]?.starts(with: "/Users/runner/") ?? false
  }
}
