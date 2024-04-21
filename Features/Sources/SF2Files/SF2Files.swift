// Copyright © 2020 Brad Howes. All rights reserved.

import Foundation

public enum SF2FilesError: Error {
  case notFound(name: String)
  case missingResources
}

/// Public interface for the SF2Files framework. It provides URLs to SF2 files that are bundled with the framework.
public struct SF2Files {

  /// The extension for an SF2 file
  public static let sf2Extension = "sf2"

  /// The extension for an SF2 file that begins with a period ('.')
  public static let sf2DottedExtension = "." + sf2Extension

  /// Collection of all available SF2 files in this bundle
  public static let resources = Bundle.module.urls(forResourcesWithExtension: sf2Extension, subdirectory: nil) ?? []

  /**
   Locate a specific SF2 resource by name.

   - parameter name: the name to look for
   - returns: the URL of the resource in the bundle
   */
  public static func resource(name: String) throws -> URL {
    guard let url = Bundle.module.url(forResource: name, withExtension: sf2Extension) else {
      throw SF2FilesError.notFound(name: name)
    }
    return url
  }
}
