// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import Engine

public enum SF2ResourceFilesError: Error {
  case notFound(name: String)
  case missingResources
}

/// Public interface for the SF2ResourceFiles framework. It provides URLs to SF2 files that are bundled with the framework.
public struct SF2ResourceFiles {

  /// The extension for an SF2 file
  public static let sf2Extension = "sf2"

  /// The extension for an SF2 file that begins with a period ('.')
  public static let sf2DottedExtension = "." + sf2Extension

  /// Collection of all available SF2 files in this bundle -- order the URLs here to match the order of cases in
  /// SF2FileTag
  public static let resources: [URL] = SF2ResourceFileTag.allCases.map {
    Bundle.main.url(forResource: $0.fileName, withExtension: sf2Extension)!
  }

  /**
   Locate a specific SF2 resource by file name.

   - parameter fileName: the name to look for
   - returns: the URL of the resource in the bundle
   */
  public static func resource(fileName: String) throws -> URL {
    guard let url = Bundle.main.url(forResource: fileName, withExtension: sf2Extension) else {
      throw SF2ResourceFilesError.notFound(name: fileName)
    }
    return url
  }
}
