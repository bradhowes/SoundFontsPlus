// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import Sharing
import SQLiteData

extension URL {

  /**
   - Returns: the URL for the file that persists the `activeState` values. For an AUv3 extension we save to a
   throw-away file that is unique across all instances since we do not want multiple AUv3 extensions to share
   this state, and the active state is guided by the current AUv3 preset.
   */
  public static let activeStateURL: URL = {
    @Shared(.isAUv3) var isAUv3
    return isAUv3 ? .temporaryDirectory.appendingPathComponent(ProcessInfo().globallyUniqueString) :
      .applicationSupportDirectory.appendingPathComponent("activeState.json")
  }()
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

extension URL {
  public var displayName: Substring { self.lastPathComponent.withoutExtension }
}

private let log: Logger = .init(category: "URL")
