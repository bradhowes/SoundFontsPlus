// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import os
import Dependencies

extension FileManager {

  public var groupIdentifier: String { "group.com.braysoftware.SoundFontsShare" }

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
    return temporaryFileURL
  }

  public func newTemporaryURL() throws -> URL {
    let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    let temporaryFileURL = temporaryDirectoryURL.appendingPathComponent(UUID().uuidString)
    return temporaryFileURL
  }
  /// Location of app documents that we want to keep private but backed-up. We need to create it if it does not
  /// exist, so this could be a high latency call.
  public var privateDocumentsDirectory: URL {
    let url = urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    if !self.fileExists(atPath: url.path) {
      try? self.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    }
    return url
  }

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

  public func sharedPath(for component: String) -> URL {
    sharedDocumentsDirectory.appendingPathComponent(component)
  }

  public var sharedContents: [String] {
    (try? contentsOfDirectory(atPath: sharedDocumentsDirectory.path)) ?? [String]()
  }

  /// True if the user has an iCloud container available to use
  public var hasCloudDirectory: Bool { self.ubiquityIdentityToken != nil }

  /// Location of documents on device that can be backed-up to iCloud if enabled.
  public var localDocumentsDirectory: URL {
    self.urls(for: .documentDirectory, in: .userDomainMask).last!
  }

  /// Location of app documents in iCloud (if enabled). NOTE: this should not be accessed from the main thread as
  /// it can take some time before it will return a value.
  public var cloudDocumentsDirectory: URL? {
    precondition(Thread.current.isMainThread == false)
    guard let loc = self.url(forUbiquityContainerIdentifier: nil) else {
      return nil
    }
    let dir = loc.appendingPathComponent("Documents")
    if !self.fileExists(atPath: dir.path) {
      try? self.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
    }

    return dir
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
