// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import Foundation
import os

extension FileManager {

  /// - returns: The app group identifier.
  public var applicationGroupIdentifier: String { "group.com.braysoftware.SFP" }

  /// - returns: Location of shared documents between app and extension
  public var sharedDocumentsDirectory: URL {
    guard let url = containerURL(forSecurityApplicationGroupIdentifier: applicationGroupIdentifier) else {
      fatalError("mismatch app group identifier")
    }
    return url
  }

  /// - returns: The directory containing SoundFontsPlus font files
  public var fontFilesDirectory: URL { sharedDocumentsDirectory.appendingPathComponent("FontFiles") }

  /// - returns: True if the user has an iCloud container available to use
  public var hasCloudDirectory: Bool { ubiquityIdentityToken != nil }

  /// - returns: Location of documents on device that can be backed-up to iCloud if enabled.
  public var localDocumentsDirectory: URL { urls(for: .documentDirectory, in: .userDomainMask)[0] }

  /// - returns: Location of app documents in iCloud (if enabled).
  public var cloudDocumentsDirectory: URL? { url(forUbiquityContainerIdentifier: nil) }

  /**
   Try to obtain the size of a given file.

   - parameter url: The location of the file to measure
   - returns: Size in bytes or 0 if there was a problem getting the size
   */
  public func fileSizeOf(url: URL) -> UInt64 { (try? (attributesOfItem(atPath: url.path) as NSDictionary).fileSize()) ?? 0 }
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

private let log: Logger = .init(category: "FileManager")
