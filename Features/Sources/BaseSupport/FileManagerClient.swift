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
      hasCloudDirectory: { FileManager.default.hasCloudDirectory },
      localDocumentsDirectory: { FileManager.default.localDocumentsDirectory },
      sharedDocumentsDirectory: { FileManager.default.sharedDocumentsDirectory },
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
      hasCloudDirectory: { false },
      localDocumentsDirectory: { FileManager.default.localDocumentsDirectory },
      sharedDocumentsDirectory: { FileManager.default.sharedDocumentsDirectory },
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
      hasCloudDirectory: { unimplemented("hasCloudDirectory", placeholder: false) },
      localDocumentsDirectory: { unimplemented("localDocumentsDirectory", placeholder: bogus) },
      sharedDocumentsDirectory: { unimplemented("sharedDocumentsDirectory", placeholder: bogus) },
      cloudDocumentsDirectory: { unimplemented("cloudDocumentsDirectory", placeholder: nil) },
      fileSizeOf: { _ in unimplemented("fileSizeOf", placeholder: 0) },
      isUbiquitousItem: { _ in unimplemented("isUbiquitousItem", placeholder: false) },
      copyItem: { _, _ in unimplemented("copyItem", placeholder: ()) },
      removeItem: { _ in unimplemented("removeItem", placeholder: ()) }
    )
  }
}
