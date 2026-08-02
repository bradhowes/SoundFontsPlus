// Copyright © 2025 Brad Howes. All rights reserved.

public import Foundation

extension ProcessInfo {
  public var isOnGithub: Bool { !(environment["SNAPSHOT_ARTIFACTS"]?.isEmpty ?? true) }
}
