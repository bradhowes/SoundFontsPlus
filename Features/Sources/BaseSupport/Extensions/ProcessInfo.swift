// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation

extension ProcessInfo {
  public var isOnGithub: Bool { environment["HOME"]?.starts(with: "/Users/runner/") ?? false }
}
