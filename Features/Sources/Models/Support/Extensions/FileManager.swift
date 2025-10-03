// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import os
import Dependencies

extension FileManager {

  public var groupIdentifier: String { "group.com.braysoftware.SoundFontsShare" }

  /// Location of shared documents between app and extension
  public var sharedDocumentsDirectory: URL {
    guard let url = self.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier) else {
      return localDocumentsDirectory
    }

    if !self.fileExists(atPath: url.path) {
      try? self.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    }

    return url
  }

  /// True if the user has an iCloud container available to use
  public var hasCloudDirectory: Bool { self.ubiquityIdentityToken != nil }

  /// Location of documents on device that can be backed-up to iCloud if enabled.
  public var localDocumentsDirectory: URL {
    // swiftlint:disable:next force_unwrapping
    self.urls(for: .documentDirectory, in: .userDomainMask).last!
  }

  /// Location of app documents in iCloud (if enabled).
  public var cloudDocumentsDirectory: URL? {
    self.url(forUbiquityContainerIdentifier: nil)
  }

  /**
   Try to obtain the size of a given file.

   - parameter url: the location of the file to measure
   - returns: size in bytes or 0 if there was a problem getting the size
   */
  public func fileSizeOf(url: URL) -> UInt64 {
    (try? (self.attributesOfItem(atPath: url.path) as NSDictionary).fileSize()) ?? 0
  }
}

// From https://fatbobman.com/en/posts/in-depth-guide-to-icloud-documents/

#if false

actor CloudDocumentsHandler {
  let coordinator = NSFileCoordinator()

  func write(targetURL: URL, data: Data) throws {
    var coordinationError: NSError?
    var writeError: Error?

    // Use the coordinationError variable to capture the error information of the coordinate method.
    // If an NSError pointer is not provided, errors occurring during the coordination process will not be caught
    // and handled.
    coordinator.coordinate(writingItemAt: targetURL, options: [.forDeleting], error: &coordinationError) { url in
      do {
        try data.write(to: url, options: .atomic)
      } catch {
        writeError = error
      }
    }

    // Check outside the closure to see if an error occurred
    if let error = writeError {
      throw error
    }

    // Check if an error occurred during reconciliation
    if let coordinationError = coordinationError {
      throw coordinationError
    }
  }
}

#endif
