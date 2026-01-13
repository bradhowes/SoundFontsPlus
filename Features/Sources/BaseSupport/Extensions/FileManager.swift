// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import os

extension FileManager: @unchecked @retroactive Sendable {

  /// - returns: The app group identifier.
  public var applicationGroupIdentifier: String { "group.com.braysoftware.SFP" }

  /**
   Obtain the URL for a new, temporary file. The file will exist on the system but will be empty.

   - returns: the location of the temporary file.
   - throws: exceptions encountered by FileManager while locating location for temporary file
   */
  public func newTemporaryFile() throws -> URL {
    let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    let temporaryFileURL = temporaryDirectoryURL.appendingPathComponent(
      ProcessInfo().globallyUniqueString)
    precondition(self.createFile(atPath: temporaryFileURL.path, contents: nil))
    log.debug("newTemporaryFile - \(temporaryFileURL.absoluteString, privacy: .public)")
    return temporaryFileURL
  }

  /// Location of app documents that we want to keep private but backed-up. We need to create it if it does not
  /// exist, so this could be a high latency call.
  public var privateDocumentsDirectory: URL {
    let url = urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    if !self.fileExists(atPath: url.path) {
      do {
        try self.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
      } catch {
        log.error("Failed to create directory \(url, privacy: .public) - \(error, privacy: .public)")
      }
    }
    return url
  }

  /// - returns: Location of shared documents between app and extension
  public var sharedDocumentsDirectory: URL {
    guard let url = self.containerURL(forSecurityApplicationGroupIdentifier: applicationGroupIdentifier) else {
      log.error("unable to obtain container URL for '\(self.applicationGroupIdentifier, privacy: .public)")
      return localDocumentsDirectory
    }

    if !self.fileExists(atPath: url.path) {
      do {
        try self.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
      } catch {
        log.error("Failed to create directory \(url, privacy: .public) - \(error, privacy: .public)")
      }
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

private let log: Logger = .init(category: "FileManager")
