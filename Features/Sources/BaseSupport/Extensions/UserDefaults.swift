// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation

extension UserDefaults {
  // swiftlint:disable:next force_unwrapping
  public nonisolated(unsafe) static let group = UserDefaults(suiteName: FileManager.default.applicationGroupIdentifier)!
}
