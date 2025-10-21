// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation

extension URL {
  static public var activeStateURL: URL { URL.applicationSupportDirectory.appendingPathComponent("activeState.json")
  }
}
