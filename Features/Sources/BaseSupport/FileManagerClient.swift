// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import Dependencies

/**
 Collection of FileManager dependencies to allow for mocking and controlling in tests.
 */
public struct FileManagerClient: Sendable {
  public var hasCloudDirectory: @Sendable () -> Bool
  public var localDocumentsDirectory: @Sendable () -> URL
  public var sharedDocumentsDirectory: @Sendable () -> URL
  public var cloudDocumentsDirectory: @Sendable () -> URL?
  public var fontFilesDirectory: @Sendable () -> URL
  public var fontFilePath: @Sendable (_ filename: String) -> URL
  public var fileSizeOf: @Sendable (_ url: URL) -> UInt64
  public var isUbiquitousItem: @Sendable (_ url: URL) -> Bool
  public var copyItem: @Sendable (_ src: URL, _ dst: URL) throws -> Void
  public var removeItem: @Sendable (_ at: URL) throws -> Void
  public var createDirectory: @Sendable (_ at: URL) throws -> Void
  public var contentsOfDirectory: @Sendable (_ at: URL) throws -> [URL]
  public var fileExists: @Sendable (_ at: URL) -> Bool
  public var startDownloadingUbiquitousItem: @Sendable (_ url: URL) throws -> Void
}

extension FileManagerClient: DependencyKey {

  /// Mapping of FileManager functionality to use in "live" situations. Note that there is no state here in order 
  /// to satisfy Sendable conformance.
  public static var liveValue: FileManagerClient {
    .init(
      hasCloudDirectory: { FileManager.default.hasCloudDirectory },
      localDocumentsDirectory: { FileManager.default.localDocumentsDirectory },
      sharedDocumentsDirectory: { FileManager.default.sharedDocumentsDirectory },
      cloudDocumentsDirectory: { FileManager.default.cloudDocumentsDirectory },
      fontFilesDirectory: { FileManager.default.fontFilesDirectory },
      fontFilePath: { FileManager.default.fontFilesDirectory.appendingPathComponent($0, isDirectory: false) },
      fileSizeOf: { FileManager.default.fileSizeOf(url: $0) },
      isUbiquitousItem: { FileManager.default.isUbiquitousItem(at: $0) },
      copyItem: { try FileManager.default.copyItem(at: $0, to: $1) },
      removeItem: { try FileManager.default.removeItem(at: $0) },
      createDirectory: { try FileManager.default.createDirectory(at: $0, withIntermediateDirectories: true) },
      contentsOfDirectory: {
        try FileManager.default.contentsOfDirectory(
          at: $0,
          includingPropertiesForKeys: [.typeIdentifierKey],
          options: [.skipsHiddenFiles]
        )
      },
      fileExists: { FileManager.default.fileExists(atPath: $0.path()) },
      startDownloadingUbiquitousItem: { try FileManager.default.startDownloadingUbiquitousItem(at: $0) }
    )
  }

  /// Mapping of FileManager functionality to use in SwiftUI previews
  public static var previewValue: FileManagerClient {
    .init(
      hasCloudDirectory: { false },
      localDocumentsDirectory: { FileManager.default.localDocumentsDirectory },
      sharedDocumentsDirectory: { FileManager.default.sharedDocumentsDirectory },
      cloudDocumentsDirectory: { nil },
      fontFilesDirectory: { FileManager.default.fontFilesDirectory },
      fontFilePath: { FileManager.default.fontFilesDirectory.appendingPathComponent($0, isDirectory: false) },
      fileSizeOf: { FileManager.default.fileSizeOf(url: $0) },
      isUbiquitousItem: { _ in false },
      copyItem: { _, _ in },
      removeItem: { _ in },
      createDirectory: { _ in },
      contentsOfDirectory: {
        try FileManager.default.contentsOfDirectory(
          at: $0,
          includingPropertiesForKeys: [.typeIdentifierKey],
          options: [.skipsHiddenFiles]
        )
      },
      fileExists: { FileManager.default.fileExists(atPath: $0.path()) },
      startDownloadingUbiquitousItem: { try FileManager.default.startDownloadingUbiquitousItem(at: $0) }
    )
  }

  /// Mapping of FileManager functinality to use in unit tests.
  public static var testValue: FileManagerClient {
    let bogus: URL = .init(fileURLWithPath: "bogus")
    return .init(
      hasCloudDirectory: { unimplemented("hasCloudDirectory", placeholder: false) },
      localDocumentsDirectory: { unimplemented("localDocumentsDirectory", placeholder: bogus) },
      sharedDocumentsDirectory: { unimplemented("sharedDocumentsDirectory", placeholder: bogus) },
      cloudDocumentsDirectory: { unimplemented("cloudDocumentsDirectory", placeholder: nil) },
      fontFilesDirectory: { unimplemented("fontFilesDirectory", placeholder: bogus) },
      fontFilePath: { _ in unimplemented("fontFilePath", placeholder: bogus) },
      fileSizeOf: { _ in unimplemented("fileSizeOf", placeholder: 0) },
      isUbiquitousItem: { _ in unimplemented("isUbiquitousItem", placeholder: false) },
      copyItem: { _, _ in unimplemented("copyItem", placeholder: ()) },
      removeItem: { _ in unimplemented("removeItem", placeholder: ()) },
      createDirectory: { _ in unimplemented("createDirectory", placeholder: ()) },
      contentsOfDirectory: { _ in unimplemented("contentsOfDirectory", placeholder: [bogus]) },
      fileExists: { _ in unimplemented("fileExists", placeholder: false) },
      startDownloadingUbiquitousItem: { _ in unimplemented("startDownloadingUbiquitousItem") }
    )
  }
}
