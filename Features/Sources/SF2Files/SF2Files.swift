// Copyright © 2024 Brad Howes. All rights reserved.

import Foundation
import Engine


public enum SF2FilesError: Error {
  case notFound(name: String)
  case missingResources
}

/**
 Collection of unique tags for each SF2 file in the bundle
 */
public enum SF2FileTag: Int, CaseIterable {

  case freeFont
  case museScore
  case rolandNicePiano

  static let freeFontFileName = "FreeFont"
  static let museScoreFileName = "GeneralUser GS MuseScore v1.442"
  static let rolandNicePianoFileName = "RolandNicePiano"

  /// Obtain the name of the SF2 resource file without suffix
  public var fileName: String {
    switch self {
    case .freeFont: return Self.freeFontFileName
    case .museScore: return Self.museScoreFileName
    case .rolandNicePiano: return Self.rolandNicePianoFileName
    }
  }

  static let freeFontName = freeFontFileName
  static let museScoreName = "MuseScore"
  static let rolandNicePianoName = "Roland Piano"

  /// Obtain the name of the SF2 resource
  public var name: String {
    switch self {
    case .freeFont: return Self.freeFontName
    case .museScore: return Self.museScoreName
    case .rolandNicePiano: return Self.rolandNicePianoName
    }
  }

  /// Obtain the `resources` index associated with the tag
  public var resourceIndex: Int { self.rawValue }

  /// Obtain the URL for an SF2 file in the bundle
  public var url: URL { SF2Files.resources[resourceIndex] }

  /// Obtain a info and preset info about an SF2 file
  public var fileInfo: Engine.SF2FileInfo? {
    var fileInfo = Engine.SF2FileInfo(url.path(percentEncoded: false))
    return fileInfo.load() ? fileInfo : nil
  }

  public static func from(name: String) -> SF2FileTag {
    if name == Self.freeFontName {
      return .freeFont
    } else if name == Self.museScoreName {
      return .museScore
    } else if name == Self.rolandNicePianoName {
      return .rolandNicePiano
    } else {
      fatalError("unknown display name")
    }
  }
}

/// Public interface for the SF2Files framework. It provides URLs to SF2 files that are bundled with the framework.
public struct SF2Files {

  /// The extension for an SF2 file
  public static let sf2Extension = "sf2"

  /// The extension for an SF2 file that begins with a period ('.')
  public static let sf2DottedExtension = "." + sf2Extension

  /// Collection of all available SF2 files in this bundle -- order the URLs here to match the order of cases in
  /// SF2FileTag
  public static let resources = SF2FileTag.allCases.map {
    Bundle.module.url(forResource: $0.fileName, withExtension: sf2Extension)!
  }

  /**
   Locate a specific SF2 resource by file name.

   - parameter fileName: the name to look for
   - returns: the URL of the resource in the bundle
   */
  public static func resource(fileName: String) throws -> URL {
    guard let url = Bundle.module.url(forResource: fileName, withExtension: sf2Extension) else {
      throw SF2FilesError.notFound(name: fileName)
    }
    return url
  }
}
