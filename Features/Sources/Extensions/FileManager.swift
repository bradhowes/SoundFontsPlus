// Copyright © 2024 Brad Howes. All rights reserved.

import Foundation
import os
import Dependencies
import XCTestDynamicOverlay

/**
 Collection of FileManager dependencies to allow for mocking and controlling in tests.
 */
public struct FileManagerClient : Sendable {
  public var newTemporaryFile: @Sendable () throws -> URL
  public var privateDocumentsDirectory: @Sendable () -> URL
  public var sharedDocumentsDirectory: @Sendable () -> URL
  public var sharedPathFor: @Sendable (_ component: String) -> URL
  public var sharedContents: @Sendable () -> [String]
  public var hasCloudDirectory: @Sendable () -> Bool
  public var localDocumentsDirectory: @Sendable () -> URL
  public var cloudDocumentsDirectory: @Sendable () -> URL?
  public var fileSizeOf: @Sendable (_ url: URL) -> UInt64
  public var isUbiquitousItem: @Sendable (_ url: URL) -> Bool
  public var copyItem: @Sendable (_ src: URL, _ dst: URL) throws -> Void
  public var removeItem: @Sendable (_ at: URL) throws -> Void
}

extension FileManagerClient: DependencyKey {

  /// Mapping of FileManager functionality to use in "live" situations. Note that there is no state here in order 
  /// to satisfy Sendable conformance.0
  public static var liveValue: FileManagerClient {
    .init(
      newTemporaryFile: { try FileManager.default.newTemporaryFile() },
      privateDocumentsDirectory: { FileManager.default.privateDocumentsDirectory },
      sharedDocumentsDirectory: { FileManager.default.sharedDocumentsDirectory },
      sharedPathFor: { FileManager.default.sharedPath(for: $0) },
      sharedContents: { FileManager.default.sharedContents },
      hasCloudDirectory: { FileManager.default.hasCloudDirectory },
      localDocumentsDirectory: { FileManager.default.localDocumentsDirectory },
      cloudDocumentsDirectory: { FileManager.default.cloudDocumentsDirectory },
      fileSizeOf: { FileManager.default.fileSizeOf(url: $0) },
      isUbiquitousItem: { FileManager.default.isUbiquitousItem(at: $0) },
      copyItem: { try FileManager.default.copyItem(at: $0, to: $1) },
      removeItem: { try FileManager.default.removeItem(at: $0) }
    )
  }

  /// Mapping of FileManager functionality to use in SwiftUI previews
  public static var previewValue: FileManagerClient { 
    .init(
      newTemporaryFile: { try FileManager.default.newTemporaryFile() },
      privateDocumentsDirectory: { FileManager.default.localDocumentsDirectory },
      sharedDocumentsDirectory: { FileManager.default.localDocumentsDirectory },
      sharedPathFor: { _ in FileManager.default.localDocumentsDirectory},
      sharedContents: { ["One", "Two", "Three"] },
      hasCloudDirectory: { false },
      localDocumentsDirectory: { FileManager.default.localDocumentsDirectory },
      cloudDocumentsDirectory: { nil },
      fileSizeOf: { FileManager.default.fileSizeOf(url: $0) },
      isUbiquitousItem: { _ in false },
      copyItem: { _, _ in },
      removeItem: { _ in }
    )
  }

  private static var bogus: URL { URL(fileURLWithPath: "bogus") }

  /// Mapping of FileManager functinality to use in unit tests.
  public static var testValue: FileManagerClient {
    .init(
      newTemporaryFile: { unimplemented("newTemporaryFile", placeholder: bogus) },
      privateDocumentsDirectory: { unimplemented("privateDocumentDirectory", placeholder: bogus) },
      sharedDocumentsDirectory: { unimplemented("sharedDocumentsDirectory", placeholder: bogus) },
      sharedPathFor: { _ in unimplemented("sharedPathFor", placeholder: bogus) },
      sharedContents: { unimplemented("sharedContents", placeholder: []) },
      hasCloudDirectory: { unimplemented("hasCloudDirectory", placeholder: false) },
      localDocumentsDirectory: { unimplemented("localDocumentsDirectory", placeholder: bogus) },
      cloudDocumentsDirectory: { unimplemented("cloudDocumentsDirectory", placeholder: nil) },
      fileSizeOf: { _ in unimplemented("fileSizeOf", placeholder: 0) },
      isUbiquitousItem: { _ in unimplemented("isUbiquitousItem", placeholder: false) },
      copyItem: { _, _ in unimplemented("copyItem", placeholder: ()) },
      removeItem: { _ in unimplemented("removeItem", placeholder: ()) }
    )
  }
}

extension DependencyValues {
  public var fileManager: FileManagerClient {
    get { self[FileManagerClient.self] }
    set { self[FileManagerClient.self] = newValue }
  }
}


public extension FileManager {

  var groupIdentifier: String { "group.com.braysoftware.SoundFontsShare" }

  /**
   Obtain the URL for a new, temporary file. The file will exist on the system but will be empty.

   - returns: the location of the temporary file.
   - throws: exceptions encountered by FileManager while locating location for temporary file
   */
  func newTemporaryFile() throws -> URL {
    let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    let temporaryFileURL = temporaryDirectoryURL.appendingPathComponent(
      ProcessInfo().globallyUniqueString)
    precondition(self.createFile(atPath: temporaryFileURL.path, contents: nil))
    return temporaryFileURL
  }

  /// Location of app documents that we want to keep private but backed-up. We need to create it if it does not
  /// exist, so this could be a high latency call.
  var privateDocumentsDirectory: URL {
    let url = urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    if !self.fileExists(atPath: url.path) {
      try? self.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    }
    return url
  }

  /// Location of shared documents between app and extension
  var sharedDocumentsDirectory: URL {
    guard let url = self.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier) else {
      return localDocumentsDirectory
    }

    if !self.fileExists(atPath: url.path) {
      try? self.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    }
    return url
  }

  func sharedPath(for component: String) -> URL {
    sharedDocumentsDirectory.appendingPathComponent(component)
  }

  var sharedContents: [String] {
    (try? contentsOfDirectory(atPath: sharedDocumentsDirectory.path)) ?? [String]()
  }

  /// True if the user has an iCloud container available to use
  var hasCloudDirectory: Bool { self.ubiquityIdentityToken != nil }

  /// Location of documents on device that can be backed-up to iCloud if enabled.
  var localDocumentsDirectory: URL {
    self.urls(for: .documentDirectory, in: .userDomainMask).last!
  }

  /// Location of app documents in iCloud (if enabled). NOTE: this should not be accessed from the main thread as
  /// it can take some time before it will return a value.
  var cloudDocumentsDirectory: URL? {
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
  func fileSizeOf(url: URL) -> UInt64 {
    (try? (self.attributesOfItem(atPath: url.path) as NSDictionary).fileSize()) ?? 0
  }
}
