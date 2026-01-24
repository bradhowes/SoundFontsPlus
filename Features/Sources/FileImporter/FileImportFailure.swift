// Copyright (c) 2026 Brad Howes. All rights reserved.

import Foundation

/// Types of file import failures
public struct FileImportFailure: Error, Equatable {

  public enum Reason: Equatable, Sendable {
    case invalidFile
    case unableToCreateFile
    case unknownError(String)
    case duplicateFile
    case unknownFileType
    case failedToReadDirectory

    public var tag: String {
      switch self {
      case .invalidFile: return "not a valid SF2 file"
      case .unableToCreateFile: return "failed to copy the file"
      case .unknownError(let err): return err
      case .duplicateFile: return "duplicate file"
      case .unknownFileType: return "unknown file type"
      case .failedToReadDirectory: return "unable to read directory"
      }
    }
  }

  public let url: URL
  public let reason: Reason

  public init(_ url: URL, reason: Reason) {
    self.url = url
    self.reason = reason
  }
}

public typealias FileImportResult = Result<String, FileImportFailure>
