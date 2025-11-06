// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import SQLiteData

extension URL {
  static public var activeStateURL: URL {
    URL.applicationSupportDirectory.appendingPathComponent("activeState.json")
  }
}

extension URL {

  /**
   Attempt to obtain bookmark data for an artifact URL that can be saved and later used to generate a valid URL
   to the artifact.
   */
  var secureBookmarkData: Data? {
    withSecurityScoping { _ in
      // The documentation for call indicates that `relativeTo` should not be `nil`, but that never worked for me.
      // So far this does but not sure how stable it is.
      try bookmarkData(
        options: .minimalBookmark,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )
    }
  }
}

extension URL {

  public func withSecurityScoping<T>(_ closure: (URL) throws -> T) -> T? {
    let secured = self.startAccessingSecurityScopedResource()
    defer { if secured { self.stopAccessingSecurityScopedResource() } }
    return withErrorReporting {
      return try closure(self)
    }
  }

  public func withSecurityScopingThrows<T>(_ closure: (URL) throws -> T) throws -> T {
    let secured = self.startAccessingSecurityScopedResource()
    defer { if secured { self.stopAccessingSecurityScopedResource() } }
    return try closure(self)
  }
}
