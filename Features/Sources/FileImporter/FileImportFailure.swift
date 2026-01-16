// Copyright (c) 2026 Brad Howes. All rights reserved.

import Foundation

/// Types of file import failures
public struct FileImportFailure: Error, Equatable {

  public enum Reason: Equatable, Sendable {
    case emptyFile
    case invalidFile
    case unableToCreateFile
    case unknownError(String)
    case duplicateFile
    case failedToReadDirectory
    case unknownFileType
  }

  public let url: URL
  public let reason: Reason

  public init(_ url: URL, reason: Reason) {
    self.url = url
    self.reason = reason
  }
}

public typealias FileImportResult = Result<String, FileImportFailure>
