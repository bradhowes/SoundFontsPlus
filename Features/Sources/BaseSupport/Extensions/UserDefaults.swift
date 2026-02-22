// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation

extension UserDefaults {
  public nonisolated(unsafe) static let group: UserDefaults? = .init(suiteName: FileManager.default.applicationGroupIdentifier)
}
