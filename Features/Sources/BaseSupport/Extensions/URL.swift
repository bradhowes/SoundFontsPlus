// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import SQLiteData

extension URL {

  /**
   - Returns: the URL for the file that persists the `activeState` values.
   */
  static public var activeStateURL: URL {
    URL.applicationSupportDirectory.appendingPathComponent("activeState.json")
  }
}

extension URL {

  /**
   Attempt to obtain bookmark data for an artifact URL that can be saved and later used to generate a valid URL
   to the artifact.

   - Returns: an optional `Data` container with the bookmark value
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

  /**
   Execute a closure for accessing a security-scoped resource. Captures and logs any exceptions raised in the closure.
   - Parameters:
     - closure: code block to execute
   - Returns: the result from the closure, or nil if the closure raised an exception.
   */
  public func withSecurityScoping<T>(_ closure: (URL) throws -> T) -> T? {
    let secured = self.startAccessingSecurityScopedResource()
    defer { if secured { self.stopAccessingSecurityScopedResource() } }
    return withErrorReporting {
      try closure(self)
    }
  }

  /**
   Execute a closure for accessing a security-scoped resource.
   - Parameters:
   - closure: code block to execute
   - Returns: the result from the closure
   */
  public func withSecurityScopingThrows<T>(_ closure: (URL) throws -> T) throws -> T {
    let secured = self.startAccessingSecurityScopedResource()
    defer { if secured { self.stopAccessingSecurityScopedResource() } }
    return try closure(self)
  }
}
