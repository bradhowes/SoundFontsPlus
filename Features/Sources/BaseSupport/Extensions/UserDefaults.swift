// Copyright © 2025 Brad Howes. All rights reserved.

public import Foundation

extension UserDefaults {
  public nonisolated(unsafe) static let group: UserDefaults? = .init(suiteName: FileManager.default.applicationGroupIdentifier)
}
